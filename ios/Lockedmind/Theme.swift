// Lockedmind's look: a private journal kept by a living mind.
// Geist type (the website's own), warm paper by day and deep ink at night,
// and the logo, a sphere of violet-to-sky light with a keyhole lit from
// inside, as the one living, glowing thing on screen.

import SwiftUI
import UIKit
import CoreText

enum Theme {
    /// The orb's colours, the same as the website and the icon.
    static let violet = Color(red: 0.675, green: 0.467, blue: 0.980)      // #ac77fa
    static let sky = Color(red: 0.0, green: 0.682, blue: 0.914)           // #00aee9
    static let lilac = Color(red: 0.80, green: 0.70, blue: 1.0)
    static let indigo = Color(red: 0.42, green: 0.36, blue: 0.95)
    static let periwinkle = Color(red: 0.50, green: 0.62, blue: 1.0)
    static let deepSky = Color(red: 0.0, green: 0.52, blue: 0.86)
    static let ink = Color(red: 0.043, green: 0.039, blue: 0.075)
    static let online = Color(red: 0.20, green: 0.78, blue: 0.45)

    static let accent = dynamic(light: UIColor(red: 0.42, green: 0.27, blue: 0.90, alpha: 1),
                                dark: UIColor(red: 0.72, green: 0.60, blue: 1.0, alpha: 1))

    /// The page: warm paper by day, deep violet-black ink by night.
    static let paper = dynamic(light: UIColor(red: 0.984, green: 0.980, blue: 0.969, alpha: 1),
                               dark: UIColor(red: 0.039, green: 0.035, blue: 0.059, alpha: 1))
    /// Cards and fields that sit on the paper.
    static let card = dynamic(light: UIColor(red: 1, green: 1, blue: 1, alpha: 1),
                              dark: UIColor(red: 0.09, green: 0.085, blue: 0.125, alpha: 1))
    /// A quieter card, for chips and the code block's header.
    static let well = dynamic(light: UIColor(red: 0.95, green: 0.94, blue: 0.93, alpha: 1),
                              dark: UIColor(red: 0.12, green: 0.115, blue: 0.16, alpha: 1))
    static let hairline = dynamic(light: UIColor(white: 0, alpha: 0.08), dark: UIColor(white: 1, alpha: 0.09))

    static let orb = LinearGradient(colors: [violet, sky], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let thread = LinearGradient(colors: [violet.opacity(0.55), sky.opacity(0.45)], startPoint: .top, endPoint: .bottom)

    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    // MARK: Type

    /// Geist, at the size of an iOS text style, growing with Dynamic Type.
    static func ui(_ style: Font.TextStyle, _ weight: Font.Weight = .regular) -> Font {
        .custom(name("Geist", weight), size: size(style), relativeTo: style)
    }

    /// Geist Mono, for code.
    static func mono(_ style: Font.TextStyle, _ weight: Font.Weight = .regular) -> Font {
        .custom(name("GeistMono", weight), size: size(style), relativeTo: style)
    }

    static let answer = ui(.body)
    static let question = ui(.title3, .semibold)

    private static func name(_ family: String, _ weight: Font.Weight) -> String {
        switch weight {
        case .ultraLight, .thin, .light: "\(family)-Light"
        case .medium: "\(family)-Medium"
        case .semibold: "\(family)-SemiBold"
        case .bold: "\(family)-Bold"
        case .heavy, .black: "\(family)-ExtraBold"
        default: "\(family)-Regular"
        }
    }

    private static func size(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline, .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        default: 17
        }
    }

    /// Makes Geist and Geist Mono (bundled, SIL Open Font License) available,
    /// including to the navigation bars UIKit draws.
    static func registerFonts() {
        for name in ["Geist-Variable", "GeistMono-Variable"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "woff2") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        let bar = UINavigationBar.appearance()
        if let title = UIFont(name: "Geist-SemiBold", size: 17) {
            bar.titleTextAttributes = [.font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: title)]
        }
        if let large = UIFont(name: "Geist-Bold", size: 34) {
            bar.largeTitleTextAttributes = [.font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: large)]
        }
    }
}

// MARK: - The logo

/// A keyhole: a round head over a tapering stem.
struct Keyhole: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let head = CGRect(x: rect.minX, y: rect.minY, width: w, height: w)
        let cx = rect.midX
        let top = rect.minY + w * 0.72, bottom = rect.maxY
        let topHalf = w * 0.25, bottomHalf = w * 0.40, corner = w * 0.12
        var stem = Path()
        stem.move(to: CGPoint(x: cx - topHalf, y: top))
        stem.addLine(to: CGPoint(x: cx + topHalf, y: top))
        stem.addLine(to: CGPoint(x: cx + bottomHalf, y: bottom - corner))
        stem.addQuadCurve(to: CGPoint(x: cx + bottomHalf - corner, y: bottom), control: CGPoint(x: cx + bottomHalf, y: bottom))
        stem.addLine(to: CGPoint(x: cx - bottomHalf + corner, y: bottom))
        stem.addQuadCurve(to: CGPoint(x: cx - bottomHalf, y: bottom - corner), control: CGPoint(x: cx - bottomHalf, y: bottom))
        stem.closeSubpath()
        return Path(ellipseIn: head).union(stem)
    }
}

/// The logo, alive: a sphere of slowly drifting violet and sky light with a
/// keyhole lit from inside. Resting, it barely breathes; ready (something
/// is typed), it brightens; thinking, it swirls, the keyhole glows and a
/// ring of light runs round it.
struct LivingOrb: View {
    enum Mood { case resting, ready, thinking }

    var size: CGFloat = 64
    var mood: Mood = .resting
    /// The keyhole from the logo.
    var keyhole = true
    /// A symbol drawn on the orb instead (the send arrow, stop).
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
                    } else if keyhole {
                        lock(t)
                    }
                }
        }
        .frame(width: size, height: size)
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
            [0, 0], [0.55 + w(0, 0.12), 0], [1, 0],
            [0, 0.45 + w(1.3, 0.12)], [0.42 + w(2.1, 0.18), 0.52 + w(0.7, 0.18)], [1, 0.6 + w(2.9, 0.12)],
            [0, 1], [0.6 + w(3.7, 0.12), 1], [1, 1],
        ]
        let colors: [Color] = [Theme.lilac, Theme.violet, Theme.indigo,
                               Theme.violet, Theme.periwinkle, Theme.sky,
                               Theme.indigo, Theme.sky, Theme.deepSky]
        let breath = 1 + (mood == .thinking ? 0.035 : 0.012) * sin(time * (mood == .thinking ? 3.2 : 1.1))
        return MeshGradient(width: 3, height: 3, points: points, colors: colors)
            .clipShape(Circle())
            .overlay(Circle().fill(RadialGradient(colors: [.white.opacity(0.45), .clear],
                                                  center: UnitPoint(x: 0.3, y: 0.24),
                                                  startRadius: 0, endRadius: size * 0.55)))
            .overlay(Circle().fill(RadialGradient(colors: [.clear, .black.opacity(0.2)],
                                                  center: UnitPoint(x: 0.35, y: 0.3),
                                                  startRadius: size * 0.35, endRadius: size * 0.72)))
            .overlay(Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.05), Theme.lilac.opacity(0.35)],
                                                          startPoint: .topLeading, endPoint: .bottomTrailing),
                                           lineWidth: max(0.6, size * 0.012)))
            .scaleEffect(reduceMotion ? 1 : breath)
            .saturation(mood == .resting ? 0.92 : 1.05)
    }

    /// The keyhole, lit from inside; brighter while thinking.
    private func lock(_ time: Double) -> some View {
        let lit = mood == .thinking ? 0.75 + 0.25 * sin(time * 3.2) : (mood == .ready ? 0.9 : 0.75)
        return Keyhole()
            .fill(LinearGradient(colors: [.white, Color(red: 0.93, green: 0.89, blue: 1.0), Theme.lilac],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: size * 0.24, height: size * 0.42)
            .offset(y: size * 0.015)
            .shadow(color: .white.opacity(0.9 * lit), radius: size * 0.025)
            .shadow(color: Theme.lilac.opacity(lit), radius: size * 0.07)
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
            .stroke(AngularGradient(colors: [Theme.violet.opacity(0), Theme.violet, Theme.sky], center: .center),
                    style: StrokeStyle(lineWidth: max(1.5, size * 0.055), lineCap: .round))
            .frame(width: size * 1.28, height: size * 1.28)
            .rotationEffect(.degrees(time * 220))
    }
}

// MARK: - The page

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

/// A faint grain over the paper, so it feels like a page rather than a screen.
struct Grain: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Canvas { context, size in
            var rng = SeededRandom(seed: 7)
            let dots = Int(size.width * size.height / 70)
            let shade: Color = scheme == .dark ? .white : .black
            for _ in 0..<dots {
                let x = rng.next() * size.width, y = rng.next() * size.height
                let a = 0.02 + rng.next() * 0.035
                context.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)), with: .color(shade.opacity(a)))
            }
        }
        .drawingGroup()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct SeededRandom {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
}

/// The paper itself: colour, grain and the rising glow.
struct Paper: View {
    var energy: Double = 0.3

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.paper
            Grain()
            Aurora(energy: energy)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Little pieces

/// "Thinking on this iPhone…", with light running through the words.
struct ThinkingLine: View {
    var text = "Thinking on this iPhone…"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let p = (context.date.timeIntervalSinceReferenceDate * 0.7).truncatingRemainder(dividingBy: 1) * 2.2 - 0.6
            Text(text)
                .font(Theme.ui(.body, .medium))
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
            .font(Theme.ui(.headline, .semibold))
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

/// A small capsule with a symbol: the app's privacy, always in sight.
struct PrivateBadge: View {
    var text = "Private · on this iPhone"
    var icon = "lock.fill"

    var body: some View {
        Label(text, systemImage: icon)
            .font(Theme.ui(.footnote, .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.card.opacity(0.8), in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.hairline))
    }
}

/// A tinted rounded square behind a symbol, like the Settings app's icons.
struct IconTile: View {
    let symbol: String
    var colors: [Color] = [Theme.violet, Theme.sky]

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 29, height: 29)
            .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

struct TightLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}
