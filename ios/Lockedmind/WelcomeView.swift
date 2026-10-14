// The first screen, where the mind wakes up, and the screen for an iPhone
// where Apple's on-device model can't run (yet).

import SwiftUI
import UIKit
import FoundationModels

struct WelcomeView: View {
    let start: () -> Void
    @State private var awake = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 30)
            LivingOrb(size: 150, mood: awake ? .ready : .resting)
                .scaleEffect(awake ? 1 : 0.55)
                .opacity(awake ? 1 : 0)
                .blur(radius: awake ? 0 : 12)
            Text("Lockedmind")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .padding(.top, 54)
                .opacity(awake ? 1 : 0)
                .offset(y: awake ? 0 : 12)
            Text("A private mind that lives\non your iPhone.")
                .font(.system(.title3, design: .serif).italic())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .opacity(awake ? 1 : 0)
                .offset(y: awake ? 0 : 12)
            Spacer(minLength: 30)
            VStack(alignment: .leading, spacing: 22) {
                Point(icon: "lock.fill", title: "Nothing leaves your iPhone",
                      text: "Every answer is worked out on the phone itself. No account, no tracking.")
                Point(icon: "airplane", title: "Works in Airplane Mode",
                      text: "No internet needed, ever. Lockedmind doesn't even have internet code.")
                Point(icon: "faceid", title: "Locks with Face ID",
                      text: "Turn on the lock in Settings, and only you can open your chats.")
            }
            .padding(.horizontal, 30)
            .opacity(awake ? 1 : 0)
            .offset(y: awake ? 0 : 18)
            Spacer(minLength: 30)
            Button("Begin", action: start)
                .buttonStyle(GlowButtonStyle())
                .padding(.horizontal, 28)
                .opacity(awake ? 1 : 0)
            Text("Free. Nothing to sign up for.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .opacity(awake ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(alignment: .bottom) { Aurora(energy: awake ? 0.55 : 0).ignoresSafeArea() }
        .background(Theme.paper.ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(response: 1.1, dampingFraction: 0.8).delay(0.15)) { awake = true }
        }
    }
}

private struct Point: View {
    let icon: String, title: String, text: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Theme.orb, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(.headline, design: .rounded))
                Text(text)
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(.secondary)
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
            ("Waking up…",
             "Your iPhone is still downloading Apple's on-device model. Keep it on Wi-Fi and charging; this screen moves on by itself when it's done.",
             false)
        default:
            ("Lockedmind can't start yet",
             "Apple's on-device model isn't available on this iPhone right now. Check that Apple Intelligence is on in Settings.",
             true)
        }
    }

    private var downloading: Bool { availability == .unavailable(.modelNotReady) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            LivingOrb(size: 104, mood: downloading ? .thinking : .resting, glow: downloading)
                .saturation(downloading ? 1 : 0)
                .opacity(downloading ? 1 : 0.7)
            Text(copy.title)
                .font(.system(.title2, design: .serif).weight(.medium))
                .multilineTextAlignment(.center)
                .padding(.top, 44)
            Text(copy.text)
                .font(Theme.answer)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
            if copy.settings {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .buttonStyle(GlowButtonStyle())
                .padding(.horizontal, 40)
                .padding(.top, 30)
            }
            Spacer()
            PrivateBadge(text: "Lockedmind never sends what you write anywhere")
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper.ignoresSafeArea())
    }
}
