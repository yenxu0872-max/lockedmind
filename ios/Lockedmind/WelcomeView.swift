// The first screen, where the mind wakes up and asks your name, and the
// screen for an iPhone where Apple's on-device model can't run (yet).

import SwiftUI
import UIKit
import FoundationModels

struct WelcomeView: View {
    let start: () -> Void
    @AppStorage("name") private var name = ""
    @State private var awake = false
    @FocusState private var naming: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                LivingOrb(size: 124, mood: awake ? .ready : .resting)
                    .scaleEffect(awake ? 1 : 0.55)
                    .opacity(awake ? 1 : 0)
                    .blur(radius: awake ? 0 : 12)
                    .padding(.top, 48)
                Text("Lockedmind")
                    .font(Theme.ui(.largeTitle, .bold))
                    .tracking(-0.5)
                    .padding(.top, 44)
                Text("A private mind that lives on your iPhone.")
                    .font(Theme.ui(.title3))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
                VStack(alignment: .leading, spacing: 20) {
                    Point(icon: "lock.fill", title: "Nothing leaves your iPhone",
                          text: "Every answer is worked out on the phone itself. No account, no tracking.")
                    Point(icon: "airplane", title: "Works without internet",
                          text: "Lockedmind never connects to the internet, so it works the same in Airplane Mode.")
                    Point(icon: "doc.viewfinder", title: "Reads photos, scans and PDFs",
                          text: "Attach them and ask away. They're read on this iPhone too.")
                    Point(icon: "faceid", title: "Locks with Face ID",
                          text: "Turn on the lock in Settings, and only you can open your chats.")
                }
                .padding(.top, 36)
                .padding(.horizontal, 30)
                VStack(alignment: .leading, spacing: 6) {
                    Text("What should I call you?")
                        .font(Theme.ui(.footnote, .semibold))
                        .foregroundStyle(.secondary)
                    TextField("Your first name (optional)", text: $name)
                        .font(Theme.ui(.body))
                        .textContentType(.givenName)
                        .submitLabel(.done)
                        .focused($naming)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.hairline))
                }
                .padding(.horizontal, 28)
                .padding(.top, 32)
                .padding(.bottom, 24)
            }
            .opacity(awake ? 1 : 0)
            .offset(y: awake ? 0 : 14)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button("Begin", action: start)
                    .buttonStyle(GlowButtonStyle())
                Text("Free. Nothing to sign up for.")
                    .font(Theme.ui(.footnote))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 8)
            .background {
                // The page fades out under the button rather than running beneath it.
                LinearGradient(stops: [.init(color: Theme.paper.opacity(0), location: 0),
                                       .init(color: Theme.paper.opacity(0.94), location: 0.35)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            }
            .opacity(awake ? 1 : 0)
        }
        .background { Paper(energy: awake ? 0.55 : 0) }
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
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Theme.orb, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Theme.ui(.headline, .semibold))
                Text(text)
                    .font(Theme.ui(.subheadline))
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
                .font(Theme.ui(.title2, .semibold))
                .multilineTextAlignment(.center)
                .padding(.top, 44)
            Text(copy.text)
                .font(Theme.ui(.body))
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
        .background { Paper(energy: 0) }
    }
}
