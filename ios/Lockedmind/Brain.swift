// Talks to Apple's on-device language model (the Foundation Models
// framework). Everything here runs on the iPhone itself: Lockedmind never
// connects to the internet, so a message cannot leave the phone.
//
// One live session follows the open chat. It is rebuilt from the saved
// messages whenever it falls out of step (another chat, a regenerated reply,
// a changed setting, an app restart), and the history is trimmed from the
// oldest end so it always fits the model's context window.

import Foundation
import FoundationModels
import CoreGraphics

/// What the person chose in Settings, as the model needs it.
struct Voice: Equatable, Sendable {
    enum Length: String, CaseIterable, Identifiable, Sendable {
        case short, balanced, detailed
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    enum Tone: String, CaseIterable, Identifiable, Sendable {
        case warm, professional, playful, direct
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var symbol: String {
            switch self {
            case .warm: "heart"
            case .professional: "briefcase"
            case .playful: "face.smiling"
            case .direct: "arrow.right"
            }
        }
    }

    enum Creativity: String, CaseIterable, Identifiable, Sendable {
        case precise, balanced, creative
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var temperature: Double? {
            switch self {
            case .precise: 0.3
            case .balanced: nil
            case .creative: 1.0
            }
        }
    }

    var length: Length = .balanced
    var tone: Tone = .warm
    var creativity: Creativity = .balanced
    var name = ""
    var about = ""

    static var current: Voice {
        let d = UserDefaults.standard
        return Voice(length: Length(rawValue: d.string(forKey: "length") ?? "") ?? .balanced,
                     tone: Tone(rawValue: d.string(forKey: "tone") ?? "") ?? .warm,
                     creativity: Creativity(rawValue: d.string(forKey: "creativity") ?? "") ?? .balanced,
                     name: d.string(forKey: "name") ?? "",
                     about: d.string(forKey: "about") ?? "")
    }
}

enum BrainError: LocalizedError {
    case tooLong
    var errorDescription: String? {
        "That message is too long for the on-device model. Try a shorter one, or split it in parts."
    }
}

@MainActor
final class Brain {
    private var session: LanguageModelSession?
    private var sessionChat: UUID?
    /// How many of the chat's messages the session already holds; -1 = out of step.
    private var sessionSeen = -1
    private var sessionInstructions = ""
    /// How many earlier messages the last rebuilt session was given.
    private var keptHistory = 0

    static var availability: SystemLanguageModel.Availability { SystemLanguageModel.default.availability }

    /// Whether the on-device model can look at photos (iOS 27 and later).
    static var canSee: Bool {
        if #available(iOS 27.0, *) { return SystemLanguageModel.default.capabilities.contains(.vision) }
        return false
    }

    nonisolated static var contextSize: Int { SystemLanguageModel.default.contextSize }
    static var languageCount: Int { SystemLanguageModel.default.supportedLanguages.count }

    /// Loads the model ahead of the first message, so the reply starts sooner.
    func prewarm(_ chat: Chat, voice: Voice) {
        guard SystemLanguageModel.default.isAvailable else { return }
        let instructions = Self.instructions(for: voice)
        if session == nil || sessionChat != chat.id || sessionInstructions != instructions {
            rebuild(for: chat, history: chat.messages, prompt: "", images: 0, instructions: instructions, length: voice.length)
        }
        session?.prewarm()
    }

    /// Writes the reply to the chat's last message, which must be the person's.
    /// `images` are the photos attached to it, shown to the model when it can
    /// see. `onText` receives the reply so far, many times a second.
    func reply(to chat: Chat, voice: Voice, images: [CGImage] = [], onText: (String) -> Void) async throws -> String {
        guard let prompt = chat.messages.last, prompt.role == .user else { return "" }
        let history = Array(chat.messages.dropLast())
        let instructions = Self.instructions(for: voice)
        let text = Self.promptText(prompt)
        let seen = Self.canSee ? images : []
        let options = GenerationOptions(temperature: voice.creativity.temperature)
        var room = 1.0

        for attempt in 0..<3 {
            if attempt > 0 || session == nil || sessionChat != chat.id
                || sessionSeen != history.count || sessionInstructions != instructions {
                rebuild(for: chat, history: history, prompt: text, images: seen.count, instructions: instructions,
                        length: voice.length, room: room)
            }
            guard let session else { break }
            do {
                var written = ""
                for try await snapshot in stream(session, text: text, images: seen, options: options) {
                    written = snapshot.content
                    onText(written)
                }
                sessionSeen = chat.messages.count + 1
                return written
            } catch {
                sessionSeen = -1
                // Too long: keep less of the history and try again, unless
                // the message alone is already too much.
                guard Self.isContextOverflow(error) else { throw error }
                guard keptHistory > 0 else { throw BrainError.tooLong }
                room /= 2
                onText("")
            }
        }
        throw BrainError.tooLong
    }

    private func stream(_ session: LanguageModelSession, text: String, images: [CGImage],
                        options: GenerationOptions) -> LanguageModelSession.ResponseStream<String> {
        if #available(iOS 27.0, *), !images.isEmpty {
            return session.streamResponse(options: options) {
                text
                for image in images { FoundationModels.Attachment(image) }
            }
        }
        return session.streamResponse(to: text, options: options)
    }

    /// Forgets the live session, e.g. after a reply was stopped half-way.
    func reset() { sessionSeen = -1 }

    private func rebuild(for chat: Chat, history: [Message], prompt: String, images: Int, instructions: String,
                         length: Voice.Length, room: Double = 1) {
        var entries: [Transcript.Entry] = [
            .instructions(Transcript.Instructions(segments: [.text(.init(content: instructions))], toolDefinitions: []))
        ]
        let kept = Self.fit(history, window: Self.contextSize,
                            reserved: Self.tokens(instructions) + Self.tokens(prompt) + images * Self.imageTokens + Self.replyRoom(length),
                            room: room)
        keptHistory = kept.count
        for m in kept {
            let segment = Transcript.Segment.text(.init(content: m.role == .user ? Self.promptText(m) : m.text))
            entries.append(m.role == .user
                           ? .prompt(Transcript.Prompt(segments: [segment]))
                           : .response(Transcript.Response(assetIDs: [], segments: [segment])))
        }
        session = LanguageModelSession(transcript: Transcript(entries: entries))
        sessionChat = chat.id
        sessionSeen = history.count
        sessionInstructions = instructions
    }

    // MARK: Fitting the history into the window

    /// The newest question-and-answer pairs that fit, oldest first. Unanswered
    /// questions and failed replies are left out, so turns always alternate.
    static func fit(_ history: [Message], window: Int, reserved: Int, room: Double) -> [Message] {
        var pairs: [(Message, Message)] = []
        var i = 0
        while i < history.count {
            let m = history[i]
            if m.role == .user, i + 1 < history.count {
                let r = history[i + 1]
                if r.role == .assistant, r.problem == nil, !r.text.isEmpty {
                    pairs.append((m, r))
                    i += 2
                    continue
                }
            }
            i += 1
        }
        var budget = Int(Double(window - reserved) * room)
        var kept: [(Message, Message)] = []
        for pair in pairs.reversed() {
            let cost = tokens(promptText(pair.0)) + tokens(pair.1.text) + 8
            guard cost <= budget else { break }
            budget -= cost
            kept.insert(pair, at: 0)
        }
        return kept.flatMap { [$0.0, $0.1] }
    }

    /// How much of the model's memory this chat fills (can go past 1), and the
    /// first message it still remembers when older ones no longer fit.
    static func memory(of chat: Chat, voice: Voice) -> (used: Double, firstRemembered: UUID?) {
        let instructions = instructions(for: voice)
        let all = chat.messages.reduce(tokens(instructions)) { $0 + tokens(promptText($1)) + 4 }
        let used = Double(all + replyRoom(voice.length)) / Double(max(contextSize, 1))
        guard used > 1 else { return (used, nil) }
        let kept = fit(chat.messages, window: contextSize,
                       reserved: tokens(instructions) + replyRoom(voice.length) + 200, room: 1)
        return (used, kept.first?.id)
    }

    /// A deliberately generous token estimate: a token per three bytes of UTF-8.
    /// English runs nearer four characters a token; Chinese or Japanese about one.
    static func tokens(_ text: String) -> Int { text.utf8.count / 3 + 4 }
    static let imageTokens = 700

    static func replyRoom(_ length: Voice.Length) -> Int {
        switch length {
        case .short: 350
        case .balanced: 800
        case .detailed: 1300
        }
    }

    /// The most text one message may bring in from attachments.
    nonisolated static var attachmentBudget: Int { max(1500, contextSize * 3 / 2) }

    /// A person's message as the model reads it: their words, then whatever
    /// was read from the photos, scans and files they attached.
    static func promptText(_ m: Message) -> String {
        guard !m.files.isEmpty else { return m.text }
        var out = m.text.isEmpty ? "(The user sent attachments without a message: help with them.)" : m.text
        for a in m.files {
            let kind = switch a.kind {
            case .photo: "photo"
            case .scan: "scanned document"
            case .file: "file"
            }
            let text = a.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty {
                out += "\n\n[Attached \(kind) \"\(a.name)\": no text could be read from it.]"
            } else {
                out += "\n\n[Attached \(kind) \"\(a.name)\". Text read from it:]\n\(text)\n[End of \(kind)\(a.shortened == true ? ", shortened to fit" : "")]"
            }
        }
        return out
    }

    static func isContextOverflow(_ error: Error) -> Bool {
        if #available(iOS 27.0, *), let e = error as? LanguageModelError, case .contextSizeExceeded = e { return true }
        if let e = error as? LanguageModelSession.GenerationError, case .exceededContextWindowSize = e { return true }
        return ["contextSizeExceeded", "exceededContextWindowSize"].contains(caseName(error))
    }

    // MARK: Words

    static func instructions(for voice: Voice, now: Date = .now) -> String {
        // Kept short on purpose: Apple's on-device model is small, and long
        // lists of rules leak into answers (it would announce its own name,
        // or add headings to a text message).
        var lines = [
            "You are Lockedmind, a warm, sharp and helpful assistant that runs privately on the user's iPhone. You have no internet access.",
            "Answer directly, with no preamble, and stop when the question is answered. Keep greetings and simple questions short and plain.",
            "For longer explanations you may use short \"### \" headings, \"- \" bullet points, \"1. \" numbered steps and a little **bold**.",
            "If the user asks you to write a message, email or post for them, reply with just that text, written as plain sentences with no bullet points or headings.",
            "If you're not sure of something, say so. Never make up facts, names or numbers.",
            canSee
                ? "You can see photos the user attaches. Text read from attached documents appears after their message."
                : "You can't see images, but text read from photos and documents the user attaches appears after their message.",
            "(For reference only, in case the user asks: today is \(now.formatted(.dateTime.weekday(.wide).day().month(.wide).year())).)",
        ]
        switch voice.tone {
        case .warm: break
        case .professional: lines.append("Use a polished, professional tone.")
        case .playful: lines.append("Be light and playful, with a touch of humour where it fits.")
        case .direct: lines.append("Be direct and get straight to the point, without small talk.")
        }
        switch voice.length {
        case .short: lines.append("Keep every answer brief: a few sentences at most, unless the user asks for more.")
        case .balanced: break
        case .detailed: lines.append("Give thorough answers, with an example where it helps.")
        }
        let first = voice.name.trimmingCharacters(in: .whitespaces).split(separator: " ").first.map(String.init) ?? ""
        if !first.isEmpty { lines.append("The user's name is \(first).") }
        let about = voice.about.trimmingCharacters(in: .whitespacesAndNewlines)
        if !about.isEmpty { lines.append("What the user wants you to know about them: \(about.prefix(600))") }
        return lines.joined(separator: "\n")
    }

    /// A short name for a new chat, from its first message. Nil if the model can't.
    static func title(for text: String) async -> String? {
        guard SystemLanguageModel.default.isAvailable else { return nil }
        let session = LanguageModelSession(instructions: "You name conversations. Reply with a title of 2 to 5 words and nothing else: no quotes, no full stop.")
        let options = GenerationOptions(temperature: 0.2, maximumResponseTokens: 16)
        guard let reply = try? await session.respond(to: "Name a conversation that starts with this message:\n\n\(text.prefix(500))", options: options) else { return nil }
        var title = reply.content.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        title = title.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "Title:", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’#*.:").union(.whitespaces))
        guard (2...48).contains(title.count) else { return nil }
        return title
    }

    /// Three questions the person might ask next. Empty if the model can't.
    static func followUps(question: String, answer: String) async -> [String] {
        guard SystemLanguageModel.default.isAvailable else { return [] }
        let session = LanguageModelSession(instructions: "You suggest what a user might ask next. Reply with exactly three short questions, each under nine words, one per line, with no numbers, bullets or quotes.")
        let prompt = "The user asked:\n\(question.prefix(400))\n\nThe answer was:\n\(answer.prefix(1500))\n\nWrite three follow-up questions the user might ask next, in the user's language."
        guard let reply = try? await session.respond(to: prompt, options: GenerationOptions(temperature: 0.6, maximumResponseTokens: 90)) else { return [] }
        let lines = reply.content.split(whereSeparator: \.isNewline).map { line in
            line.trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: #"^([-*•]|\d+[.)])\s*"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’*").union(.whitespaces))
        }
        return Array(lines.filter { (4...70).contains($0.count) && !$0.lowercased().hasPrefix("here") }.prefix(3))
    }

    /// What to tell the person when a reply fails, in plain words.
    static func explain(_ error: Error) -> String {
        if let e = error as? BrainError { return e.localizedDescription }
        if isContextOverflow(error) { return BrainError.tooLong.localizedDescription }
        if let e = error as? LanguageModelSession.GenerationError, case .assetsUnavailable = e {
            return "Apple's on-device model isn't ready right now. Check that Apple Intelligence is on, then try again."
        }
        switch caseName(error) {
        case "guardrailViolation", "refusal": return refused
        case "rateLimited", "concurrentRequests": return busy
        case "unsupportedLanguageOrLocale": return language
        case "unsupportedCapability", "unsupportedTranscriptContent":
            return "Apple's on-device model can't take this kind of attachment on this iPhone. Try sending the text instead."
        default: return "Something went wrong writing that reply. Try again."
        }
    }

    /// The error's case, e.g. "contextSizeExceeded". iOS 27 throws a new error
    /// type even to apps built for iOS 26, so errors are matched by name.
    static func caseName(_ error: Error) -> String {
        Mirror(reflecting: error).children.first?.label ?? ""
    }

    private static let refused = "Apple's on-device model won't answer this one: its safety filter stepped in. Try putting it another way."
    private static let busy = "Your iPhone paused the model, which happens when Lockedmind is in the background. Try again."
    private static let language = "Apple's on-device model doesn't speak this language yet. Try English or another language Apple Intelligence supports."
}
