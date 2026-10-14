// The main screen: one conversation, the box to write in, and a way to
// reach the other chats.

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

    var body: some View {
        NavigationStack {
            Group {
                if app.current.messages.isEmpty {
                    EmptyChat { prompt in send(prompt) }
                } else {
                    conversation
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Composer(text: $draft, typing: $typing, isResponding: app.isResponding,
                         send: { send(draft) }, stop: app.stop)
            }
            .navigationTitle(app.current.messages.isEmpty ? "" : app.current.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showChats = true } label: { Image(systemName: "line.3.horizontal") }
                        .accessibilityLabel("Chats")
                }
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
        .sensoryFeedback(.success, trigger: app.isResponding) { was, now in was && !now }
    }

    private var conversation: some View {
        let last = app.current.messages.last?.id
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(app.current.messages) { message in
                    MessageRow(message: message,
                               isLast: message.id == last,
                               isWriting: app.isResponding && message.id == last,
                               regenerate: app.regenerate,
                               retry: app.regenerate)
                        .id(message.id)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 18)
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

// MARK: - A message

struct MessageRow: View {
    let message: Message
    let isLast: Bool
    let isWriting: Bool
    let regenerate: () -> Void
    let retry: () -> Void

    @State private var copied = false

    var body: some View {
        switch message.role {
        case .user: question
        case .assistant: answer
        }
    }

    /// Long pasted messages are folded after a dozen lines.
    @State private var unfolded = false
    private var foldable: Bool { message.text.count > 700 || message.text.filter(\.isNewline).count > 12 }

    private var question: some View {
        HStack {
            Spacer(minLength: 48)
            VStack(alignment: .trailing, spacing: 6) {
                Text(message.text)
                    .lineLimit(foldable && !unfolded ? 12 : nil)
                if foldable {
                    Button(unfolded ? "Show less" : "Show all") { withAnimation(.smooth) { unfolded.toggle() } }
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.borderless)
                }
            }
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .background(Theme.bubble, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .contextMenu {
                    Button { UIPasteboard.general.string = message.text } label: { Label("Copy", systemImage: "doc.on.doc") }
                    ShareLink(item: message.text) { Label("Share", systemImage: "square.and.arrow.up") }
                }
        }
    }

    @ViewBuilder private var answer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let problem = message.problem {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "exclamationmark.circle")
                    Text(problem)
                }
                .foregroundStyle(.secondary)
                if isLast && problem != BrainError.tooLong.localizedDescription {
                    Button("Try again", systemImage: "arrow.clockwise", action: retry)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            } else if message.text.isEmpty && isWriting {
                TypingDots()
            } else {
                MarkdownView(text: message.text)
                    .textSelection(.enabled)
                if !isWriting { actions }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actions: some View {
        HStack(spacing: 18) {
            Button {
                UIPasteboard.general.string = message.text
                copied = true
                Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
            }
            .accessibilityLabel(copied ? "Copied" : "Copy")
            ShareLink(item: message.text) { Image(systemName: "square.and.arrow.up") }
                .accessibilityLabel("Share")
            if isLast {
                Button(action: regenerate) { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("Write it again")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .buttonStyle(.borderless)
        .padding(.top, 2)
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
        HStack(alignment: .bottom, spacing: 6) {
            TextField("Message Lockedmind", text: $text, axis: .vertical)
                .lineLimit(1...6)
                .focused(typing)
                .padding(.leading, 18)
                .padding(.vertical, 12)
            Button(action: isResponding ? stop : send) {
                Image(systemName: isResponding ? "stop.fill" : "arrow.up")
                    .font(.system(size: isResponding ? 13 : 16, weight: .bold))
                    .foregroundStyle(Color(.systemBackground))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(canSend || isResponding ? Color.primary : Color.secondary.opacity(0.35)))
            }
            .disabled(!canSend && !isResponding)
            .padding(6)
            .accessibilityLabel(isResponding ? "Stop" : "Send")
            .animation(.snappy, value: isResponding)
        }
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 23, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

// MARK: - A new chat

struct EmptyChat: View {
    let pick: (String) -> Void
    @AppStorage("name") private var name = ""

    init(pick: @escaping (String) -> Void) { self.pick = pick }

    private struct Idea: Identifiable {
        let icon: String, title: String, detail: String, prompt: String
        var id: String { title }
    }

    private let ideas = [
        Idea(icon: "envelope", title: "Write a message", detail: "that says no, nicely",
             prompt: "Help me write a friendly message turning down an invitation to a party this weekend."),
        Idea(icon: "lightbulb", title: "Explain simply", detail: "how compound interest works",
             prompt: "Explain how compound interest works, simply, with a quick example."),
        Idea(icon: "calendar", title: "Plan my week", detail: "around work and the gym",
             prompt: "Help me plan a balanced week: I work 9 to 5, want to exercise three times and cook at home more."),
        Idea(icon: "gift", title: "Brainstorm", detail: "a gift for a friend who cooks",
             prompt: "Give me 8 thoughtful birthday gift ideas for a friend who loves cooking and hiking."),
    ]

    private var greeting: String {
        let first = name.split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? "What's on your mind?" : "Hi \(first), what's on your mind?"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Orb(size: 76)
            Text(greeting)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.top, 30)
            Label("Private AI that runs on this iPhone", systemImage: "lock.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            Spacer()
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(ideas) { idea in
                    Button { pick(idea.prompt) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Image(systemName: idea.icon)
                                .font(.callout)
                                .foregroundStyle(Theme.accent)
                                .padding(.bottom, 5)
                            Text(idea.title).font(.subheadline.weight(.semibold))
                            Text(idea.detail).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                        .padding(14)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
}
