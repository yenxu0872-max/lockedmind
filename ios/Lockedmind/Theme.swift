// Lockedmind's look on iPhone: the system's own type and surfaces, with the
// brand's violet-to-sky orb as the one splash of colour.

import SwiftUI
import UIKit

enum Theme {
    /// The orb's two colours, the same as the website and the Mac icon.
    static let violet = Color(red: 0.675, green: 0.467, blue: 0.980)   // #ac77fa
    static let sky = Color(red: 0.0, green: 0.682, blue: 0.914)        // #00aee9

    static let accent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.72, green: 0.60, blue: 1.0, alpha: 1)
            : UIColor(red: 0.42, green: 0.27, blue: 0.90, alpha: 1)
    })

    /// The person's own messages sit in a quiet grey bubble.
    static let bubble = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.17, alpha: 1)
            : UIColor(red: 0.945, green: 0.945, blue: 0.96, alpha: 1)
    })

    static let orb = LinearGradient(colors: [violet, sky], startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// The logo: a violet-to-sky sphere with a small dot at its shoulder.
/// While `thinking`, it breathes.
struct Orb: View {
    var size: CGFloat = 64
    var glow = true
    var thinking = false

    var body: some View {
        ZStack {
            if glow {
                Circle()
                    .fill(Theme.violet.opacity(0.32))
                    .frame(width: size * 1.5, height: size * 1.5)
                    .blur(radius: size * 0.38)
            }
            Circle()
                .fill(Theme.orb)
                .overlay(
                    Circle().fill(RadialGradient(colors: [.white.opacity(0.32), .clear],
                                                 center: UnitPoint(x: 0.33, y: 0.3),
                                                 startRadius: 0, endRadius: size * 0.55))
                )
                .frame(width: size, height: size)
            // The dot, ringed in the page colour so it reads as sitting in front.
            Circle()
                .fill(Color(.systemBackground))
                .frame(width: size * 0.47, height: size * 0.47)
                .overlay(Circle().fill(Color.primary).padding(size * 0.052))
                .offset(x: size * 0.41, y: -size * 0.41)
        }
        .frame(width: size, height: size)
        .compositingGroup()
        .phaseAnimator(thinking ? [0.0, 1.0] : [0.5]) { orb, phase in
            orb.scaleEffect(0.94 + phase * 0.12).opacity(thinking ? 0.75 + phase * 0.25 : 1)
        } animation: { _ in .easeInOut(duration: 0.9) }
        .accessibilityHidden(true)
    }
}

/// A row of three dots that pulse while the first words are on their way.
struct TypingDots: View {
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 7, height: 7)
                    .phaseAnimator([0.3, 1.0]) { dot, value in
                        dot.opacity(value)
                    } animation: { _ in .easeInOut(duration: 0.55).delay(Double(i) * 0.18) }
            }
        }
        .padding(.vertical, 6)
        .accessibilityLabel("Writing")
    }
}
