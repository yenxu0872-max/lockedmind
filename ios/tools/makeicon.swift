// Draws Lockedmind's logo, the keyhole orb: a sphere of violet-to-sky light
// (the mind) with a keyhole through it (locked), lit from inside. Renders
// the iPhone app icon (default, dark and tinted, 1024 px, opaque where
// Apple wants it) and a transparent logo mark, with SwiftUI's own
// MeshGradient so it matches the orb in the app.
//
//   swift tools/makeicon.swift Lockedmind/Assets.xcassets/AppIcon.appiconset
//   (then move Logo.png to AppStore/)

import SwiftUI
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".", isDirectory: true)

let violet = Color(red: 0.675, green: 0.467, blue: 0.980)
let sky = Color(red: 0.0, green: 0.682, blue: 0.914)
let lilac = Color(red: 0.80, green: 0.70, blue: 1.0)
let indigo = Color(red: 0.42, green: 0.36, blue: 0.95)
let periwinkle = Color(red: 0.50, green: 0.62, blue: 1.0)
let deepSky = Color(red: 0.0, green: 0.52, blue: 0.86)
let ink = Color(red: 0.043, green: 0.039, blue: 0.075)

/// A keyhole: a round head over a tapering stem, in a box twice as tall as wide (roughly).
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
        // One outline, so a stroke doesn't cross where the head meets the stem.
        return Path(ellipseIn: head).union(stem)
    }
}

struct Mark: View {
    var size: CGFloat
    var tinted = false

    var body: some View {
        let colors: [Color] = tinted
            ? [.white, Color(white: 0.85), Color(white: 0.62), Color(white: 0.85), Color(white: 0.72), Color(white: 0.55), Color(white: 0.6), Color(white: 0.5), Color(white: 0.42)]
            : [lilac, violet, indigo, violet, periwinkle, sky, indigo, sky, deepSky]
        ZStack {
            // the orb
            MeshGradient(width: 3, height: 3, points: [
                [0, 0], [0.55, 0], [1, 0],
                [0, 0.45], [0.42, 0.52], [1, 0.6],
                [0, 1], [0.6, 1], [1, 1],
            ], colors: colors)
            .clipShape(Circle())
            // light from the top left, so it reads as a sphere
            Circle().fill(RadialGradient(colors: [.white.opacity(0.45), .clear], center: UnitPoint(x: 0.3, y: 0.24),
                                         startRadius: 0, endRadius: size * 0.55))
            // shade at the bottom right
            Circle().fill(RadialGradient(colors: [.clear, .black.opacity(tinted ? 0.15 : 0.22)], center: UnitPoint(x: 0.35, y: 0.3),
                                         startRadius: size * 0.35, endRadius: size * 0.72))
            // a thin rim of light
            Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.05), lilac.opacity(0.35)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: size * 0.012)
            // the keyhole, lit from inside the mind
            Keyhole()
                .fill(LinearGradient(colors: [.white, Color(red: 0.93, green: 0.89, blue: 1.0), lilac],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.24, height: size * 0.42)
                .offset(y: size * 0.015)
                .shadow(color: .white.opacity(0.9), radius: size * 0.025)
                .shadow(color: lilac.opacity(0.9), radius: size * 0.07)
        }
        .frame(width: size, height: size)
        .shadow(color: (tinted ? Color.white : violet).opacity(0.35), radius: size * 0.12)
    }
}

struct Icon: View {
    enum Kind { case standard, dark, tinted }
    var kind: Kind

    var body: some View {
        ZStack {
            switch kind {
            case .standard:
                LinearGradient(colors: [Color(red: 0.12, green: 0.10, blue: 0.22), ink], startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [violet.opacity(0.45), .clear], center: .center, startRadius: 40, endRadius: 520)
                RadialGradient(colors: [sky.opacity(0.22), .clear], center: UnitPoint(x: 0.7, y: 0.85), startRadius: 0, endRadius: 420)
            case .dark:
                Color.clear      // iOS puts its own dark backdrop behind a dark icon
            case .tinted:
                Color.black
            }
            Mark(size: 640, tinted: kind == .tinted)
        }
        .frame(width: 1024, height: 1024)
    }
}

@MainActor func save(_ view: some View, _ name: String, opaque: Bool) {
    let renderer = ImageRenderer(content: view)
    renderer.scale = 1
    renderer.isOpaque = opaque
    guard let image = renderer.cgImage else { print("could not render \(name)"); return }
    let rep = NSBitmapImageRep(cgImage: image)
    try! rep.representation(using: .png, properties: [:])!.write(to: out.appending(path: name))
    print(out.appending(path: name).path)
}

MainActor.assumeIsolated {
    save(Icon(kind: .standard), "AppIcon.png", opaque: true)
    save(Icon(kind: .dark), "AppIcon-dark.png", opaque: false)
    save(Icon(kind: .tinted), "AppIcon-tinted.png", opaque: true)
    save(Mark(size: 900).padding(62).frame(width: 1024, height: 1024), "Logo.png", opaque: false)
}
