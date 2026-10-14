// How answers should sound, what Lockedmind may know about the person,
// whether chats go into backups, and plain facts about privacy.

import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("length") private var length = Voice.Length.balanced.rawValue
    @AppStorage("name") private var name = ""
    @AppStorage("about") private var about = ""
    @AppStorage(Library.backupsKey) private var backups = false
    @AppStorage(Guard.key) private var lockOn = false
    @Environment(Guard.self) private var guardian
    @State private var confirmDelete = false
    @State private var noPasscode = false

    /// Turning the lock on first proves the person can unlock it.
    private var lockBinding: Binding<Bool> {
        Binding(get: { lockOn }, set: { wanted in
            guard wanted else { lockOn = false; return }
            guard Guard.isPossible else { noPasscode = true; return }
            Task { if await guardian.confirm() { lockOn = true } }
        })
    }

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
                Toggle(isOn: lockBinding) {
                    Label("Lock with \(Guard.method.name)", systemImage: Guard.method.symbol)
                }
            } footer: {
                Text("Lockedmind hides your chats whenever you leave it, and opens again only for you. iOS does the checking; Lockedmind never sees your face or fingerprint.")
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
        .scrollContentBackground(.hidden)
        .background(Theme.paper.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Set a passcode first", isPresented: $noPasscode) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The lock uses your iPhone's Face ID or passcode. Set a passcode in the Settings app, then try again.")
        }
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
                .foregroundStyle(Theme.orb)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text(text).font(.system(.footnote, design: .serif)).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}
