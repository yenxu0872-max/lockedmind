// Draws Lockedmind's iPhone app icon: the orb and its dot on the dark body,
// full-bleed and opaque, 1024 px, as the App Store wants (iOS rounds the
// corners itself). The Mac icon is native/makeicon.swift; same colours.
//
//   swift tools/makeicon.swift Lockedmind/Assets.xcassets/AppIcon.appiconset/AppIcon.png

import AppKit

let size = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 255) / 255, green: CGFloat(hex >> 8 & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: a)
}

// The body: near-black, a touch lighter at the top.
ctx.drawLinearGradient(CGGradient(colorsSpace: space, colors: [rgb(0x26262e), rgb(0x111115)] as CFArray, locations: [0, 1])!,
                       start: CGPoint(x: 512, y: 1024), end: CGPoint(x: 512, y: 0), options: [])

// A soft violet glow behind the orb.
let centre = CGPoint(x: 500, y: 492)
ctx.drawRadialGradient(CGGradient(colorsSpace: space, colors: [rgb(0xac77fa, 0.45), rgb(0xac77fa, 0)] as CFArray, locations: [0, 1])!,
                       startCenter: centre, startRadius: 0, endCenter: centre, endRadius: 500, options: [])

// The orb: violet at the top left to sky blue at the bottom right.
let orbR: CGFloat = 290
ctx.saveGState()
ctx.addEllipse(in: CGRect(x: centre.x - orbR, y: centre.y - orbR, width: orbR * 2, height: orbR * 2)); ctx.clip()
ctx.drawLinearGradient(CGGradient(colorsSpace: space, colors: [rgb(0xac77fa), rgb(0x00aee9)] as CFArray, locations: [0, 1])!,
                       start: CGPoint(x: centre.x - orbR * 0.5, y: centre.y + orbR * 0.87),
                       end: CGPoint(x: centre.x + orbR * 0.5, y: centre.y - orbR * 0.87), options: [])
ctx.drawRadialGradient(CGGradient(colorsSpace: space, colors: [rgb(0xffffff, 0.30), rgb(0xffffff, 0)] as CFArray, locations: [0, 1])!,
                       startCenter: CGPoint(x: centre.x - 104, y: centre.y + 116), startRadius: 0,
                       endCenter: CGPoint(x: centre.x - 104, y: centre.y + 116), endRadius: 300, options: [])
ctx.restoreGState()

// The white dot at the top right, ringed in the body colour.
let dot = CGPoint(x: centre.x + orbR * 0.82, y: centre.y + orbR * 0.82), dotR = orbR * 0.368, ring = orbR * 0.104
ctx.setFillColor(rgb(0x1d1d24)); ctx.fillEllipse(in: CGRect(x: dot.x - dotR - ring, y: dot.y - dotR - ring, width: (dotR + ring) * 2, height: (dotR + ring) * 2))
ctx.setFillColor(rgb(0xffffff)); ctx.fillEllipse(in: CGRect(x: dot.x - dotR, y: dot.y - dotR, width: dotR * 2, height: dotR * 2))

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
