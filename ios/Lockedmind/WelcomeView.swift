// The first screen, and the screen for an iPhone where Apple's on-device
// model can't run (yet).

import SwiftUI
import UIKit
import FoundationModels

struct WelcomeView: View {
    let start: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)
            Orb(size: 96)
            Text("Lockedmind")
                .font(.largeTitle.weight(.bold))
                .padding(.top, 36)
            Text("Private AI that lives on your iPhone.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
            Spacer(minLength: 32)
            VStack(alignment: .leading, spacing: 22) {
                Point(icon: "lock.fill", title: "Nothing leaves your iPhone",
                      text: "Every answer is worked out on the phone itself. No account, no tracking.")
                Point(icon: "airplane", title: "Works in Airplane Mode",
                      text: "No internet needed, ever. Lockedmind doesn't even have internet code.")
                Point(icon: "sparkles", title: "Writes, explains, plans",
                      text: "Draft messages, understand tricky things, plan your week, brainstorm ideas.")
            }
            .padding(.horizontal, 32)
            Spacer(minLength: 32)
            Button(action: start) {
                Text("Start chatting")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(Theme.accent)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }
}

private struct Point: View {
    let icon: String, title: String, text: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Theme.orb)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct UnavailableView: View {
    let availability: SystemLanguageModel.Availability

    private var copy: (title: String, text: String, settings: Bool) {
        switch availability {
        case .unavailable(.deviceNotEligible):
            ("This iPhone can't run Lockedmind",
             "Lockedmind uses Apple's on-device model, which needs an iPhone with Apple Intelligence: iPhone 15 Pro or newer.",
             false)
        case .unavailable(.appleIntelligenceNotEnabled):
            ("Turn on Apple Intelligence",
             "Lockedmind uses Apple's on-device model. Open Settings, tap Apple Intelligence & Siri and switch it on. Then come back here.",
             true)
        case .unavailable(.modelNotReady):
            ("Getting ready…",
             "Your iPhone is still downloading Apple's on-device model. Keep it on Wi-Fi and charging; this screen moves on by itself when it's done.",
             false)
        default:
            ("Lockedmind can't start yet",
             "Apple's on-device model isn't available on this iPhone right now. Check that Apple Intelligence is on in Settings.",
             true)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Orb(size: 80, glow: false, thinking: availability == .unavailable(.modelNotReady))
                .saturation(availability == .unavailable(.modelNotReady) ? 1 : 0)
            Text(copy.title)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.top, 32)
            Text(copy.text)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
            if copy.settings {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(Theme.accent)
                .padding(.top, 28)
            }
            Spacer()
            Label("Lockedmind never sends what you write anywhere.", systemImage: "lock.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 32)
    }
}
