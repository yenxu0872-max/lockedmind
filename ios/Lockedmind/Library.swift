// The chats, and where they are kept: one JSON file in the app's own
// Application Support folder, written atomically and locked by iOS data
// protection, with attached pictures in a folder beside it. By default both
// are left out of iCloud and computer backups, so a chat exists only on this
// iPhone (Settings can let them into backups).
//
// Every field added after the first version is optional, so older saved
// chats still open.

import Foundation
import Observation

/// A photo, a scanned document or a file the person attached to a message.
/// Everything in it was read on the iPhone.
struct Attachment: Identifiable, Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case photo, scan, file }

    var id = UUID()
    var kind: Kind
    var name: String
    /// Text read from it: the words in a photo or scan, or the file's own text.
    var text: String
    /// True if the text was cut to fit the model's memory.
    var shortened: Bool? = nil
    /// The picture (a photo, or a scan's first page), stored beside the chats.
    var imageFile: String? = nil
    var pages: Int? = nil

    var symbol: String {
        switch kind {
        case .photo: "photo"
        case .scan: "doc.viewfinder"
        case .file: name.lowercased().hasSuffix(".pdf") ? "doc.richtext" : "doc.text"
        }
    }
}

struct Message: Identifiable, Codable, Equatable, Sendable {
    enum Role: String, Codable, Sendable { case user, assistant }

    var id = UUID()
    var role: Role
    var text: String
    var date = Date()
    /// Why a reply could not be written. Shown in place of the reply, and
    /// never shown to the model.
    var problem: String? = nil
    /// How long the reply took to write, in seconds.
    var seconds: Double? = nil
    var attachments: [Attachment]? = nil
    /// Questions the person might ask next, offered under the last answer.
    var followUps: [String]? = nil

    var files: [Attachment] { attachments ?? [] }

    var words: Int { text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count }
}

struct Chat: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var title = ""
    var messages: [Message] = []
    var created = Date()
    var updated = Date()
    var pinnedAt: Date? = nil
    /// True once the person has named the chat themselves.
    var named: Bool? = nil

    var isPinned: Bool { pinnedAt != nil }

    var displayTitle: String {
        if !title.isEmpty { return title }
        guard let first = messages.first(where: { $0.role == .user }) else { return "New chat" }
        if first.text.isEmpty, let file = first.files.first { return file.name }
        return Self.shorten(first.text, to: 40)
    }

    /// The last thing said, for the chat list.
    var preview: String {
        guard let last = messages.last(where: { $0.problem == nil && !$0.text.isEmpty }) else { return "" }
        return Self.shorten(last.text, to: 90)
    }

    static func shorten(_ text: String, to limit: Int) -> String {
        // Plain words only: no heading marks, bullets, step numbers, bold or code marks.
        let flat = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: #"^(#{1,6}|[-*•+]|\d{1,3}[.)])\s+"#, with: "", options: .regularExpression) }
            .filter { !$0.isEmpty && !$0.hasPrefix("```") }
            .joined(separator: " ")
            .replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard flat.count > limit else { return flat }
        let cut = flat.prefix(limit)
        let word = cut.lastIndex(of: " ").map { cut[..<$0] } ?? cut
        return word.trimmingCharacters(in: .punctuationCharacters.union(.whitespaces)) + "…"
    }

    /// The whole chat as Markdown, for sharing or saving.
    var markdown: String {
        var out = "# \(displayTitle)\n\n"
        for m in messages {
            switch m.role {
            case .user:
                out += "**You** · \(m.date.formatted(date: .abbreviated, time: .shortened))\n\n\(m.text)\n"
                for a in m.files { out += "\n_Attached: \(a.name)_\n" }
                out += "\n"
            case .assistant:
                guard m.problem == nil, !m.text.isEmpty else { continue }
                out += "**Lockedmind** · written on iPhone\n\n\(m.text)\n\n"
            }
        }
        return out + "---\nMade with Lockedmind, private AI that runs on iPhone.\n"
    }
}

@MainActor @Observable
final class Library {
    /// Pinned first, then newest first.
    private(set) var chats: [Chat] = []

    @ObservationIgnored let base: URL
    @ObservationIgnored private let file: URL
    @ObservationIgnored let pictures: URL
    @ObservationIgnored private var pending: Task<Void, Never>?

    static let backupsKey = "includeInBackups"

    init(folder: URL? = nil) {
        base = folder ?? URL.applicationSupportDirectory.appending(path: "Lockedmind", directoryHint: .isDirectory)
        file = base.appending(path: "chats.json")
        pictures = base.appending(path: "attachments", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: pictures, withIntermediateDirectories: true)
        load()
    }

    func chat(_ id: UUID) -> Chat? { chats.first { $0.id == id } }

    func imageURL(_ attachment: Attachment) -> URL? {
        attachment.imageFile.map { pictures.appending(path: $0) }
    }

    /// Adds or replaces a chat and saves soon after. Empty chats are never kept.
    func put(_ chat: Chat) {
        guard !chat.messages.isEmpty else { return }
        if let i = chats.firstIndex(where: { $0.id == chat.id }) { chats[i] = chat } else { chats.append(chat) }
        sort()
        saveSoon()
    }

    func rename(_ id: UUID, to title: String) {
        guard let i = chats.firstIndex(where: { $0.id == id }) else { return }
        chats[i].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        chats[i].named = true
        saveSoon()
    }

    func togglePin(_ id: UUID) {
        guard let i = chats.firstIndex(where: { $0.id == id }) else { return }
        chats[i].pinnedAt = chats[i].isPinned ? nil : .now
        sort()
        saveSoon()
    }

    func delete(_ id: UUID) {
        if let chat = chat(id) { removePictures(of: chat.messages) }
        chats.removeAll { $0.id == id }
        saveSoon()
    }

    func deleteAll() {
        chats.removeAll()
        try? FileManager.default.removeItem(at: pictures)
        try? FileManager.default.createDirectory(at: pictures, withIntermediateDirectories: true)
        saveNow()
    }

    /// Forgets pictures that belonged to messages being removed.
    func removePictures(of messages: [Message]) {
        for a in messages.flatMap(\.files) {
            if let url = imageURL(a) { try? FileManager.default.removeItem(at: url) }
        }
    }

    private func sort() {
        chats.sort { a, b in
            switch (a.pinnedAt, b.pinnedAt) {
            case let (x?, y?): x > y
            case (.some, nil): true
            case (nil, .some): false
            default: a.updated > b.updated
            }
        }
    }

    // MARK: Disk

    private struct Saved: Codable {
        var version = 1
        var chats: [Chat]
    }

    private func load() {
        guard let data = try? Data(contentsOf: file) else { return }
        do {
            chats = try JSONDecoder.lockedmind.decode(Saved.self, from: data).chats
            sort()
        } catch {
            // Never throw a damaged file away: put it aside and start afresh.
            let aside = file.deletingLastPathComponent()
                .appending(path: "chats-unreadable-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: file, to: aside)
        }
    }

    func saveSoon() {
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        pending?.cancel()
        pending = nil
        do {
            let data = try JSONEncoder.lockedmind.encode(Saved(chats: chats))
            try data.write(to: file, options: [.atomic, .completeFileProtectionUnlessOpen])
            applyBackupChoice()
        } catch {
            assertionFailure("Could not save chats: \(error)")
        }
    }

    /// Chats and their pictures stay out of iCloud and computer backups
    /// unless the person lets them in.
    func applyBackupChoice() {
        let include = UserDefaults.standard.bool(forKey: Self.backupsKey)
        for target in [file, pictures] {
            var values = URLResourceValues()
            values.isExcludedFromBackup = !include
            var url = target
            try? url.setResourceValues(values)
        }
    }
}

extension JSONEncoder {
    static let lockedmind: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

extension JSONDecoder {
    static let lockedmind: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
