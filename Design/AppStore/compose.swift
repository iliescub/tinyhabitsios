// Composes App Store screenshots: caption on the dawn sky, the app screen below it.
// iPhone 6.9" = 1320 × 2868; with --ipad, iPad 13" = 2064 × 2752 (docs/DESIGN.md §12).
// Usage: swift Design/AppStore/compose.swift <raw-dir> <out-dir> [--ipad]
// <raw-dir> holds full-resolution simulator PNGs named after the screens in `shots` below
// (scripts/appstore-screenshots.sh captures them). Captions follow docs/DESIGN.md §9.

import AppKit

let args = CommandLine.arguments
let rawDir = URL(fileURLWithPath: args.count > 1 ? args[1] : "/tmp/fledge-appstore-raw")
let outDir = URL(fileURLWithPath: args.count > 2 ? args[2] : "Design/AppStore")

let isPad = args.contains("--ipad")
let size = isPad ? CGSize(width: 2064, height: 2752) : CGSize(width: 1320, height: 2868)
let device = isPad ? "iPad" : "iPhone"
let ink = NSColor(srgbRed: 0x1B / 255.0, green: 0x22 / 255.0, blue: 0x40 / 255.0, alpha: 1)
let ink2 = NSColor(srgbRed: 0x5B / 255.0, green: 0x62 / 255.0, blue: 0x80 / 255.0, alpha: 1)

/// (file, headline, subline)
let shots: [(String, String, String)] = [
    ("graduation", "When a habit sticks,\nit flies.", "Most habit apps want you forever. Fledge lets go after about 66 days."),
    ("today", "Three habits.\nDone for you.", "Fledge fills them in from Apple Health."),
    ("configure", "Starts from\nyour own data.", "Your last 30 days from Apple Health, and a goal you can win."),
    ("flown", "See what stuck.", "Flown habits keep tracking quietly. If one slips, you hear once."),
    ("widgets", "Check in without\nopening the app.", isPad ? "Widgets for the Home Screen and the Lock Screen." : "Widgets for the Home Screen, Lock Screen and StandBy."),
    ("onboarding-health", "No account.\nYour data stays put.", "Health data never leaves your \(device)."),
]

func roundedFont(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    return base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? base
}

func draw(_ text: String, font: NSFont, color: NSColor, in rect: CGRect) {
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    style.lineSpacing = font.pointSize * 0.06
    NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
        .draw(with: rect, options: [.usesLineFragmentOrigin])
}

// Each set captures only some of these screens; number the images that are written, 01, 02, …
var written = 0
for shot in shots {
    let rawURL = rawDir.appendingPathComponent("\(shot.0).png")
    guard let screen = NSImage(contentsOf: rawURL) else { continue }
    written += 1
    let image = NSImage(size: size, flipped: true) { _ in
        // Dawn sky, as on Today.
        NSGradient(colors: [
            NSColor(srgbRed: 0.86, green: 0.91, blue: 1, alpha: 1),
            NSColor(srgbRed: 1, green: 0.89, blue: 0.81, alpha: 1),
            NSColor(srgbRed: 0.97, green: 0.96, blue: 0.95, alpha: 1),
        ])?.draw(in: CGRect(origin: .zero, size: size), angle: 90)

        // iPad: one line of headline (wider canvas), the screen a little lower and much wider.
        let headline = isPad ? shot.1.replacingOccurrences(of: "\n", with: " ") : shot.1
        draw(headline, font: roundedFont(isPad ? 104 : 92, .heavy), color: ink, in: CGRect(x: 90, y: 150, width: size.width - 180, height: 260))
        draw(shot.2, font: roundedFont(isPad ? 48 : 42, .medium), color: ink2, in: CGRect(x: 120, y: isPad ? 300 : 420, width: size.width - 240, height: 120))

        // The screen, with the device's corner radius and a soft shadow.
        let width: CGFloat = isPad ? 1640 : 1000
        let height = width * screen.size.height / screen.size.width
        let frame = CGRect(x: (size.width - width) / 2, y: isPad ? 470 : 610, width: width, height: height)
        let radius: CGFloat = isPad ? 64 : 118
        let path = NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
        shadow.shadowBlurRadius = 60
        shadow.shadowOffset = CGSize(width: 0, height: -20)
        shadow.set()
        NSColor.white.setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        screen.draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        NSGraphicsContext.restoreGraphicsState()
        return true
    }
    guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    // Render at exactly 1320 × 2868 pixels (NSImage may use the screen's backing scale).
    let pixels = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: pixels)
    image.draw(in: CGRect(origin: .zero, size: size))
    NSGraphicsContext.restoreGraphicsState()
    _ = png
    let name = String(format: "%02d-%@.png", written, shot.0)
    try! pixels.representation(using: .png, properties: [:])!.write(to: outDir.appendingPathComponent(name))
    print("wrote \(name)")
}
