// Everything you can choose, and plain facts about how Lockedmind works:
// you, how answers sound, privacy and the lock, the model itself, your data.

import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(Guard.self) private var guardian
    @Environment(Connection.self) private var connection
    @AppStorage("length") private var length = Voice.Length.balanced.rawValue
    @AppStorage("tone") private var tone = Voice.Tone.warm.rawValue
    @AppStorage("creativity") private var creativity = Voice.Creativity.balanced.rawValue
    @AppStorage("followUps") private var followUps = true
    @AppStorage("name") private var name = ""
    @AppStorage("about") private var about = ""
    @AppStorage(Library.backupsKey) private var backups = false
    @AppStorage(Guard.key) private var lockOn = false
    @State private var confirmDelete = false
    @State private var noPasscode = false

    private var version: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "1.0") (\(info?["CFBundleVersion"] as? String ?? "1"))"
    }

    /// Turning the lock on first proves the person can unlock it.
    private var lockBinding: Binding<Bool> {
        Binding(get: { lockOn }, set: { wanted in
            guard wanted else { lockOn = false; return }
            guard Guard.isPossible else { noPasscode = true; return }
            Task { if await guardian.confirm() { lockOn = true } }
        })
    }

    private var everything: String {
        app.library.chats.map(\.markdown).joined(separator: "\n\n")
    }

    var body: some View {
        Form {
            Section {
                row("person.fill", [Theme.violet, Theme.indigo]) {
                    TextField("Your first name", text: $name).textContentType(.givenName)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("About you").font(Theme.ui(.footnote, .semibold)).foregroundStyle(.secondary)
                    TextField("Your job, what you're learning, how you like answers…", text: $about, axis: .vertical)
                        .lineLimit(2...6)
                }
                .padding(.vertical, 2)
            } header: {
                header("You")
            } footer: {
                Note("Optional. Kept on this iPhone, and given to the model with each chat so its answers fit you.")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    label("text.alignleft", "Length")
                    Picker("Length", selection: $length) {
                        ForEach(Voice.Length.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.vertical, 4)
                Picker(selection: $tone) {
                    ForEach(Voice.Tone.allCases) { Label($0.label, systemImage: $0.symbol).tag($0.rawValue) }
                } label: {
                    label("theatermasks", "Tone")
                }
                VStack(alignment: .leading, spacing: 8) {
                    label("sparkles", "Creativity")
                    Picker("Creativity", selection: $creativity) {
                        ForEach(Voice.Creativity.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.vertical, 4)
                Toggle(isOn: $followUps) { label("arrow.turn.down.right", "Suggest follow-up questions") }
            } header: {
                header("Answers")
            } footer: {
                Note("Precise sticks closely to the likeliest words; Creative takes more chances, which suits stories and brainstorming.")
            }

            Section {
                Toggle(isOn: lockBinding) { label(Guard.method.symbol, "Lock with \(Guard.method.name)") }
                Toggle(isOn: $backups) { label("externaldrive", "Include chats in backups") }
                    .onChange(of: backups) { app.library.applyBackupChoice() }
                HStack {
                    label(connection.isOnline ? "wifi" : "wifi.slash", "This iPhone is \(connection.label.lowercased())")
                    Spacer()
                    Circle().fill(connection.isOnline ? Theme.online : Theme.violet).frame(width: 8, height: 8)
                }
            } header: {
                header("Privacy and security")
            } footer: {
                Note(backups
                     ? "The lock hides your chats whenever you leave Lockedmind; iOS does the checking. Backups: your chats are included when this iPhone backs up to iCloud or a computer. Online or not, Lockedmind never sends anything."
                     : "The lock hides your chats whenever you leave Lockedmind; iOS does the checking. Backups: your chats are left out, so they exist only on this iPhone. Online or not, Lockedmind never sends anything.")
            }

            Section {
                Fact(icon: "iphone", title: "Runs on this iPhone",
                     text: "Answers come from Apple's on-device model. What you write is never sent anywhere.")
                Fact(icon: "airplane", title: "Works in Airplane Mode",
                     text: "Lockedmind never connects to the internet. It only checks whether your iPhone is online, to show you.")
                Fact(icon: "doc.text.viewfinder", title: "Photos and files stay here too",
                     text: Brain.canSee
                        ? "Pictures are looked at and read on this iPhone; files are read here."
                        : "Words in pictures and files are read on this iPhone.")
                Fact(icon: "mic", title: "Dictation on the device",
                     text: "Your voice is turned into words on this iPhone, or not at all.")
                Fact(icon: "person.crop.circle.badge.xmark", title: "No account, no tracking, no ads",
                     text: "There is nothing to sign up for, and nothing about you is collected.")
            } header: {
                header("How it works")
            }

            Section {
                LabeledContent { Text("Apple on-device") } label: { label("cpu", "Model") }
                LabeledContent { Text("\(Brain.contextSize.formatted()) tokens") } label: { label("brain.head.profile", "Memory per chat") }
                LabeledContent { Text("\(Brain.languageCount)") } label: { label("globe", "Languages") }
                LabeledContent { Text(Brain.canSee ? "Yes" : "Reads their text") } label: { label("eye", "Sees photos") }
                LabeledContent {
                    Text(app.isAvailable ? "Ready" : "Not ready")
                        .foregroundStyle(app.isAvailable ? Theme.online : .secondary)
                } label: { label("checkmark.seal", "Status") }
            } header: {
                header("The model")
            } footer: {
                Note("A chat longer than its memory keeps going: Lockedmind keeps the newest part in mind and marks where older messages fall away.")
            }

            Section {
                ShareLink(item: everything, preview: SharePreview("Lockedmind chats")) {
                    label("square.and.arrow.up", "Export all chats")
                }
                .disabled(app.library.chats.isEmpty)
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label { Text("Delete all chats") } icon: { IconTile(symbol: "trash", colors: [.red, .pink]) }
                }
                .disabled(app.library.chats.isEmpty)
            } header: {
                header("Your data")
            }

            Section {
                LabeledContent { Text(version) } label: { label("info.circle", "Version") }
                Link(destination: URL(string: "https://yenxu0872-max.github.io/lockedmind/app/")!) {
                    LabeledContent { Image(systemName: "arrow.up.right") } label: { label("globe", "Lockedmind for Mac and the web") }
                }
                Link(destination: URL(string: "https://yenxu0872-max.github.io/lockedmind/app/privacy.html")!) {
                    LabeledContent { Image(systemName: "arrow.up.right") } label: { label("hand.raised", "Privacy policy") }
                }
            } header: {
                header("About")
            } footer: {
                Note("Set in Geist and Geist Mono by Vercel, under the SIL Open Font License.")
            }
        }
        .font(Theme.ui(.body))
        .scrollContentBackground(.hidden)
        .background { Paper(energy: 0) }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete all chats?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete all chats", role: .destructive) { app.deleteAll() }
        } message: {
            Text(backups ? "This can't be undone." : "They're only on this iPhone, so they can't be brought back.")
        }
        .alert("Set a passcode first", isPresented: $noPasscode) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The lock uses your iPhone's Face ID or passcode. Set a passcode in the Settings app, then try again.")
        }
    }

    private func header(_ text: String) -> some View {
        Text(text).font(Theme.ui(.footnote, .semibold))
    }

    private func label(_ symbol: String, _ text: String) -> some View {
        Label { Text(text) } icon: { IconTile(symbol: symbol) }
    }

    private func row(_ symbol: String, _ colors: [Color], @ViewBuilder _ content: () -> some View) -> some View {
        HStack(spacing: 14) {
            IconTile(symbol: symbol, colors: colors)
            content()
        }
    }
}

/// A section footer, in the small size footers should have.
private struct Note: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(Theme.ui(.footnote)) }
}

private struct Fact: View {
    let icon: String, title: String, text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            IconTile(symbol: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.ui(.subheadline, .semibold))
                Text(text).font(Theme.ui(.footnote)).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}
