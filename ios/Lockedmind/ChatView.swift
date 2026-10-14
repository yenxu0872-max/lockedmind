// The main screen. A conversation reads like pages of a private journal:
// each question in bold, each answer beneath it, joined by a thin thread of
// light down the left side, with the day marked where it changes. The orb is
// the send button; light rises from the bottom of the screen while the mind
// is thinking; and the header always says whether the iPhone is online.

import SwiftUI
import UIKit
import PhotosUI

struct ChatView: View {
    @Environment(AppModel.self) private var app
    @Environment(Dictation.self) private var dictation
    @State private var draft = ""
    @FocusState private var typing: Bool
    @State private var showChats = false

    @State private var position = ScrollPosition(edge: .bottom)
    @State private var follow = true          // keep the newest words in view
    @State private var gap: CGFloat = 0       // distance from the bottom
    @State private var dragging = false

    @State private var renaming = false
    @State private var newTitle = ""
    @State private var confirmDelete = false
    @State private var problem: String?

    private var hasDraft: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !app.attachments.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if app.current.messages.isEmpty {
                    EmptyChat(isTyping: hasDraft) { prompt in send(prompt) }
                } else {
                    conversation
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                Paper(energy: app.isResponding ? 1 : (hasDraft || dictation.isListening ? 0.5 : 0.3))
                    .animation(.easeInOut(duration: 0.9), value: app.isResponding)
                    .animation(.easeInOut(duration: 0.6), value: hasDraft)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Composer(text: $draft, typing: $typing, send: { send(draft) }, problem: $problem)
            }
            .overlay(alignment: .bottomTrailing) { downButton }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showChats = true } label: { Image(systemName: "rectangle.stack") }
                        .accessibilityLabel("Chats")
                }
                ToolbarItem(placement: .principal) { header }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { app.newChat(); draft = ""; typing = true } label: { Image(systemName: "square.and.pencil") }
                        .accessibilityLabel("New chat")
                        .disabled(app.current.messages.isEmpty)
                }
            }
            .sheet(isPresented: $showChats) { ChatsView() }
            .alert("Rename chat", isPresented: $renaming) {
                TextField("Title", text: $newTitle)
                Button("Cancel", role: .cancel) {}
                Button("Rename") { app.rename(app.current.id, to: newTitle) }
            }
            .confirmationDialog("Delete this chat?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete chat", role: .destructive) { app.delete(app.current.id) }
            } message: {
                Text("It's only on this iPhone, so it can't be brought back.")
            }
            .alert("Lockedmind", isPresented: Binding(get: { problem != nil || app.notice != nil },
                                                     set: { if !$0 { problem = nil; app.notice = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(problem ?? app.notice ?? "")
            }
            #if PREVIEW
            .onReceive(NotificationCenter.default.publisher(for: PreviewHarness.showChats)) { _ in showChats = true }
            #endif
        }
        .sensoryFeedback(.impact(weight: .light), trigger: app.sends)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: app.firstWords)
    }

    // MARK: Header

    /// The chat's name (tap for what you can do with the chat), and under it
    /// whether the iPhone is online.
    private var header: some View {
        VStack(spacing: 2) {
            if app.current.messages.isEmpty {
                Text("Lockedmind")
                    .font(Theme.ui(.subheadline, .semibold))
            } else {
                Menu { chatMenu } label: {
                    HStack(spacing: 4) {
                        if app.current.isPinned {
                            Image(systemName: "pin.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.accent)
                        }
                        Text(app.current.displayTitle).lineLimit(1)
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                    }
                    .font(Theme.ui(.subheadline, .semibold))
                    .foregroundStyle(.primary)
                }
                .tint(.primary)
                .accessibilityLabel("\(app.current.displayTitle), chat options")
            }
            ConnectionStatus()
        }
        .frame(maxWidth: 240)
    }

    @ViewBuilder private var chatMenu: some View {
        let memory = Brain.memory(of: app.current, voice: .current)
        Section {
            Button { newTitle = app.current.displayTitle; renaming = true } label: { Label("Rename", systemImage: "pencil") }
            Button { app.togglePin(app.current.id) } label: {
                Label(app.current.isPinned ? "Unpin" : "Pin", systemImage: app.current.isPinned ? "pin.slash" : "pin")
            }
            ShareLink(item: app.current.markdown, preview: SharePreview(app.current.displayTitle)) {
                Label("Share chat", systemImage: "square.and.arrow.up")
            }
        }
        Section {
            Label(memory.used > 1 ? "Memory full: remembers the newest part" : "Memory \(Int((memory.used * 100).rounded()))% used",
                  systemImage: "brain.head.profile")
            Label("\(app.current.messages.filter { $0.role == .user }.count) questions · started \(app.current.created.formatted(date: .abbreviated, time: .omitted))",
                  systemImage: "calendar")
        }
        Section {
            Button(role: .destructive) { confirmDelete = true } label: { Label("Delete chat", systemImage: "trash") }
        }
    }

    // MARK: The conversation

    private var conversation: some View {
        let messages = app.current.messages
        let remembered = Brain.memory(of: app.current, voice: .current).firstRemembered
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                    if message.role == .user, let day = Self.dayLabel(messages, at: index) {
                        Marker(text: day, symbol: nil, line: index > 0)
                    }
                    if message.id == remembered, index > 0 {
                        Marker(text: "Older messages are beyond Lockedmind's memory now", symbol: "brain.head.profile", line: true)
                    }
                    Page(message: message,
                         first: index == 0,
                         last: index == messages.count - 1,
                         isWriting: app.isResponding && index == messages.count - 1,
                         actions: PageActions(
                            regenerate: app.regenerate,
                            ask: { send($0) },
                            edit: { m in draft = app.beginEdit(m); typing = true }))
                        .id(message.id)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .scrollPosition($position)
        .defaultScrollAnchor(.bottom)
        .scrollDismissesKeyboard(.interactively)
        .onScrollGeometryChange(for: CGFloat.self) { g in
            g.contentSize.height + g.contentInsets.bottom - g.visibleRect.maxY
        } action: { _, new in
            gap = new
        }
        .onScrollPhaseChange { _, phase in
            dragging = phase == .interacting || phase == .tracking
            if phase == .idle { follow = gap < 60 }
            if dragging { follow = false }
        }
        .onChange(of: app.current.messages.last?.text) {
            if follow && !dragging { position.scrollTo(edge: .bottom) }
        }
        .onChange(of: app.current.messages.last?.followUps) {
            if follow && !dragging { withAnimation(.smooth) { position.scrollTo(edge: .bottom) } }
        }
        .onChange(of: app.current.id) { follow = true; position.scrollTo(edge: .bottom) }
    }

    /// "Today · 9:41" above the first question of each day.
    static func dayLabel(_ messages: [Message], at index: Int) -> String? {
        let date = messages[index].date
        if index > 0, Calendar.current.isDate(messages[index - 1].date, inSameDayAs: date) { return nil }
        let time = date.formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInToday(date) { return "Today · \(time)" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday · \(time)" }
        return "\(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))) · \(time)"
    }

    @ViewBuilder private var downButton: some View {
        if !app.current.messages.isEmpty && gap > 400 {
            Button {
                follow = true
                withAnimation(.smooth) { position.scrollTo(edge: .bottom) }
            } label: {
                Image(systemName: "arrow.down")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .glassEffect(.regular.interactive(), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 18)
            .padding(.bottom, 90)
            .transition(.scale.combined(with: .opacity))
            .accessibilityLabel("Jump to the newest message")
        }
    }

    private func send(_ text: String) {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasText || !app.attachments.isEmpty, app.canSend else { return }
        dictation.stop()
        app.send(text)
        draft = ""
        follow = true
        withAnimation(.smooth) { position.scrollTo(edge: .bottom) }
    }
}

// MARK: - Markers in the thread

/// A quiet line in the thread: the day, or where the model's memory begins.
private struct Marker: View {
    let text: String
    let symbol: String?
    let line: Bool

    var body: some View {
        HStack(spacing: 6) {
            if let symbol { Image(systemName: symbol).font(.system(size: 10, weight: .semibold)) }
            Text(text)
        }
        .font(Theme.ui(.caption, .medium))
        .foregroundStyle(.tertiary)
        .padding(.leading, 34)
        .padding(.top, 26)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .leading) {
            Rectangle().fill(Theme.thread).frame(width: 1.5).opacity(line ? 1 : 0)
                .frame(width: 22)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - A page: one question or one answer

struct PageActions {
    let regenerate: () -> Void
    let ask: (String) -> Void
    let edit: (Message) -> Void
}

struct Page: View {
    let message: Message
    let first: Bool
    let last: Bool
    let isWriting: Bool
    let actions: PageActions

    @Environment(AppModel.self) private var app
    @Environment(Speaker.self) private var speaker
    @Environment(\.dynamicTypeSize) private var size
    @ScaledMetric(relativeTo: .title3) private var questionMid: CGFloat = 13
    @ScaledMetric(relativeTo: .body) private var answerMid: CGFloat = 11
    @State private var copied = false
    @State private var unfolded = false

    private var isQuestion: Bool { message.role == .user }
    private var topPad: CGFloat { isQuestion ? (first ? 12 : 22) : 10 }
    /// Where the marker sits: beside the first line of words, below any attachments.
    private var attachmentHeight: CGFloat { isQuestion && !message.files.isEmpty ? 62 : 0 }

    var body: some View {
        Group {
            if isQuestion { question } else { answer }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 34)
        .padding(.top, topPad)
        .padding(.bottom, isQuestion ? 4 : 6)
        .background(alignment: .leading) {
            Thread(marker: isQuestion ? .question : .answer(thinking: isWriting && message.text.isEmpty),
                   markerY: topPad + attachmentHeight + (isQuestion ? questionMid : answerMid),
                   above: !first, below: !last)
                .frame(width: 22)
        }
    }

    // The question, in the person's own words.

    /// Long pasted messages are folded after a dozen lines.
    private var foldable: Bool { message.text.count > 600 || message.text.filter(\.isNewline).count > 10 }
    private var long: Bool { message.text.count > 220 }

    private var question: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !message.files.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(message.files) { AttachmentCard(attachment: $0, url: app.library.imageURL($0)) }
                    }
                }
                .scrollIndicators(.hidden)
                .frame(height: 54)
            }
            if !message.text.isEmpty {
                Text(message.text)
                    .font(long ? Theme.ui(.body, .medium) : Theme.question)
                    .lineSpacing(1)
                    .lineLimit(foldable && !unfolded ? 12 : nil)
                    .textSelection(.enabled)
            }
            if foldable {
                Button(unfolded ? "Show less" : "Show all") { withAnimation(.smooth) { unfolded.toggle() } }
                    .font(Theme.ui(.footnote, .semibold))
                    .buttonStyle(.borderless)
            }
        }
        .contextMenu {
            Button { UIPasteboard.general.string = message.text } label: { Label("Copy", systemImage: "doc.on.doc") }
            if !app.isResponding {
                Button { actions.edit(message) } label: { Label("Edit and ask again", systemImage: "pencil") }
            }
            ShareLink(item: message.text) { Label("Share", systemImage: "square.and.arrow.up") }
            Text("Asked \(message.date.formatted(date: .abbreviated, time: .shortened))")
        }
    }

    // The answer, written on this iPhone.

    @ViewBuilder private var answer: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let problem = message.problem {
                Text(problem)
                    .font(Theme.ui(.body).italic())
                    .foregroundStyle(.secondary)
                if last && problem != BrainError.tooLong.localizedDescription {
                    Button("Try again", systemImage: "arrow.clockwise", action: actions.regenerate)
                        .font(Theme.ui(.subheadline, .semibold))
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                }
            } else if message.text.isEmpty && isWriting {
                ThinkingLine(text: message.files.isEmpty ? "Thinking on this iPhone…" : "Reading and thinking on this iPhone…")
            } else {
                MarkdownView(text: message.text)
                    .textSelection(.enabled)
                    .mask { if isWriting { InkMask() } else { Rectangle() } }
                if !isWriting {
                    seal
                    if last, let next = message.followUps, !next.isEmpty { followUps(next) }
                }
            }
        }
    }

    /// Under every finished answer: where it was made, and what you can do with it.
    /// With very large text the two go on separate lines.
    @ViewBuilder private var seal: some View {
        if size.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                sealLabel
                HStack(spacing: 22) { tools }
            }
            .padding(.top, 2)
        } else {
            HStack(spacing: 16) {
                sealLabel
                Spacer(minLength: 4)
                tools
            }
            .padding(.top, 2)
        }
    }

    private var sealLabel: some View {
        Label(sealText, systemImage: "lock.fill")
            .labelStyle(TightLabel())
            .font(Theme.ui(.caption))
            .foregroundStyle(.tertiary)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }

    private var sealText: String {
        var parts = ["On this iPhone"]
        if let s = message.seconds { parts.append(s < 10 ? String(format: "%.1f s", s) : "\(Int(s.rounded())) s") }
        parts.append("\(message.words) words")
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private var tools: some View {
        Group {
            Button {
                UIPasteboard.general.string = message.text
                copied = true
                Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .contentTransition(.symbolEffect(.replace))
            }
            .accessibilityLabel(copied ? "Copied" : "Copy")
            Button { speaker.toggle(message) } label: {
                Image(systemName: speaker.speaking == message.id ? "stop.circle" : "speaker.wave.2")
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.variableColor.iterative, isActive: speaker.speaking == message.id)
            }
            .accessibilityLabel(speaker.speaking == message.id ? "Stop reading" : "Read aloud")
            ShareLink(item: message.text) { Image(systemName: "square.and.arrow.up") }
                .accessibilityLabel("Share")
            if last {
                Button(action: actions.regenerate) { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("Write it again")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .buttonStyle(.borderless)
    }

    /// Questions to ask next, one tap each.
    private func followUps(_ next: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(next, id: \.self) { question in
                Button { actions.ask(question) } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.orb)
                        Text(question)
                            .font(Theme.ui(.subheadline, .medium))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.card.opacity(0.9), in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.hairline))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

/// While words are still arriving, the newest line fades in like wet ink.
private struct InkMask: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
            LinearGradient(colors: [.black, .black.opacity(0.08)], startPoint: .top, endPoint: .bottom)
                .frame(height: 30)
        }
    }
}

/// The thread down the left side: a ring for each question, a small orb for
/// each answer, and a line of light joining them.
private struct Thread: View {
    enum Marker: Equatable { case question, answer(thinking: Bool) }
    let marker: Marker
    let markerY: CGFloat
    let above: Bool
    let below: Bool

    private let size: CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            line.frame(height: max(0, markerY - size / 2 - 3)).opacity(above ? 1 : 0)
            Group {
                switch marker {
                case .question:
                    Circle()
                        .strokeBorder(Theme.orb, lineWidth: 2)
                        .background(Circle().fill(Theme.paper))
                        .frame(width: size, height: size)
                case .answer(let thinking):
                    LivingOrb(size: size + 2, mood: thinking ? .thinking : .resting, keyhole: false,
                              glow: thinking, animated: thinking)
                        .frame(width: size, height: size)
                }
            }
            .padding(.vertical, 3)
            line.frame(maxHeight: .infinity).opacity(below ? 1 : 0)
        }
    }

    private var line: some View {
        Rectangle().fill(Theme.thread).frame(width: 1.5)
    }
}

// MARK: - Writing a message

struct Composer: View {
    @Binding var text: String
    var typing: FocusState<Bool>.Binding
    let send: () -> Void
    @Binding var problem: String?

    @Environment(AppModel.self) private var app
    @Environment(Dictation.self) private var dictation
    @State private var choosingPhoto = false
    @State private var photo: PhotosPickerItem?
    @State private var choosingFile = false
    @State private var scanning = false

    private var canSend: Bool {
        (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !app.attachments.isEmpty) && app.reading == 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if app.editing != nil {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                    Text("Editing your question: sending replaces it and its answer")
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 4)
                    Button("Cancel") { app.cancelEdit(); text = "" }
                        .font(Theme.ui(.caption, .semibold))
                }
                .font(Theme.ui(.caption, .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
            if !app.attachments.isEmpty || app.reading > 0 {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(app.attachments) { a in
                            AttachmentCard(attachment: a, url: app.library.imageURL(a)) { app.removeAttachment(a.id) }
                        }
                        if app.reading > 0 { ReadingCard() }
                    }
                    .padding(.horizontal, 10)
                }
                .scrollIndicators(.hidden)
                .padding(.top, 10)
            }
            HStack(alignment: .bottom, spacing: 2) {
                attachMenu
                if dictation.isListening {
                    listening
                } else {
                    TextField(app.editing == nil ? "Ask anything, privately" : "Change your question", text: $text, axis: .vertical)
                        .font(Theme.ui(.body))
                        .lineLimit(1...6)
                        .focused(typing)
                        .padding(.vertical, 13)
                        .padding(.leading, 4)
                }
                if !app.isResponding { micButton }
                sendButton
            }
        }
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .animation(.smooth(duration: 0.3), value: app.attachments)
        .animation(.smooth(duration: 0.3), value: dictation.isListening)
        .photosPicker(isPresented: $choosingPhoto, selection: $photo, matching: .images)
        .onChange(of: photo) {
            if let photo { app.addPhoto(photo); self.photo = nil }
        }
        .fileImporter(isPresented: $choosingFile, allowedContentTypes: Reader.fileTypes) { result in
            if case .success(let url) = result { app.addFile(url) }
        }
        .fullScreenCover(isPresented: $scanning) {
            DocumentScanner { pages in
                scanning = false
                app.addScan(pages)
            }
            .ignoresSafeArea()
        }
    }

    private var attachMenu: some View {
        Menu {
            Button { choosingPhoto = true } label: { Label("Photo", systemImage: "photo.on.rectangle") }
            if DocumentScanner.isAvailable {
                Button { scanning = true } label: { Label("Scan a document", systemImage: "doc.viewfinder") }
            }
            Button { choosingFile = true } label: { Label("File or PDF", systemImage: "doc") }
            Section(Brain.canSee ? "Read and seen on this iPhone" : "Read on this iPhone") {}
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 46)
        }
        .disabled(app.isResponding)
        .accessibilityLabel("Attach a photo, scan or file")
        .padding(.leading, 6)
    }

    private var micButton: some View {
        Button {
            if dictation.isListening { dictation.stop(); return }
            Task {
                do { try await dictation.start(prefix: text) { text = $0 } }
                catch { problem = error.localizedDescription }
            }
        } label: {
            Image(systemName: dictation.isListening ? "mic.fill" : "mic")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(dictation.isListening ? AnyShapeStyle(Theme.orb) : AnyShapeStyle(.secondary))
                .frame(width: 36, height: 46)
                .symbolEffect(.pulse, isActive: dictation.isListening)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dictation.isListening ? "Stop dictation" : "Dictate")
    }

    /// While listening: a small meter that moves with the voice, and the words so far.
    private var listening: some View {
        HStack(spacing: 10) {
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { i in
                    let wave = [0.5, 0.8, 1.0, 0.8, 0.5][i]
                    Capsule()
                        .fill(Theme.orb)
                        .frame(width: 3, height: 6 + 18 * dictation.level * wave)
                }
            }
            .animation(.easeOut(duration: 0.12), value: dictation.level)
            Text(text.isEmpty ? "Listening, on this iPhone…" : text)
                .font(Theme.ui(.body))
                .foregroundStyle(text.isEmpty ? .secondary : .primary)
                .lineLimit(3)
                .truncationMode(.head)
        }
        .padding(.vertical, 13)
        .padding(.leading, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The orb is the send button: it wakes when there is something to send,
    /// and swirls (tap to stop) while the answer is being written.
    private var sendButton: some View {
        Button(action: app.isResponding ? app.stop : send) {
            LivingOrb(size: 38,
                      mood: app.isResponding ? .thinking : (canSend ? .ready : .resting),
                      keyhole: false,
                      glyph: app.isResponding ? "stop.fill" : "arrow.up",
                      glow: canSend || app.isResponding,
                      animated: canSend || app.isResponding)
                .saturation(canSend || app.isResponding ? 1 : 0)
                .opacity(canSend || app.isResponding ? 1 : 0.35)
                .animation(.smooth(duration: 0.35), value: canSend)
        }
        .buttonStyle(.plain)
        .disabled(!canSend && !app.isResponding)
        .padding(6)
        .accessibilityLabel(app.isResponding ? "Stop" : "Send")
    }
}

// MARK: - A new chat

struct EmptyChat: View {
    let isTyping: Bool
    let pick: (String) -> Void
    @AppStorage("name") private var name = ""
    @State private var touched = 0
    @Environment(\.dynamicTypeSize) private var size
    @Environment(Connection.self) private var connection

    init(isTyping: Bool, pick: @escaping (String) -> Void) {
        self.isTyping = isTyping
        self.pick = pick
    }

    private struct Starter: Identifiable {
        let icon: String, kind: String, text: String, prompt: String
        var id: String { text }
    }

    private let starters = [
        Starter(icon: "envelope.open", kind: "Write", text: "Help me say no to a party, nicely.",
                prompt: "Help me write a friendly message turning down an invitation to a party this weekend."),
        Starter(icon: "lightbulb", kind: "Learn", text: "Explain compound interest like I'm twelve.",
                prompt: "Explain how compound interest works, simply, with a quick example."),
        Starter(icon: "calendar", kind: "Plan", text: "Plan a calm, healthy week around work.",
                prompt: "Help me plan a balanced week: I work 9 to 5, want to exercise three times and cook at home more."),
        Starter(icon: "gift", kind: "Ideas", text: "Gift ideas for a friend who loves cooking.",
                prompt: "Give me 8 thoughtful birthday gift ideas for a friend who loves cooking and hiking."),
        Starter(icon: "chevron.left.forwardslash.chevron.right", kind: "Code", text: "Write a Swift function to reverse words.",
                prompt: "Write a short Swift function that reverses the order of words in a sentence, with an example."),
        Starter(icon: "leaf", kind: "Feel better", text: "A two-minute way to calm down.",
                prompt: "Give me a simple two-minute exercise to calm down when I feel stressed."),
    ]

    private var greeting: String {
        let first = name.split(separator: " ").first.map(String.init) ?? ""
        let hour = Calendar.current.component(.hour, from: .now)
        let part = hour < 5 ? "Still up" : hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
        return first.isEmpty ? "\(part).\nWhat's on your mind?" : "\(part), \(first).\nWhat's on your mind?"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)
            LivingOrb(size: size.isAccessibilitySize ? 84 : 124, mood: isTyping ? .ready : .resting)
                .scaleEffect(touched % 2 == 0 ? 1 : 1.06)
                .animation(.spring(response: 0.35, dampingFraction: 0.5), value: touched)
                .onTapGesture { touched += 1 }
                .sensoryFeedback(.impact(flexibility: .soft), trigger: touched)
            Text(greeting)
                .font(Theme.ui(.title2, .semibold))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, size.isAccessibilitySize ? 30 : 42)
                .padding(.horizontal, 24)
            HStack(spacing: 8) {
                PrivateBadge(text: "Private", icon: "lock.fill")
                PrivateBadge(text: connection.isOnline ? "Needs no internet" : "Offline · still works",
                             icon: connection.isOnline ? "icloud.slash" : "wifi.slash")
            }
            .padding(.top, 14)
            Spacer(minLength: 24)
            HStack {
                Text("Try asking")
                    .font(Theme.ui(.footnote, .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 8)
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(starters) { starter in
                        Button { pick(starter.prompt) } label: { card(starter) }
                            .buttonStyle(.plain)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
                .fixedSize(horizontal: false, vertical: true)    // as tall as the tallest card, no taller
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .padding(.bottom, 14)
        }
    }

    private func card(_ starter: Starter) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: starter.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.orb)
                Text(starter.kind.uppercased())
                    .font(Theme.ui(.caption2, .semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
            }
            Text(starter.text)
                .font(Theme.ui(.callout, .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: size.isAccessibilitySize ? 290 : 190, alignment: .topLeading)
        .frame(minHeight: 120, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.hairline))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}
