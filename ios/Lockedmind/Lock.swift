// The lock in Lockedmind: when it's on, the app hides everything as soon as
// it leaves the screen, and opens again only with Face ID (or Touch ID, or
// the passcode). iOS does the checking; the app only learns yes or no.

import SwiftUI
import LocalAuthentication
import Observation

@MainActor @Observable
final class Guard {
    static let key = "faceLock"

    private(set) var locked: Bool
    @ObservationIgnored private var asking = false

    init() {
        locked = UserDefaults.standard.bool(forKey: Self.key)
    }

    var isOn: Bool { UserDefaults.standard.bool(forKey: Self.key) }

    /// What this iPhone unlocks with, for the button and the setting.
    static var method: (name: String, symbol: String) {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return ("Face ID", "faceid")
        case .touchID: return ("Touch ID", "touchid")
        case .opticID: return ("Optic ID", "opticid")
        default: return ("Passcode", "lock.fill")
        }
    }

    /// The lock needs at least a passcode on the iPhone.
    static var isPossible: Bool { LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) }

    func lockIfOn() {
        if isOn { locked = true }
    }

    /// Asks iOS to check it's the owner. True if they are.
    @discardableResult
    func unlock(reason: String = "Unlock your chats") async -> Bool {
        guard !asking else { return false }
        asking = true
        defer { asking = false }
        let context = LAContext()
        context.localizedCancelTitle = "Not now"
        do {
            let ok = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            if ok { withAnimation(.smooth(duration: 0.5)) { locked = false } }
            return ok
        } catch {
            return false
        }
    }

    /// For turning the lock on: proves the person can unlock before it locks.
    func confirm() async -> Bool {
        let context = LAContext()
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication,
                                                  localizedReason: "Turn on the lock for Lockedmind")) ?? false
    }
}

/// Shown while locked, and over the app in the app switcher: the logo's
/// keyhole, glowing, and one button.
struct LockScreen: View {
    let unlock: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            LivingOrb(size: 118, mood: .ready)
            Text("Locked")
                .font(Theme.ui(.largeTitle, .bold))
                .padding(.top, 50)
            Text("Your chats stay hidden until you unlock.")
                .font(Theme.ui(.body))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            Spacer()
            if let unlock {
                Button(action: unlock) {
                    Label("Unlock with \(Guard.method.name)", systemImage: Guard.method.symbol)
                }
                .buttonStyle(GlowButtonStyle())
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { Paper(energy: 0.45) }
    }
}
