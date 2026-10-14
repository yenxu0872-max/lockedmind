// The main screen. A conversation reads like pages of a private journal:
// each question in bold, each answer in serif beneath it, joined by a thin
// thread of light down the left side. The orb is the send button, and light
// rises from the bottom of the screen while the mind is thinking.

import SwiftUI
import UIKit

struct ChatView: View {
    @Environment(AppModel.self) private var app
    @State private var draft = ""
    @FocusState private var typing: Bool
    @State private var showChats = false

    @State private var position = ScrollPosition(edge: .bottom)
    @State private var follow = true          // keep the newest words in view
    @State private var gap: CGFloat = 0       // distance from the bottom
    @State private var dragging = false

    private var hasDraft: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

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
            .background(alignment: .bottom) {
                Aurora(energy: app.isResponding ? 1 : (hasDraft ? 0.5 : 0.3))
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.9), value: app.isResponding)
                    .animation(.easeInOut(duration: 0.6), value: hasDraft)
            }
            .background(Theme.paper.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Composer(text: $draft, typing: $typing, isResponding: app.isResponding,
                         send: { send(draft) }, stop: app.stop)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showChats = true } label: { Image(systemName: "rectangle.stack") }
                        .accessibilityLabel("Chats")
                }
                ToolbarItem(placement: .principal) { header }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { app.newChat(); typing = true } label: { Image(systemName: "square.and.pencil") }
                        .accessibilityLabel("New chat")
                        .disabled(app.current.messages.isEmpty)
                }
            }
            .sheet(isPresented: $showChats) { ChatsView() }
            #if PREVIEW
            .onReceive(NotificationCenter.default.publisher(for: PreviewHarness.showChats)) { _ in showChats = true }
            #endif
        }
        .sensoryFeedback(.impact(weight: .light), trigger: app.sends)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: app.firstWords)
    }

    /// The chat's name, and underneath it, where it lives.
    private var header: some View {
        VStack(spacing: 1) {
            Text(app.current.messages.isEmpty ? "Lockedmind" : app.current.displayTitle)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .lineLimit(1)
            Label("on this iPhone", systemImage: "lock.fill")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
                .labelStyle(TightLabel())
        }
        .accessibilityElement(children: .combine)
    }

    private var conversation: some View {
        let messages = app.current.messages
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                    Page(message: message,
                         first: index == 0,
                         last: index == messages.count - 1,
                         isWriting: app.isResponding && index == messages.count - 1,
                         regenerate: app.regenerate)
                        .id(message.id)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
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
        .onChange(of: app.current.id) { follow = true; position.scrollTo(edge: .bottom) }
    }

    private func send(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !app.isResponding else { return }
        app.send(text)
        draft = ""
        follow = true
        withAnimation(.smooth) { position.scrollTo(edge: .bottom) }
    }
}

struct TightLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}

// MARK: - A page: one question or one answer

struct Page: View {
    let message: Message
    let first: Bool
    let last: Bool
    let isWriting: Bool
    let regenerate: () -> Void

    @ScaledMetric(relativeTo: .title3) private var questionMid: CGFloat = 13
    @ScaledMetric(relativeTo: .body) private var answerMid: CGFloat = 11
    @State private var copied = false
    @State private var unfolded = false
    @Environment(\.dynamicTypeSize) private var size

    private var isQuestion: Bool { message.role == .user }
    private var topPad: CGFloat { isQuestion ? (first ? 14 : 30) : 10 }

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
                   markerY: topPad + (isQuestion ? questionMid : answerMid),
                   above: !first, below: !last)
                .frame(width: 22)
        }
    }

    // The question, in the person's own words.

    /// Long pasted messages are folded after a dozen lines.
    private var foldable: Bool { message.text.count > 600 || message.text.filter(\.isNewline).count > 10 }
    private var long: Bool { message.text.count > 220 }

    private var question: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message.text)
                .font(long ? .system(.body, design: .rounded).weight(.medium) : Theme.question)
                .lineLimit(foldable && !unfolded ? 12 : nil)
                .textSelection(.enabled)
            if foldable {
                Button(unfolded ? "Show less" : "Show all") { withAnimation(.smooth) { unfolded.toggle() } }
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .buttonStyle(.borderless)
            }
        }
        .contextMenu {
            Button { UIPasteboard.general.string = message.text } label: { Label("Copy", systemImage: "doc.on.doc") }
            ShareLink(item: message.text) { Label("Share", systemImage: "square.and.arrow.up") }
        }
    }

    // The answer, written on this iPhone.

    @ViewBuilder private var answer: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let problem = message.problem {
                Text(problem)
                    .font(Theme.answer.italic())
                    .foregroundStyle(.secondary)
                if last && problem != BrainError.tooLong.localizedDescription {
                    Button("Try again", systemImage: "arrow.clockwise", action: regenerate)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                }
            } else if message.text.isEmpty && isWriting {
                ThinkingLine()
            } else {
                MarkdownView(text: message.text)
                    .textSelection(.enabled)
                    .mask { if isWriting { InkMask() } else { Rectangle() } }
                if !isWriting { seal }
            }
        }
    }

    /// Under every finished answer: where it was made, and what you can do with it.
    /// With very large text the two go on separate lines.
    @ViewBuilder private var seal: some View {
        if size.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                sealLabel
                HStack(spacing: 22) { actions }
            }
            .padding(.top, 2)
        } else {
            HStack(spacing: 18) {
                sealLabel
                Spacer()
                actions
            }
            .padding(.top, 2)
        }
    }

    private var sealLabel: some View {
        Label(sealText, systemImage: "lock.fill")
            .labelStyle(TightLabel())
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(.tertiary)
    }

    @ViewBuilder private var actions: some View {
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
            ShareLink(item: message.text) { Image(systemName: "square.and.arrow.up") }
                .accessibilityLabel("Share")
            if last {
                Button(action: regenerate) { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("Write it again")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .buttonStyle(.borderless)
    }

    private var sealText: String {
        guard let s = message.seconds else { return "Written on this iPhone" }
        return "Written on this iPhone · \(s < 10 ? String(format: "%.1f", s) : String(Int(s.rounded()))) s"
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
                    LivingOrb(size: size + 2, mood: thinking ? .thinking : .resting, dot: false,
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
    let isResponding: Bool
    let send: () -> Void
    let stop: () -> Void

    private var canSend: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            TextField("Ask anything, privately", text: $text, axis: .vertical)
                .font(.system(.body, design: .rounded))
                .lineLimit(1...6)
                .focused(typing)
                .padding(.leading, 18)
                .padding(.vertical, 13)
            // The orb is the send button: it wakes when there is something to
            // send, and swirls (tap to stop) while the answer is being written.
            Button(action: isResponding ? stop : send) {
                LivingOrb(size: 38,
                          mood: isResponding ? .thinking : (canSend ? .ready : .resting),
                          dot: false,
                          glyph: isResponding ? "stop.fill" : "arrow.up",
                          glow: canSend || isResponding,
                          animated: canSend || isResponding)
                    .saturation(canSend || isResponding ? 1 : 0)
                    .opacity(canSend || isResponding ? 1 : 0.35)
                    .animation(.smooth(duration: 0.35), value: canSend)
            }
            .buttonStyle(.plain)
            .disabled(!canSend && !isResponding)
            .padding(6)
            .accessibilityLabel(isResponding ? "Stop" : "Send")
        }
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

// MARK: - A new chat

struct EmptyChat: View {
    let isTyping: Bool
    let pick: (String) -> Void
    @AppStorage("name") private var name = ""
    @State private var touched = 0
    @Environment(\.dynamicTypeSize) private var size

    init(isTyping: Bool, pick: @escaping (String) -> Void) {
        self.isTyping = isTyping
        self.pick = pick
    }

    private struct Starter: Identifiable {
        let icon: String, text: String, prompt: String
        var id: String { text }
    }

    private let starters = [
        Starter(icon: "envelope.open", text: "Help me say no to a party, nicely.",
                prompt: "Help me write a friendly message turning down an invitation to a party this weekend."),
        Starter(icon: "lightbulb", text: "Explain compound interest like I'm twelve.",
                prompt: "Explain how compound interest works, simply, with a quick example."),
        Starter(icon: "calendar", text: "Plan a calm, healthy week around work.",
                prompt: "Help me plan a balanced week: I work 9 to 5, want to exercise three times and cook at home more."),
        Starter(icon: "gift", text: "Gift ideas for a friend who loves cooking.",
                prompt: "Give me 8 thoughtful birthday gift ideas for a friend who loves cooking and hiking."),
    ]

    private var greeting: String {
        let first = name.split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? "What's on your mind?" : "What's on your mind, \(first)?"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)
            LivingOrb(size: size.isAccessibilitySize ? 84 : 128, mood: isTyping ? .ready : .resting)
                .scaleEffect(touched % 2 == 0 ? 1 : 1.06)
                .animation(.spring(response: 0.35, dampingFraction: 0.5), value: touched)
                .onTapGesture { touched += 1 }
                .sensoryFeedback(.impact(flexibility: .soft), trigger: touched)
            Text(greeting)
                .font(.system(.title, design: .serif).weight(.medium))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, size.isAccessibilitySize ? 30 : 44)
                .padding(.horizontal, 24)
            PrivateBadge(text: "Private · works offline")
                .padding(.top, 14)
            Spacer(minLength: 24)
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
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: starter.icon)
                .font(.title3)
                .foregroundStyle(Theme.orb)
            Text("“\(starter.text)”")
                .font(.system(.callout, design: .serif))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: size.isAccessibilitySize ? 290 : 196, alignment: .topLeading)
        .frame(minHeight: 132, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.hairline))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}
