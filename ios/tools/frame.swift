// Frames raw app captures as App Store screenshots: 1320 x 2868 (6.9-inch
// iPhone), a Geist headline over the phone, on the brand's dark background.
//
//   swift tools/frame.swift RAW_DIR OUT_DIR
//
// RAW_DIR holds raw-1-*.png … raw-7-*.png (Simulator screenshots).

import SwiftUI
import AppKit
import CoreText

let args = CommandLine.arguments
let raw = URL(fileURLWithPath: args.count > 1 ? args[1] : "build/shots/raw", isDirectory: true)
let out = URL(fileURLWithPath: args.count > 2 ? args[2] : "AppStore/screenshots", isDirectory: true)
let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
for font in ["Geist-Variable", "GeistMono-Variable"] {
    let url = here.deletingLastPathComponent().appending(path: "Lockedmind/Fonts/\(font).woff2")
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
}

let headlines: [String: (String, String)] = [
    "1": ("A private mind", "that lives on your iPhone"),
    "2": ("Clear answers,", "and what to ask next"),
    "3": ("Reads your photos", "and documents, right here"),
    "4": ("Online or offline,", "nothing you write is sent"),
    "5": ("Locked with Face ID.", "Open only for you."),
    "6": ("Your chats stay", "on this iPhone"),
    "7": ("Speak, scan, attach,", "all on the device"),
]

let violet = Color(red: 0.675, green: 0.467, blue: 0.980)
let sky = Color(red: 0.0, green: 0.682, blue: 0.914)

struct Shot: View {
    let image: NSImage
    let line1: String
    let line2: String

    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0.027, green: 0.027, blue: 0.04)
            RadialGradient(colors: [Color(red: 0.33, green: 0.2, blue: 0.6).opacity(0.95), .clear],
                           center: UnitPoint(x: 0.5, y: 0.05), startRadius: 0, endRadius: 1100)
            RadialGradient(colors: [Color(red: 0.0, green: 0.28, blue: 0.43).opacity(0.85), .clear],
                           center: UnitPoint(x: 0.62, y: 0.95), startRadius: 0, endRadius: 1000)
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text(line1).foregroundStyle(.white)
                    Text(line2).foregroundStyle(LinearGradient(colors: [Color(red: 0.84, green: 0.77, blue: 1), Color(red: 0.62, green: 0.86, blue: 1)],
                                                               startPoint: .leading, endPoint: .trailing))
                }
                .font(.custom("Geist-SemiBold", size: 92))
                .tracking(-1.5)
                .multilineTextAlignment(.center)
                .padding(.top, 210)
                Spacer()
            }
            phone
                .padding(.top, 610)
        }
        .frame(width: 1320, height: 2868)
    }

    private var phone: some View {
        let screenWidth: CGFloat = 930
        let screenHeight = screenWidth * image.size.height / image.size.width
        let bezel: CGFloat = 22
        return Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .frame(width: screenWidth, height: screenHeight)
            .clipShape(RoundedRectangle(cornerRadius: 128, style: .continuous))
            .padding(bezel)
            .background(RoundedRectangle(cornerRadius: 150, style: .continuous).fill(Color(red: 0.11, green: 0.11, blue: 0.125)))
            .overlay(RoundedRectangle(cornerRadius: 150, style: .continuous)
                .strokeBorder(LinearGradient(colors: [Color(white: 0.45), Color(white: 0.2), violet.opacity(0.5)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3))
            .shadow(color: .black.opacity(0.6), radius: 50, y: 30)
            .shadow(color: violet.opacity(0.25), radius: 80)
    }
}

MainActor.assumeIsolated {
    try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    let files = (try? FileManager.default.contentsOfDirectory(at: raw, includingPropertiesForKeys: nil)) ?? []
    for file in files.filter({ $0.lastPathComponent.hasPrefix("raw-") && $0.pathExtension == "png" })
        .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
        let stem = file.deletingPathExtension().lastPathComponent        // raw-1-start
        let key = String(stem.split(separator: "-")[1])
        guard let (one, two) = headlines[key], let image = NSImage(contentsOf: file) else { continue }
        let renderer = ImageRenderer(content: Shot(image: image, line1: one, line2: two))
        renderer.scale = 1
        renderer.isOpaque = true
        guard let cg = renderer.cgImage else { print("could not render \(stem)"); continue }
        let target = out.appending(path: "\(stem.dropFirst(4)).png")
        try! NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!.write(to: target)
        print(target.path)
    }
}
