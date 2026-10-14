// What the screens share: the open chat, whether a reply is being written,
// and the actions that change them.

import Foundation
import FoundationModels
import Observation

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
        current = Chat()
        brain.prewarm(current, voice: .current)
    }

    func open(_ id: UUID) {
        guard let chat = library.chat(id) else { return }
        stop()
        current = chat
        brain.prewarm(chat, voice: .current)
    }

    func delete(_ id: UUID) {
        if id == current.id { stop(); current = Chat() }
        library.delete(id)
    }

    func deleteAll() {
        stop()
        current = Chat()
        library.deleteAll()
    }

    func rename(_ id: UUID, to title: String) {
        library.rename(id, to: title)
        if id == current.id, let chat = library.chat(id) { current.title = chat.title }
    }

    // MARK: Writing

    func send(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isResponding, isAvailable else { return }
        current.messages.append(Message(role: .user, text: text))
        sends += 1
        respond()
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
        let reply = Message(role: .assistant, text: "")
        current.messages.append(reply)
        current.updated = .now
        library.put(current)
        isResponding = true
        let voice = Voice.current
        let firstQuestion = asked.messages.count == 1 && asked.title.isEmpty ? asked.messages[0].text : nil

        task = Task { [weak self] in
            guard let self else { return }
            let started = Date.now
            var spoke = false
            do {
                let text = try await brain.reply(to: asked, voice: voice) { text in
                    if !spoke && !text.isEmpty { spoke = true; self.firstWords += 1 }
                    self.edit(chatID) { $0.edit(reply.id) { $0.text = text } }
                }
                let seconds = Date.now.timeIntervalSince(started)
                edit(chatID) { $0.edit(reply.id) { $0.text = text.trimmingCharacters(in: .whitespacesAndNewlines); $0.seconds = seconds } }
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
            if let firstQuestion, let title = await Brain.title(for: firstQuestion) {
                edit(chatID, save: true) { if $0.title.isEmpty { $0.title = title } }
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
