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
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(Theme.accent)
                #if PREVIEW
                .modifier(PreviewHarness(model: model))
                #endif
        }
        .onChange(of: phase) {
            if phase == .active { model.refreshAvailability() }
            if phase == .background { model.library.saveNow() }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("welcomed") private var welcomed = false

    var body: some View {
        Group {
            if !welcomed {
                WelcomeView { withAnimation(.smooth) { welcomed = true } }
            } else if app.isAvailable {
                ChatView()
            } else {
                UnavailableView(availability: app.availability)
            }
        }
        .animation(.smooth, value: app.isAvailable)
    }
}
