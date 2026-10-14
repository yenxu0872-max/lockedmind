// Lockedmind's look: a private journal kept by a living mind.
// Warm paper (or deep ink at night), answers set in a book serif, and the
// violet-to-sky orb from the logo as the one living, glowing thing on screen.

import SwiftUI
import UIKit

enum Theme {
    /// The orb's colours, the same as the website and the Mac icon.
    static let violet = Color(red: 0.675, green: 0.467, blue: 0.980)      // #ac77fa
    static let sky = Color(red: 0.0, green: 0.682, blue: 0.914)           // #00aee9
    static let lilac = Color(red: 0.80, green: 0.70, blue: 1.0)
    static let indigo = Color(red: 0.42, green: 0.36, blue: 0.95)
    static let periwinkle = Color(red: 0.50, green: 0.62, blue: 1.0)
    static let deepSky = Color(red: 0.0, green: 0.52, blue: 0.86)

    static let accent = dynamic(light: UIColor(red: 0.42, green: 0.27, blue: 0.90, alpha: 1),
                                dark: UIColor(red: 0.72, green: 0.60, blue: 1.0, alpha: 1))

    /// The page: warm paper by day, deep violet-black ink by night.
    static let paper = dynamic(light: UIColor(red: 0.984, green: 0.980, blue: 0.969, alpha: 1),
                               dark: UIColor(red: 0.039, green: 0.035, blue: 0.059, alpha: 1))
    /// Cards and fields that sit on the paper.
    static let card = dynamic(light: UIColor(red: 1, green: 1, blue: 1, alpha: 1),
                              dark: UIColor(red: 0.09, green: 0.085, blue: 0.125, alpha: 1))
    static let hairline = dynamic(light: UIColor(white: 0, alpha: 0.08), dark: UIColor(white: 1, alpha: 0.09))

    static let orb = LinearGradient(colors: [violet, sky], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let thread = LinearGradient(colors: [violet.opacity(0.55), sky.opacity(0.45)], startPoint: .top, endPoint: .bottom)

    /// Answers read like a letter: the system's serif (New York).
    static let answer = Font.system(.body, design: .serif)
    static let question = Font.system(.title3, design: .rounded).weight(.semibold)

    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

// MARK: - The living orb

/// The logo, alive: a sphere of slowly drifting violet and sky light.
/// Resting, it barely breathes; ready (something is typed), it brightens;
/// thinking, it swirls and a ring of light runs round it.
struct LivingOrb: View {
    enum Mood { case resting, ready, thinking }

    var size: CGFloat = 64
    var mood: Mood = .resting
    /// The logo's small dot at the orb's shoulder.
    var dot = true
    /// A symbol drawn on the orb itself (the send arrow, stop, a lock).
    var glyph: String? = nil
    var glow = true
    /// Still orbs cost nothing; only animate where it says something.
    var animated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || !animated)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            // Only the sphere takes up room; the halo and the ring spill over it.
            sphere(t)
                .frame(width: size, height: size)
                .background { if glow { halo(t) } }
                .overlay { if mood == .thinking && !reduceMotion { ring(t) } }
                .overlay {
                    if let glyph {
                        Image(systemName: glyph)
                            .font(.system(size: size * 0.4, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
        }
        .frame(width: size, height: size)
        .overlay(alignment: .topTrailing) {
            if dot {
                Circle()
                    .fill(Theme.paper)
                    .frame(width: size * 0.47, height: size * 0.47)
                    .overlay(Circle().fill(Color.primary).padding(size * 0.052))
                    .offset(x: size * 0.145, y: -size * 0.145)
            }
        }
        .accessibilityHidden(true)
    }

    private var speed: Double {
        switch mood {
        case .resting: 0.35
        case .ready: 0.8
        case .thinking: 2.2
        }
    }

    private func sphere(_ time: Double) -> some View {
        let t = time * speed
        func w(_ phase: Double, _ amount: Float) -> Float { Float(sin(t + phase)) * amount }
        let points: [SIMD2<Float>] = [
            [0, 0], [0.5 + w(0, 0.12), 0], [1, 0],
            [0, 0.5 + w(1.3, 0.12)], [0.5 + w(2.1, 0.18), 0.5 + w(0.7, 0.18)], [1, 0.5 + w(2.9, 0.12)],
            [0, 1], [0.5 + w(3.7, 0.12), 1], [1, 1],
        ]
        let colors: [Color] = [Theme.lilac, Theme.violet, Theme.indigo,
                               Theme.violet, Theme.periwinkle, Theme.sky,
                               Theme.indigo, Theme.sky, Theme.deepSky]
        let breath = 1 + (mood == .thinking ? 0.035 : 0.012) * sin(time * (mood == .thinking ? 3.2 : 1.1))
        return MeshGradient(width: 3, height: 3, points: points, colors: colors)
            .clipShape(Circle())
            .overlay(
                Circle().fill(RadialGradient(colors: [.white.opacity(0.42), .clear],
                                             center: UnitPoint(x: 0.32, y: 0.27),
                                             startRadius: 0, endRadius: size * 0.5))
            )
            .overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: max(0.5, size * 0.012)))
            .scaleEffect(reduceMotion ? 1 : breath)
            .saturation(mood == .resting ? 0.9 : 1.05)
    }

    private func halo(_ time: Double) -> some View {
        let strength = mood == .thinking ? 0.5 + 0.15 * sin(time * 3.2) : (mood == .ready ? 0.42 : 0.3)
        return Circle()
            .fill(RadialGradient(colors: [Theme.violet.opacity(strength), Theme.sky.opacity(strength * 0.4), .clear],
                                 center: .center, startRadius: size * 0.3, endRadius: size * 0.95))
            .frame(width: size * 1.9, height: size * 1.9)
            .allowsHitTesting(false)
    }

    private func ring(_ time: Double) -> some View {
        Circle()
            .trim(from: 0, to: 0.62)
            .stroke(AngularGradient(colors: [Theme.violet.opacity(0), Theme.violet, Theme.sky],
                                    center: .center),
                    style: StrokeStyle(lineWidth: max(1.5, size * 0.055), lineCap: .round))
            .frame(width: size * 1.28, height: size * 1.28)
            .rotationEffect(.degrees(time * 220))
    }
}

// MARK: - The glow

/// Light rising from the bottom of the screen, as if from the orb. Faint at
/// rest; brighter and moving while the mind is thinking.
struct Aurora: View {
    var energy: Double            // 0 … 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: reduceMotion || energy < 0.5)) { context in
            let t = context.date.timeIntervalSinceReferenceDate * 0.6
            let a = (scheme == .dark ? 0.55 : 0.27) * energy
            let lift = Float(0.35 - 0.2 * energy)
            MeshGradient(width: 3, height: 3, points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, lift + Float(sin(t)) * 0.08], [0.5 + Float(sin(t * 0.7)) * 0.2, lift + Float(cos(t)) * 0.1], [1, lift + Float(cos(t * 1.3)) * 0.08],
                [0, 1], [0.5, 1], [1, 1],
            ], colors: [
                .clear, .clear, .clear,
                Theme.violet.opacity(a * 0.35), Theme.periwinkle.opacity(a * 0.4), Theme.sky.opacity(a * 0.3),
                Theme.violet.opacity(a), Theme.indigo.opacity(a * 0.9), Theme.sky.opacity(a),
            ])
        }
        .frame(height: 340)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Little pieces

/// "Thinking on this iPhone…", with light running through the words.
struct ThinkingLine: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let p = (context.date.timeIntervalSinceReferenceDate * 0.7).truncatingRemainder(dividingBy: 1) * 2.2 - 0.6
            Text("Thinking on this iPhone…")
                .font(Theme.answer.italic())
                .foregroundStyle(LinearGradient(colors: [.secondary, Theme.violet, Theme.sky, .secondary],
                                                startPoint: UnitPoint(x: p - 0.5, y: 0.5),
                                                endPoint: UnitPoint(x: p + 0.5, y: 0.5)))
        }
        .accessibilityLabel("Thinking")
    }
}

/// The main call to action: a capsule of the orb's own light.
struct GlowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(Theme.orb, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
            .shadow(color: Theme.violet.opacity(0.45), radius: configuration.isPressed ? 8 : 18, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

/// A small capsule with a lock: the app's privacy, always in sight.
struct PrivateBadge: View {
    var text = "Private · on this iPhone"

    var body: some View {
        Label(text, systemImage: "lock.fill")
            .font(.system(.footnote, design: .rounded).weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.card.opacity(0.8), in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.hairline))
    }
}
