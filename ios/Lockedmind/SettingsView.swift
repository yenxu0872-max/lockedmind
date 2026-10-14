// How answers should sound, what Lockedmind may know about the person,
// whether chats go into backups, and plain facts about privacy.

import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("length") private var length = Voice.Length.balanced.rawValue
    @AppStorage("name") private var name = ""
    @AppStorage("about") private var about = ""
    @AppStorage(Library.backupsKey) private var backups = false
    @State private var confirmDelete = false

    private var version: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "1.0") (\(info?["CFBundleVersion"] as? String ?? "1"))"
    }

    var body: some View {
        Form {
            Section {
                Picker("Answers", selection: $length) {
                    ForEach(Voice.Length.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } header: {
                Text("Answer length")
            }

            Section {
                TextField("Your first name", text: $name)
                    .textContentType(.givenName)
                TextField("Anything Lockedmind should know about you, like your job or how you like answers",
                          text: $about, axis: .vertical)
                    .lineLimit(2...6)
            } header: {
                Text("About you")
            } footer: {
                Text("Optional. Kept on this iPhone and given to the model with each chat.")
            }

            Section {
                Toggle("Include chats in backups", isOn: $backups)
                    .onChange(of: backups) { app.library.applyBackupChoice() }
            } footer: {
                Text(backups
                     ? "Your chats are included when this iPhone backs up to iCloud or a computer, so they come with you to a new iPhone."
                     : "Your chats are left out of iCloud and computer backups, so they exist only on this iPhone. Turn this on if you'd like them to move to a new iPhone with you.")
            }

            Section("Privacy") {
                Fact(icon: "iphone", title: "Runs on this iPhone",
                     text: "Answers come from Apple's on-device model. What you write is never sent anywhere.")
                Fact(icon: "airplane", title: "Works in Airplane Mode",
                     text: "Lockedmind has no internet code at all.")
                Fact(icon: "person.crop.circle.badge.xmark", title: "No account, no tracking, no ads",
                     text: "There is nothing to sign up for, and nothing about you is collected.")
            }

            Section {
                Button("Delete all chats", role: .destructive) { confirmDelete = true }
                    .disabled(app.library.chats.isEmpty)
            }

            Section {
                LabeledContent("Version", value: version)
                Link(destination: URL(string: "https://yenxu0872-max.github.io/lockedmind/app/")!) {
                    LabeledContent("Lockedmind for Mac and the web") { Image(systemName: "arrow.up.right") }
                }
            } header: {
                Text("About")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete all chats?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete all chats", role: .destructive) { app.deleteAll() }
        } message: {
            Text(backups ? "This can't be undone." : "They're only on this iPhone, so they can't be brought back.")
        }
    }
}

private struct Fact: View {
    let icon: String, title: String, text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}
