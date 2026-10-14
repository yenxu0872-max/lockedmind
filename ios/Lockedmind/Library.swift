// The chats, and where they are kept: one JSON file in the app's own
// Application Support folder, written atomically and locked by iOS data
// protection. By default it is also left out of iCloud and computer backups,
// so a chat exists only on this iPhone (Settings can let it into backups).

import Foundation
import Observation

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
}

struct Chat: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var title = ""
    var messages: [Message] = []
    var created = Date()
    var updated = Date()

    var displayTitle: String {
        if !title.isEmpty { return title }
        guard let first = messages.first(where: { $0.role == .user })?.text else { return "New chat" }
        return Self.shorten(first, to: 40)
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
}

@MainActor @Observable
final class Library {
    /// Newest first.
    private(set) var chats: [Chat] = []

    @ObservationIgnored private let file: URL
    @ObservationIgnored private var pending: Task<Void, Never>?

    static let backupsKey = "includeInBackups"

    init(folder: URL? = nil) {
        let base = folder ?? URL.applicationSupportDirectory.appending(path: "Lockedmind", directoryHint: .isDirectory)
        file = base.appending(path: "chats.json")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        load()
    }

    func chat(_ id: UUID) -> Chat? { chats.first { $0.id == id } }

    /// Adds or replaces a chat and saves soon after. Empty chats are never kept.
    func put(_ chat: Chat) {
        guard !chat.messages.isEmpty else { return }
        if let i = chats.firstIndex(where: { $0.id == chat.id }) { chats[i] = chat } else { chats.append(chat) }
        chats.sort { $0.updated > $1.updated }
        saveSoon()
    }

    func rename(_ id: UUID, to title: String) {
        guard let i = chats.firstIndex(where: { $0.id == id }) else { return }
        chats[i].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        saveSoon()
    }

    func delete(_ id: UUID) {
        chats.removeAll { $0.id == id }
        saveSoon()
    }

    func deleteAll() {
        chats.removeAll()
        saveNow()
    }

    // MARK: Disk

    private struct Saved: Codable {
        var version = 1
        var chats: [Chat]
    }

    private func load() {
        guard let data = try? Data(contentsOf: file) else { return }
        do {
            chats = try JSONDecoder.lockedmind.decode(Saved.self, from: data).chats.sorted { $0.updated > $1.updated }
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

    /// Chats stay out of iCloud and computer backups unless the person lets them in.
    func applyBackupChoice() {
        let include = UserDefaults.standard.bool(forKey: Self.backupsKey)
        var values = URLResourceValues()
        values.isExcludedFromBackup = !include
        var url = file
        try? url.setResourceValues(values)
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
