// What the screens share: the open chat, the message being written (and
// what's attached to it), whether a reply is being written, and the actions
// that change them.

import Foundation
import FoundationModels
import Observation
import SwiftUI
import PhotosUI

@MainActor @Observable
final class AppModel {
    let library: Library
    @ObservationIgnored private let brain = Brain()

    /// The chat on screen. A new chat is only kept once something is sent in it.
    private(set) var current = Chat()
    private(set) var isResponding = false
    private(set) var availability = Brain.availability
    /// Goes up by one on each send, for the haptic tap.
    private(set) var sends = 0
    /// Goes up by one when a reply's first words arrive, for a softer tap.
    private(set) var firstWords = 0

    /// Photos, scans and files waiting to go with the next message.
    private(set) var attachments: [Attachment] = []
    /// How many are still being read.
    private(set) var reading = 0
    /// Something to tell the person about an attachment that couldn't be read.
    var notice: String?
    /// The question being edited, if any: sending replaces it and what followed.
    private(set) var editing: UUID?

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var watching: Task<Void, Never>?

    init(library: Library) {
        self.library = library
        watchAvailability()
    }

    var isAvailable: Bool { availability == .available }

    // MARK: Chats

    func newChat() {
        stop()
        cancelEdit()
        current = Chat()
        brain.prewarm(current, voice: .current)
    }

    func open(_ id: UUID) {
        guard let chat = library.chat(id) else { return }
        stop()
        cancelEdit()
        current = chat
        brain.prewarm(chat, voice: .current)
    }

    func delete(_ id: UUID) {
        if id == current.id { stop(); cancelEdit(); current = Chat() }
        library.delete(id)
    }

    func deleteAll() {
        stop()
        cancelEdit()
        current = Chat()
        attachments = []
        library.deleteAll()
    }

    func rename(_ id: UUID, to title: String) {
        library.rename(id, to: title)
        if id == current.id, let chat = library.chat(id) { current.title = chat.title; current.named = chat.named }
    }

    func togglePin(_ id: UUID) {
        library.togglePin(id)
        if id == current.id, let chat = library.chat(id) { current.pinnedAt = chat.pinnedAt }
    }

    // MARK: Attaching

    func addPhoto(_ item: PhotosPickerItem) {
        reading += 1
        Task {
            defer { reading -= 1 }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { throw Reader.Failure.unreadable("that photo") }
                try await addPhoto(data)
            } catch {
                notice = error.localizedDescription
            }
        }
    }

    func addPhoto(_ data: Data, name: String? = nil) async throws {
        let name = name ?? "Photo, \(Date.now.formatted(date: .abbreviated, time: .shortened))"
        attachments.append(try await Reader.photo(data, name: name, into: library.pictures))
    }

    func addScan(_ pages: [UIImage]) {
        guard !pages.isEmpty else { return }
        reading += 1
        Task {
            defer { reading -= 1 }
            do { attachments.append(try await Reader.scan(pages, into: library.pictures)) }
            catch { notice = error.localizedDescription }
        }
    }

    func addFile(_ url: URL) {
        reading += 1
        Task {
            defer { reading -= 1 }
            do { attachments.append(try await Reader.file(url)) }
            catch { notice = error.localizedDescription }
        }
    }

    func removeAttachment(_ id: UUID) {
        guard let a = attachments.first(where: { $0.id == id }) else { return }
        attachments.removeAll { $0.id == id }
        // A picture never sent is forgotten straight away.
        if editing == nil || !current.messages.contains(where: { $0.files.contains(where: { $0.id == id }) }) {
            library.removePictures(of: [Message(role: .user, text: "", attachments: [a])])
        }
    }

    // MARK: Writing

    var canSend: Bool { reading == 0 && isAvailable && !isResponding }

    func send(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend, !text.isEmpty || !attachments.isEmpty else { return }
        if let editing, let i = current.messages.firstIndex(where: { $0.id == editing }) {
            // Replace the edited question and everything after it.
            let gone = Array(current.messages[i...])
            let kept = Set(attachments.map(\.id))
            library.removePictures(of: gone.map { m in
                var m = m
                m.attachments = m.files.filter { !kept.contains($0.id) }
                return m
            })
            current.messages.removeSubrange(i...)
            // A new first question deserves a new name, unless the person chose one.
            if i == 0 && current.named != true { current.title = "" }
        }
        editing = nil
        for i in current.messages.indices { current.messages[i].followUps = nil }
        current.messages.append(Message(role: .user, text: text, attachments: attachments.isEmpty ? nil : attachments))
        attachments = []
        sends += 1
        respond()
    }

    /// Puts a question back in the box to be changed; returns its words.
    func beginEdit(_ message: Message) -> String {
        guard !isResponding, message.role == .user else { return "" }
        editing = message.id
        attachments = message.files
        return message.text
    }

    func cancelEdit() {
        guard editing != nil else { return }
        editing = nil
        attachments = []
    }

    /// Writes the last reply again.
    func regenerate() {
        guard !isResponding, current.messages.last?.role == .assistant else { return }
        current.messages.removeLast()
        respond()
    }

    func stop() {
        task?.cancel()
    }

    private func respond() {
        let asked = current                    // everything up to the question
        let chatID = asked.id
        let question = asked.messages.last
        let reply = Message(role: .assistant, text: "")
        current.messages.append(reply)
        current.updated = .now
        library.put(current)
        isResponding = true
        let voice = Voice.current
        let firstQuestion = asked.messages.count == 1 && asked.title.isEmpty ? asked.messages[0] : nil
        let images = (question?.files ?? [])
            .filter { $0.kind != .file }
            .compactMap { library.imageURL($0).flatMap(Reader.cgImage(at:)) }

        task = Task { [weak self] in
            guard let self else { return }
            let started = Date.now
            var spoke = false
            var finished: String?
            do {
                let text = try await brain.reply(to: asked, voice: voice, images: images) { text in
                    if !spoke && !text.isEmpty { spoke = true; self.firstWords += 1 }
                    self.edit(chatID) { $0.edit(reply.id) { $0.text = text } }
                }
                let seconds = Date.now.timeIntervalSince(started)
                let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
                edit(chatID) { $0.edit(reply.id) { $0.text = clean; $0.seconds = seconds } }
                finished = clean
            } catch {
                #if PREVIEW
                FileHandle.standardError.write(Data("reply failed: \(type(of: error)) \(String(reflecting: error))\n".utf8))
                #endif
                brain.reset()
                if error is CancellationError || Task.isCancelled {
                    // A stopped reply keeps what was written; an empty one goes.
                    edit(chatID) { chat in
                        chat.messages.removeAll { $0.id == reply.id && $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    }
                } else {
                    edit(chatID) { $0.edit(reply.id) { $0.problem = Brain.explain(error) } }
                }
            }
            edit(chatID, save: true) { $0.updated = .now }
            isResponding = false

            // The title and follow-up questions come after, in their own task,
            // so moving to another chat doesn't cancel them.
            let suggest = finished.map { !$0.isEmpty } ?? false
                && (UserDefaults.standard.object(forKey: "followUps") as? Bool ?? true)
            Task { [weak self] in
                if let firstQuestion {
                    let seed = firstQuestion.text.isEmpty ? Brain.promptText(firstQuestion) : firstQuestion.text
                    if let title = await Brain.title(for: seed) {
                        self?.edit(chatID, save: true) { if $0.title.isEmpty { $0.title = title } }
                    }
                }
                if suggest, let question, let finished {
                    let next = await Brain.followUps(question: Brain.promptText(question), answer: finished)
                    if !next.isEmpty { self?.edit(chatID, save: true) { $0.edit(reply.id) { $0.followUps = next } } }
                }
            }
        }
    }

    /// Changes a chat wherever it is: on screen, or (if the person moved on
    /// while it was being written) in the library.
    private func edit(_ chatID: UUID, save: Bool = false, _ change: (inout Chat) -> Void) {
        if current.id == chatID {
            change(&current)
            if save { library.put(current) }
        } else if var chat = library.chat(chatID) {
            change(&chat)
            library.put(chat)
        }
    }

    // MARK: The model

    func refreshAvailability() {
        availability = Brain.availability
    }

    /// Apple's model can appear while the app is open (it finishes downloading,
    /// or Apple Intelligence is switched on), so keep looking until it is there.
    private func watchAvailability() {
        watching?.cancel()
        watching = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let now = Brain.availability
                if now != availability {
                    availability = now
                    if now == .available { brain.prewarm(current, voice: .current) }
                }
                try? await Task.sleep(for: .seconds(now == .available ? 20 : 3))
            }
        }
    }
}

extension Chat {
    mutating func edit(_ messageID: UUID, _ change: (inout Message) -> Void) {
        guard let i = messages.firstIndex(where: { $0.id == messageID }) else { return }
        change(&messages[i])
    }
}
