// Draws the Lockedmind Mac app icon — the logo, a violet-to-sky orb with a
// keyhole lit from inside, on a dark macOS-style rounded square — as a 1024 px
// PNG. `oriel app` turns it into AppIcon.icns. (Until October 2026 the logo
// was a white dot on the orb's shoulder.)
//
//   swift makeicon.swift out.png
//
// Colours are the logo's own (ui/_design/logo.svg, the iPhone icon): lilac →
// violet #ac77fa → periwinkle → sky #00aee9, the keyhole white → lilac.

import AppKit

let size = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 255) / 255, green: CGFloat(hex >> 8 & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: a)
}
func gradient(_ colors: [CGColor], _ stops: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors as CFArray, locations: stops)!
}

// Apple's icon grid: an 824 px body centred on the 1024 canvas, with room for the shadow.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0x000000, 0.35))
ctx.addPath(shape); ctx.setFillColor(rgb(0x0b0a13)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(shape); ctx.clip()
// The body: deep violet-black ink, a touch lighter at the top.
ctx.drawLinearGradient(gradient([rgb(0x1f1a38), rgb(0x0b0a13)], [0, 1]),
                       start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
// Light from the mind: violet behind the orb, a little sky lower down.
let centre = CGPoint(x: 512, y: 512)
ctx.drawRadialGradient(gradient([rgb(0xac77fa, 0.5), rgb(0xac77fa, 0)], [0, 1]),
                       startCenter: centre, startRadius: 0, endCenter: centre, endRadius: 440, options: [])
ctx.drawRadialGradient(gradient([rgb(0x00aee9, 0.22), rgb(0x00aee9, 0)], [0, 1]),
                       startCenter: CGPoint(x: 640, y: 230), startRadius: 0, endCenter: CGPoint(x: 640, y: 230), endRadius: 380, options: [])

// The orb.
let r: CGFloat = 268
let orbRect = CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2)
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 70, color: rgb(0xac77fa, 0.55))
ctx.setFillColor(rgb(0x8c7cff)); ctx.fillEllipse(in: orbRect)
ctx.restoreGState()
ctx.saveGState()
ctx.addEllipse(in: orbRect); ctx.clip()
ctx.drawLinearGradient(gradient([rgb(0xd6c4ff), rgb(0xac77fa), rgb(0x7d8cff), rgb(0x00aee9)], [0, 0.3, 0.64, 1]),
                       start: CGPoint(x: centre.x - r * 0.72, y: centre.y + r * 0.82),
                       end: CGPoint(x: centre.x + r * 0.72, y: centre.y - r * 0.88), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
// light from the top left, so it reads as a sphere, and shade at the bottom right
let light = CGPoint(x: centre.x - r * 0.4, y: centre.y + r * 0.52)
ctx.drawRadialGradient(gradient([rgb(0xffffff, 0.5), rgb(0xffffff, 0)], [0, 1]),
                       startCenter: light, startRadius: 0, endCenter: light, endRadius: r * 1.05, options: [])
let shade = CGPoint(x: centre.x - r * 0.28, y: centre.y + r * 0.4)
ctx.drawRadialGradient(gradient([rgb(0x000000, 0), rgb(0x000000, 0.24)], [0, 1]),
                       startCenter: shade, startRadius: r * 0.95, endCenter: shade, endRadius: r * 1.5, options: [.drawsAfterEndLocation])
ctx.restoreGState()
// a thin rim of light
ctx.setStrokeColor(rgb(0xffffff, 0.42)); ctx.setLineWidth(r * 0.022)
ctx.strokeEllipse(in: orbRect.insetBy(dx: r * 0.011, dy: r * 0.011))

// The keyhole, lit from inside the mind (y runs upwards here).
func keyhole() -> CGPath {
    let w = r * 2 * 0.24, h = r * 2 * 0.42
    let top = centre.y + h / 2 - r * 2 * 0.015          // its top edge
    let head = CGRect(x: centre.x - w / 2, y: top - w, width: w, height: w)
    let stemTop = top - w * 0.72, bottom = top - h
    let topHalf = w * 0.25, bottomHalf = w * 0.40, corner = w * 0.12
    let p = CGMutablePath()
    p.move(to: CGPoint(x: centre.x - topHalf, y: stemTop))
    p.addLine(to: CGPoint(x: centre.x + topHalf, y: stemTop))
    p.addLine(to: CGPoint(x: centre.x + bottomHalf, y: bottom + corner))
    p.addQuadCurve(to: CGPoint(x: centre.x + bottomHalf - corner, y: bottom), control: CGPoint(x: centre.x + bottomHalf, y: bottom))
    p.addLine(to: CGPoint(x: centre.x - bottomHalf + corner, y: bottom))
    p.addQuadCurve(to: CGPoint(x: centre.x - bottomHalf, y: bottom + corner), control: CGPoint(x: centre.x - bottomHalf, y: bottom))
    p.closeSubpath()
    // one outline, so the head and the stem don't cancel where they overlap
    return CGPath(ellipseIn: head, transform: nil).union(p)
}
let hole = keyhole()
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 46, color: rgb(0xd9c8ff, 0.95))
ctx.addPath(hole); ctx.setFillColor(rgb(0xe4d6ff)); ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(hole); ctx.clip()
let box = hole.boundingBox
ctx.drawLinearGradient(gradient([rgb(0xffffff), rgb(0xeee4ff), rgb(0xcdb4ff)], [0, 0.6, 1]),
                       start: CGPoint(x: box.midX, y: box.maxY), end: CGPoint(x: box.midX, y: box.minY), options: [])
ctx.restoreGState()

// A hairline edge, as on Apple's own dark icons.
ctx.addPath(shape); ctx.setStrokeColor(rgb(0xffffff, 0.08)); ctx.setLineWidth(3); ctx.strokePath()
ctx.restoreGState()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
