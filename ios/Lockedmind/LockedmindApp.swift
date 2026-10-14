// Lockedmind for iPhone: private AI that runs entirely on the phone,
// using Apple's on-device model. No account, no network, no tracking.

import SwiftUI

@main
struct LockedmindApp: App {
    #if PREVIEW
    @State private var model = AppModel(library: Library(folder: PreviewHarness.dataFolder))
    #else
    @State private var model = AppModel(library: Library())
    #endif
    @State private var guardian = Guard()
    @State private var connection = Connection()
    @State private var speaker = Speaker()
    @State private var dictation = Dictation()
    @Environment(\.scenePhase) private var phase

    init() {
        Theme.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(guardian)
                .environment(connection)
                .environment(speaker)
                .environment(dictation)
                .font(Theme.ui(.body))
                .tint(Theme.accent)
                #if PREVIEW
                .modifier(PreviewHarness(model: model, connection: connection, speaker: speaker, dictation: dictation))
                #endif
        }
        .onChange(of: phase) { _, new in
            if new == .active { model.refreshAvailability() }
            if new == .background {
                model.library.saveNow()
                guardian.lockIfOn()
                dictation.stop()
            }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(Guard.self) private var guardian
    @Environment(\.scenePhase) private var phase
    @AppStorage("welcomed") private var welcomed = false
    @AppStorage(Guard.key) private var lockOn = false
    @State private var wasAway = false

    var body: some View {
        ZStack {
            Group {
                if !welcomed {
                    WelcomeView { withAnimation(.smooth(duration: 0.6)) { welcomed = true } }
                } else if app.isAvailable {
                    ChatView()
                } else {
                    UnavailableView(availability: app.availability)
                }
            }
            .animation(.smooth, value: app.isAvailable)

            if guardian.locked {
                LockScreen { Task { await guardian.unlock() } }
                    .transition(.opacity)
                    .zIndex(2)
            } else if lockOn && phase != .active {
                // Covers the chats in the app switcher.
                LockScreen(unlock: nil)
                    .zIndex(1)
            }
        }
        .task {
            if guardian.locked { await guardian.unlock() }
        }
        .onChange(of: phase) {
            // Ask straight away when coming back, but not again after a "Not now"
            // (the Face ID prompt itself makes the app briefly inactive).
            if phase == .background { wasAway = true }
            if phase == .active, wasAway {
                wasAway = false
                if guardian.locked { Task { await guardian.unlock() } }
            }
        }
    }
}
