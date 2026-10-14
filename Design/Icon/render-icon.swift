// Renders the Fledge app icon (brand concept "First flight", docs/BRAND.md) at 1024×1024.
// Usage: swift Design/Icon/render-icon.swift <output-dir>
// Outputs:
//   fledge-icon-1024.png, fledge-icon-dark-1024.png, fledge-icon-tinted-1024.png  (asset catalog appearances)
//   layer-background.png, layer-bird.png, layer-wing.png                          (transparent layers for Icon Composer)
//   fledge-mark.png (mark only, transparent), fledge-lockup.png (mark + wordmark, for the press kit)
//   icon-preview-dawn.png, icon-preview-night.png (180 px, Settings › App icon)
// The same geometry lives in fledge-icon.svg.

import AppKit
import CoreGraphics

let size: CGFloat = 1024
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

enum Variant { case dawn, night, tinted }

struct Palette {
    let sky: [CGColor]
    let body: CGColor
    let wing: CGColor
    let beak: CGColor
    let eye: CGColor

    static func of(_ variant: Variant) -> Palette {
        switch variant {
        case .dawn:
            Palette(sky: [rgb(0x4A86FF), rgb(0x8DB6FF), rgb(0xFFC7A1)], body: rgb(0xFFFFFF), wing: rgb(0xFF5F45), beak: rgb(0xFFB13D), eye: rgb(0x1B2240))
        case .night:
            Palette(sky: [rgb(0x121731), rgb(0x1F2550), rgb(0x4A3B6B)], body: rgb(0xF4F5FB), wing: rgb(0xFF8169), beak: rgb(0xFFC15E), eye: rgb(0x1B2240))
        case .tinted:
            Palette(sky: [rgb(0x000000), rgb(0x000000), rgb(0x000000)], body: rgb(0xFFFFFF), wing: rgb(0x8C8C8C), beak: rgb(0xC4C4C4), eye: rgb(0x2E2E2E))
        }
    }
}

// MARK: - Mark geometry
// Drawn in "mark space" (bird centred near 548,470), then centred on the canvas by `placeMark`.
// The bird faces left; its wing is a checkmark whose long stroke breaks out of the body: done becomes flight.
enum Mark {
    static let body = CGPoint(x: 548, y: 470)
    static let radius: CGFloat = 214
    static let eye = CGPoint(x: 430, y: 404)
    static let eyeRadius: CGFloat = 23
    static let beak = [CGPoint(x: 356, y: 404), CGPoint(x: 256, y: 436), CGPoint(x: 356, y: 468)]
    static let wing = [CGPoint(x: 478, y: 522), CGPoint(x: 558, y: 598), CGPoint(x: 810, y: 300)]
    static let wingWidth: CGFloat = 64
    /// Optical centre of the mark's bounding box (beak tip → wing tip, wing tip → body bottom).
    static let centre = CGPoint(x: 549, y: 470)
    static let scale: CGFloat = 1.06
}

func placeMark(_ ctx: CGContext, in canvas: CGFloat = size, scale: CGFloat = Mark.scale) {
    ctx.translateBy(x: canvas / 2, y: canvas / 2)
    ctx.scaleBy(x: scale * canvas / size, y: scale * canvas / size)
    ctx.translateBy(x: -Mark.centre.x, y: -Mark.centre.y)
}

func context(_ side: Int = Int(size), _ width: Int? = nil) -> CGContext {
    let ctx = CGContext(
        data: nil, width: width ?? side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
        space: srgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    // Top-left origin so coordinates match the SVG.
    ctx.translateBy(x: 0, y: CGFloat(side))
    ctx.scaleBy(x: 1, y: -1)
    return ctx
}

func drawSky(_ ctx: CGContext, _ p: Palette, side: CGFloat = size) {
    let gradient = CGGradient(colorsSpace: srgb, colors: p.sky as CFArray, locations: [0, 0.5, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: side / 2, y: 0), end: CGPoint(x: side / 2, y: side), options: [])
}

func drawBird(_ ctx: CGContext, _ p: Palette) {
    ctx.setFillColor(p.body)
    ctx.addEllipse(in: CGRect(x: Mark.body.x - Mark.radius, y: Mark.body.y - Mark.radius, width: Mark.radius * 2, height: Mark.radius * 2))
    ctx.fillPath()

    ctx.setFillColor(p.beak)
    ctx.addLines(between: Mark.beak)
    ctx.closePath()
    ctx.fillPath()

    ctx.setFillColor(p.eye)
    ctx.addEllipse(in: CGRect(x: Mark.eye.x - Mark.eyeRadius, y: Mark.eye.y - Mark.eyeRadius, width: Mark.eyeRadius * 2, height: Mark.eyeRadius * 2))
    ctx.fillPath()
}

func drawWing(_ ctx: CGContext, _ p: Palette) {
    ctx.setStrokeColor(p.wing)
    ctx.setLineWidth(Mark.wingWidth)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.addLines(between: Mark.wing)
    ctx.strokePath()
}

func save(_ ctx: CGContext, _ name: String) {
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(name)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
    print("wrote \(url.path)")
}

func icon(_ variant: Variant, side: Int = Int(size)) -> CGContext {
    let p = Palette.of(variant)
    let c = context(side)
    drawSky(c, p, side: CGFloat(side))
    c.saveGState()
    placeMark(c, in: CGFloat(side))
    drawBird(c, p)
    drawWing(c, p)
    c.restoreGState()
    return c
}

// Full icons.
save(icon(.dawn), "fledge-icon-1024.png")
save(icon(.night), "fledge-icon-dark-1024.png")
save(icon(.tinted), "fledge-icon-tinted-1024.png")
save(icon(.dawn, side: 180), "icon-preview-dawn.png")
save(icon(.night, side: 180), "icon-preview-night.png")

// Layers for Icon Composer: background, bird (body, beak, eye), wing.
do {
    let c = context(); drawSky(c, .of(.dawn)); save(c, "layer-background.png")
}
do {
    let c = context(); placeMark(c); drawBird(c, .of(.dawn)); save(c, "layer-bird.png")
}
do {
    let c = context(); placeMark(c); drawWing(c, .of(.dawn)); save(c, "layer-wing.png")
}

// Mark only, transparent.
do {
    let c = context(); placeMark(c, scale: 1.5); drawBird(c, .of(.dawn)); drawWing(c, .of(.dawn)); save(c, "fledge-mark.png")
}

// Lockup: mark on a sky disc + wordmark in SF Pro Rounded Bold, ink.
do {
    let height = 400, width = 1400
    let c = context(height, width)
    c.saveGState()
    c.translateBy(x: 30, y: 30)
    c.addEllipse(in: CGRect(x: 0, y: 0, width: 340, height: 340))
    c.clip()
    drawSky(c, .of(.dawn), side: 340)
    placeMark(c, in: 340, scale: 0.95)
    drawBird(c, .of(.dawn)); drawWing(c, .of(.dawn))
    c.restoreGState()

    // Text draws in an unflipped context.
    c.saveGState()
    c.translateBy(x: 0, y: CGFloat(height))
    c.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: c, flipped: false)
    let base = NSFont.systemFont(ofSize: 230, weight: .bold)
    let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 230) } ?? base
    let text = NSAttributedString(string: "Fledge", attributes: [
        .font: font,
        .foregroundColor: NSColor(cgColor: rgb(0x1B2240))!,
        .kern: -4,
    ])
    text.draw(at: NSPoint(x: 420, y: 92))
    NSGraphicsContext.restoreGraphicsState()
    c.restoreGState()
    save(c, "fledge-lockup.png")
}
