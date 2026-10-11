// Renders the Fledge app icon layers at 1024×1024.
// Usage: swift Design/Icon/render-icon.swift <output-dir>
// Outputs: fledge-icon-1024.png (flattened), layer-background.png, layer-bird.png (transparent),
//          fledge-icon-dark-1024.png, fledge-icon-tinted-1024.png (grayscale glyph for tinted preview).
// The same geometry lives in fledge-icon.svg; import the two layer PNGs (or the SVG groups) into Icon Composer.

import AppKit
import CoreGraphics

let size: CGFloat = 1024
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

// Brand palette (see docs/DESIGN.md)
let sky = rgb(0x4F8DFF)
let skyLight = rgb(0x9CC4FF)
let dawn = rgb(0xFFD2AE)
let duskTop = rgb(0x1B2240)
let duskBottom = rgb(0x3A3F78)
let cloud = rgb(0xFFFFFF)
let coral = rgb(0xFF6A52)
let gold = rgb(0xFFB13D)
let ink = rgb(0x1B2240)

enum Variant { case light, dark, tinted }

func context() -> CGContext {
    let ctx = CGContext(
        data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    // Flip to a top-left origin so coordinates match the SVG.
    ctx.translateBy(x: 0, y: size)
    ctx.scaleBy(x: 1, y: -1)
    return ctx
}

func drawBackground(_ ctx: CGContext, _ variant: Variant) {
    let colors: [CGColor]
    switch variant {
    case .light: colors = [sky, skyLight, dawn]
    case .dark: colors = [duskTop, duskTop, duskBottom]
    case .tinted: colors = [rgb(0x000000), rgb(0x000000), rgb(0x000000)]
    }
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors as CFArray, locations: [0, 0.6, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 0), end: CGPoint(x: 512, y: size), options: [])
}

func drawBird(_ ctx: CGContext, _ variant: Variant) {
    let body = variant == .tinted ? rgb(0xFFFFFF) : cloud
    let wing = variant == .tinted ? rgb(0x8A8A8A) : coral
    let beak = variant == .tinted ? rgb(0xBDBDBD) : gold
    let eye = variant == .tinted ? rgb(0x3A3A3A) : ink

    // Everything is shifted 28 pt left so body + beak sit optically centred.
    ctx.saveGState()
    ctx.translateBy(x: -28, y: 0)

    // Tuft: one small feather curling forward.
    ctx.setFillColor(body)
    ctx.saveGState()
    ctx.translateBy(x: 520, y: 318)
    ctx.rotate(by: .pi / 9)
    ctx.addEllipse(in: CGRect(x: -22, y: -52, width: 44, height: 96))
    ctx.fillPath()
    ctx.restoreGState()

    // Body: a round fledgling.
    ctx.addEllipse(in: CGRect(x: 262, y: 300, width: 500, height: 500))
    ctx.fillPath()

    // Beak.
    ctx.setFillColor(beak)
    ctx.move(to: CGPoint(x: 748, y: 478))
    ctx.addLine(to: CGPoint(x: 840, y: 514))
    ctx.addLine(to: CGPoint(x: 748, y: 550))
    ctx.closePath()
    ctx.fillPath()

    // Eye.
    ctx.setFillColor(eye)
    ctx.addEllipse(in: CGRect(x: 640, y: 424, width: 52, height: 52))
    ctx.fillPath()

    // Wing: a checkmark — "done" that becomes flight.
    ctx.setStrokeColor(wing)
    ctx.setLineWidth(58)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: 360, y: 588))
    ctx.addLine(to: CGPoint(x: 456, y: 680))
    ctx.addLine(to: CGPoint(x: 612, y: 548))
    ctx.strokePath()

    ctx.restoreGState()
}

func save(_ ctx: CGContext, _ name: String) {
    let image = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    let data = rep.representation(using: .png, properties: [:])!
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(name)
    try! data.write(to: url)
    print("wrote \(url.path)")
}

do {
    let c = context(); drawBackground(c, .light); drawBird(c, .light); save(c, "fledge-icon-1024.png")
}
do {
    let c = context(); drawBackground(c, .dark); drawBird(c, .dark); save(c, "fledge-icon-dark-1024.png")
}
do {
    let c = context(); drawBackground(c, .tinted); drawBird(c, .tinted); save(c, "fledge-icon-tinted-1024.png")
}
do {
    let c = context(); drawBackground(c, .light); save(c, "layer-background.png")
}
do {
    let c = context(); drawBird(c, .light); save(c, "layer-bird.png")
}
