// Every chat on this iPhone: pinned ones first, then by day, with search,
// pin, rename, share and delete.

import SwiftUI

struct ChatsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var renaming: Chat?
    @State private var newTitle = ""

    private var found: [Chat] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return app.library.chats }
        return app.library.chats.filter { chat in
            chat.displayTitle.localizedCaseInsensitiveContains(q)
                || chat.messages.contains { $0.text.localizedCaseInsensitiveContains(q) }
        }
    }

    /// Pinned, Today, Yesterday, Previous 7 days, then by month.
    private var sections: [(String, [Chat])] {
        let calendar = Calendar.current
        var order: [String] = []
        var groups: [String: [Chat]] = [:]
        for chat in found {
            let key: String
            if chat.isPinned { key = "Pinned" }
            else if calendar.isDateInToday(chat.updated) { key = "Today" }
            else if calendar.isDateInYesterday(chat.updated) { key = "Yesterday" }
            else if chat.updated > calendar.date(byAdding: .day, value: -7, to: .now)! { key = "Previous 7 days" }
            else { key = chat.updated.formatted(.dateTime.month(.wide).year()) }
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(chat)
        }
        return order.map { ($0, groups[$0]!) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !app.library.chats.isEmpty && query.isEmpty {
                    vault
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 4))
                }
                ForEach(sections, id: \.0) { title, chats in
                    Section {
                        ForEach(chats) { chat in
                            row(chat).listRowBackground(Theme.card)
                        }
                    } header: {
                        HStack(spacing: 5) {
                            if title == "Pinned" { Image(systemName: "pin.fill").font(.system(size: 10, weight: .bold)) }
                            Text(title)
                        }
                        .font(Theme.ui(.footnote, .semibold))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background { Paper(energy: 0) }
            .overlay {
                if app.library.chats.isEmpty {
                    ContentUnavailableView {
                        Label("No chats yet", systemImage: "bubble.left.and.bubble.right")
                    } description: {
                        Text("Your chats are kept on this iPhone, and only here.").font(Theme.ui(.subheadline))
                    }
                } else if found.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, prompt: "Search chats")
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { app.newChat(); dismiss() } label: { Image(systemName: "square.and.pencil") }
                        .accessibilityLabel("New chat")
                }
            }
            .alert("Rename chat", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Title", text: $newTitle)
                Button("Cancel", role: .cancel) { renaming = nil }
                Button("Rename") {
                    if let chat = renaming { app.rename(chat.id, to: newTitle) }
                    renaming = nil
                }
            }
        }
    }

    /// The top of the list: how many chats are kept, how many words, and where.
    private var vault: some View {
        let count = app.library.chats.count
        let questions = app.library.chats.reduce(0) { $0 + $1.messages.filter { $0.role == .user }.count }
        return HStack(spacing: 14) {
            LivingOrb(size: 42, mood: .resting, glow: false, animated: false)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count) \(count == 1 ? "chat" : "chats") locked away")
                    .font(Theme.ui(.headline, .semibold))
                Text("\(questions) \(questions == 1 ? "question" : "questions") · kept only on this iPhone")
                    .font(Theme.ui(.subheadline))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func row(_ chat: Chat) -> some View {
        Button {
            app.open(chat.id)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if chat.id == app.current.id {
                        Circle().fill(Theme.orb).frame(width: 7, height: 7)
                    }
                    Text(chat.displayTitle)
                        .font(Theme.ui(.body, .semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(chat.updated.formatted(Calendar.current.isDateInToday(chat.updated)
                                                ? .dateTime.hour().minute() : .dateTime.day().month(.abbreviated)))
                        .font(Theme.ui(.caption))
                        .foregroundStyle(.secondary)
                }
                Text(chat.preview)
                    .font(Theme.ui(.subheadline))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: 10) {
                    let questions = chat.messages.filter { $0.role == .user }.count
                    Label("\(questions)", systemImage: "text.bubble")
                    let files = chat.messages.reduce(0) { $0 + $1.files.count }
                    if files > 0 { Label("\(files)", systemImage: "paperclip") }
                }
                .labelStyle(TightLabel())
                .font(Theme.ui(.caption2, .medium))
                .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { app.delete(chat.id) } label: { Label("Delete", systemImage: "trash") }
            Button { newTitle = chat.displayTitle; renaming = chat } label: { Label("Rename", systemImage: "pencil") }
                .tint(.gray)
        }
        .swipeActions(edge: .leading) {
            Button { app.togglePin(chat.id) } label: {
                Label(chat.isPinned ? "Unpin" : "Pin", systemImage: chat.isPinned ? "pin.slash" : "pin")
            }
            .tint(Theme.violet)
        }
        .contextMenu {
            Button { app.togglePin(chat.id) } label: {
                Label(chat.isPinned ? "Unpin" : "Pin", systemImage: chat.isPinned ? "pin.slash" : "pin")
            }
            Button { newTitle = chat.displayTitle; renaming = chat } label: { Label("Rename", systemImage: "pencil") }
            ShareLink(item: chat.markdown, preview: SharePreview(chat.displayTitle)) {
                Label("Share chat", systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive) { app.delete(chat.id) } label: { Label("Delete", systemImage: "trash") }
        }
    }
}
