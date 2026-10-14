// Every chat on this iPhone, newest first, with search, rename and delete.

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

    /// Today, Yesterday, Previous 7 days, then by month.
    private var sections: [(String, [Chat])] {
        let calendar = Calendar.current
        var order: [String] = []
        var groups: [String: [Chat]] = [:]
        for chat in found {
            let key: String
            if calendar.isDateInToday(chat.updated) { key = "Today" }
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
                ForEach(sections, id: \.0) { title, chats in
                    Section(title) {
                        ForEach(chats) { chat in row(chat) }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .overlay {
                if app.library.chats.isEmpty {
                    ContentUnavailableView("No chats yet", systemImage: "bubble.left.and.bubble.right",
                                           description: Text("Your chats are kept on this iPhone, and only here."))
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

    private func row(_ chat: Chat) -> some View {
        Button {
            app.open(chat.id)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(chat.displayTitle)
                        .font(.body.weight(chat.id == app.current.id ? .semibold : .regular))
                        .lineLimit(1)
                    Spacer()
                    Text(chat.updated.formatted(Calendar.current.isDateInToday(chat.updated)
                                                ? .dateTime.hour().minute() : .dateTime.day().month(.abbreviated)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(chat.preview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
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
        .contextMenu {
            Button { newTitle = chat.displayTitle; renaming = chat } label: { Label("Rename", systemImage: "pencil") }
            Button(role: .destructive) { app.delete(chat.id) } label: { Label("Delete", systemImage: "trash") }
        }
    }
}
