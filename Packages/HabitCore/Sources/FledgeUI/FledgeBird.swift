import SwiftUI
import CoreGraphics
#if canImport(UIKit)
import UIKit
#endif

/// The brand mark (docs/BRAND.md): a round fledgling, facing left, whose wing is a checkmark.
/// Geometry is the mark space of `Design/Icon/render-icon.swift`, so the app, widgets and icon draw the same bird.
public enum FledgeBirdGeometry {
    public enum Pose: Sendable, CaseIterable {
        /// The mark itself.
        case sitting
        /// Half hidden behind the three-arc nest: empty slots.
        case peeking
        /// Wing raised further, nose up 12°: graduation. It flies toward the upper left, the way it faces.
        case flying
        /// Eye closed, wing folded inside the body: all done, empty states.
        case sleeping
    }

    static let body = CGPoint(x: 548, y: 470)
    static let radius: CGFloat = 214
    static let eye = CGPoint(x: 430, y: 404)
    static let eyeRadius: CGFloat = 23
    static let beak = [CGPoint(x: 356, y: 404), CGPoint(x: 256, y: 436), CGPoint(x: 356, y: 468)]
    static let wing = [CGPoint(x: 478, y: 522), CGPoint(x: 558, y: 598), CGPoint(x: 810, y: 300)]
    static let raisedWing = [CGPoint(x: 478, y: 522), CGPoint(x: 558, y: 598), CGPoint(x: 846, y: 250)]
    static let foldedWing = [CGPoint(x: 470, y: 548), CGPoint(x: 540, y: 606), CGPoint(x: 690, y: 520)]
    static let wingWidth: CGFloat = 64
    /// Gap between the wing and the body in the one-colour glyph.
    static let glyphGap: CGFloat = 20
    static let nestWidth: CGFloat = 40

    /// Filled outlines of each part, in mark space.
    public struct Parts {
        public var body: CGPath
        public var beak: CGPath
        public var eye: CGPath
        /// Centre line of the wing; `wing` is its filled outline.
        public var wingLine: CGPath
        public var wing: CGPath
        public var nest: [CGPath]

        /// Everything the pose draws, for bounds.
        var all: [CGPath] { [body, beak, eye, wing] + nest }
    }

    public static func parts(_ pose: Pose) -> Parts {
        let bodyPath = CGPath(ellipseIn: CGRect(x: body.x - radius, y: body.y - radius, width: radius * 2, height: radius * 2), transform: nil)

        let beakPath = CGMutablePath()
        beakPath.addLines(between: beak)
        beakPath.closeSubpath()

        let eyePath: CGPath
        if pose == .sleeping {
            let lid = CGMutablePath()
            lid.move(to: CGPoint(x: eye.x - 26, y: eye.y - 4))
            lid.addQuadCurve(to: CGPoint(x: eye.x + 26, y: eye.y - 4), control: CGPoint(x: eye.x, y: eye.y + 22))
            eyePath = lid.copy(strokingWithWidth: 14, lineCap: .round, lineJoin: .round, miterLimit: 10)
        } else {
            eyePath = CGPath(ellipseIn: CGRect(x: eye.x - eyeRadius, y: eye.y - eyeRadius, width: eyeRadius * 2, height: eyeRadius * 2), transform: nil)
        }

        let wingPoints: [CGPoint] = switch pose {
        case .flying: raisedWing
        case .sleeping: foldedWing
        case .sitting, .peeking: wing
        }
        let wingLine = CGMutablePath()
        wingLine.addLines(between: wingPoints)
        let wingPath = wingLine.copy(strokingWithWidth: wingWidth, lineCap: .round, lineJoin: .round, miterLimit: 10)

        var parts = Parts(body: bodyPath, beak: beakPath, eye: eyePath, wingLine: wingLine, wing: wingPath, nest: [])
        if pose == .peeking {
            // Three arcs, the three habits; the bird sits behind the top one, so everything below its rim is hidden.
            let arcs: [(y: CGFloat, half: CGFloat, sag: CGFloat)] = [(560, 300, 80), (628, 240, 60), (688, 170, 40)]
            var nest: [CGPath] = []
            for (y, half, sag) in arcs {
                let arc = CGMutablePath()
                arc.move(to: CGPoint(x: body.x - half, y: y))
                arc.addQuadCurve(to: CGPoint(x: body.x + half, y: y), control: CGPoint(x: body.x, y: y + sag))
                nest.append(arc.copy(strokingWithWidth: nestWidth, lineCap: .round, lineJoin: .round, miterLimit: 10))
            }
            let rim = arcs[0]
            let visible = CGMutablePath()
            visible.move(to: CGPoint(x: 0, y: 0))
            visible.addLine(to: CGPoint(x: 1024, y: 0))
            visible.addLine(to: CGPoint(x: 1024, y: rim.y))
            visible.addLine(to: CGPoint(x: body.x + rim.half, y: rim.y))
            visible.addQuadCurve(to: CGPoint(x: body.x - rim.half, y: rim.y), control: CGPoint(x: body.x, y: rim.y + rim.sag))
            visible.addLine(to: CGPoint(x: 0, y: rim.y))
            visible.closeSubpath()
            parts = Parts(
                body: bodyPath.intersection(visible), beak: beakPath, eye: eyePath, wingLine: wingLine,
                wing: wingPath.intersection(visible), nest: nest
            )
        }
        if pose == .flying {
            var tilt = CGAffineTransform(translationX: body.x, y: body.y).rotated(by: 12 * .pi / 180).translatedBy(x: -body.x, y: -body.y)
            func turn(_ path: CGPath) -> CGPath { path.copy(using: &tilt) ?? path }
            parts = Parts(body: turn(bodyPath), beak: turn(beakPath), eye: turn(eyePath), wingLine: turn(wingLine), wing: turn(wingPath), nest: [])
            // y grows downwards here, so a positive angle turns the nose (left) up.
        }
        return parts
    }

    /// Tight bounding box of a pose in mark space.
    public static func bounds(_ pose: Pose) -> CGRect {
        parts(pose).all.reduce(CGRect.null) { $0.union($1.boundingBoxOfPath) }
    }

    /// Bounding box of the one-colour glyph, whose enlarged beak reaches further than the mark.
    public static func glyphBounds(_ pose: Pose) -> CGRect {
        glyph(pose).boundingBoxOfPath
    }

    /// One-colour silhouette: the body with the wing cut out by a thin gap, the wing on top, the eye as a hole.
    /// Reads at 16 px and takes any foreground style (template images, tinted widgets, menus).
    /// The eye and beak are enlarged by `featureScale` so they survive toolbar and menu sizes.
    public static func glyph(_ pose: Pose = .sitting, featureScale: CGFloat = 1.35) -> CGPath {
        var p = parts(pose)
        if featureScale != 1 {
            p.eye = scaled(p.eye, by: featureScale)
            // Grow the beak about its back edge so it stays attached to the body.
            let box = p.beak.boundingBoxOfPath
            var t = CGAffineTransform(translationX: box.maxX, y: box.midY)
                .scaledBy(x: featureScale, y: featureScale)
                .translatedBy(x: -box.maxX, y: -box.midY)
            p.beak = p.beak.copy(using: &t) ?? p.beak
        }
        let gap = p.wingLine.copy(strokingWithWidth: wingWidth + glyphGap * 2, lineCap: .round, lineJoin: .round, miterLimit: 10)
        var shape = p.body.subtracting(gap).union(p.wing).union(p.beak)
        for arc in p.nest {
            let arcGap = arc.copy(strokingWithWidth: glyphGap * 2, lineCap: .round, lineJoin: .round, miterLimit: 10)
            shape = shape.subtracting(arcGap).union(arc)
        }
        return shape.subtracting(p.eye)
    }

    static func scaled(_ path: CGPath, by factor: CGFloat) -> CGPath {
        let box = path.boundingBoxOfPath
        var t = CGAffineTransform(translationX: box.midX, y: box.midY).scaledBy(x: factor, y: factor).translatedBy(x: -box.midX, y: -box.midY)
        return path.copy(using: &t) ?? path
    }

    /// Transform that fits `rect` (mark space) into `size`, centred, keeping the aspect ratio.
    static func fit(_ rect: CGRect, in size: CGSize) -> CGAffineTransform {
        let scale = min(size.width / rect.width, size.height / rect.height)
        let dx = (size.width - rect.width * scale) / 2 - rect.minX * scale
        let dy = (size.height - rect.height * scale) / 2 - rect.minY * scale
        return CGAffineTransform(translationX: dx, y: dy).scaledBy(x: scale, y: scale)
    }
}

/// The Fledgling, drawn in code. Decorative: hidden from VoiceOver unless the caller labels it.
///
///     FledgeBird()                                   // white bird for sky backgrounds
///     FledgeBird(.flying, style: .tinted(color))     // a graduate in its habit colour
///     FledgeBird(.peeking, style: .glyph)            // one colour; uses foregroundStyle
public struct FledgeBird: View {
    public enum Style: Sendable {
        /// White body, dawn wing, gold beak, ink eye: on the sky or dark backgrounds.
        case brand
        /// The silhouette in a habit colour (wing separated by a gap, so its tip still shows on white cards),
        /// with the gold beak and ink eye: on cards, the Flown shelf, graduation.
        case tinted(Color)
        /// One colour from the foreground style.
        case glyph
    }

    public let pose: FledgeBirdGeometry.Pose
    public let style: Style

    public init(_ pose: FledgeBirdGeometry.Pose = .sitting, style: Style = .brand) {
        self.pose = pose
        self.style = style
    }

    public var body: some View {
        let bounds: CGRect = if case .glyph = style {
            FledgeBirdGeometry.glyphBounds(pose)
        } else {
            FledgeBirdGeometry.bounds(pose)
        }
        Canvas { context, size in
            let transform = FledgeBirdGeometry.fit(bounds, in: size)
            func path(_ cgPath: CGPath) -> Path { Path(cgPath).applying(transform) }

            let parts = FledgeBirdGeometry.parts(pose)
            switch style {
            case .glyph:
                context.fill(path(FledgeBirdGeometry.glyph(pose)), with: .foreground)
            case .tinted(let color):
                context.fill(path(FledgeBirdGeometry.glyph(pose, featureScale: 1)), with: .color(color))
                context.fill(path(parts.beak), with: .color(FledgeTheme.Palette.beak))
                context.fill(path(parts.eye), with: .color(FledgeTheme.Palette.birdEye))
            case .brand:
                context.fill(path(parts.body), with: .color(.white))
                context.fill(path(parts.beak), with: .color(FledgeTheme.Palette.beak))
                context.fill(path(parts.eye), with: .color(FledgeTheme.Palette.birdEye))
                context.fill(path(parts.wing), with: .color(FledgeTheme.Palette.dawn))
                for arc in parts.nest {
                    context.fill(path(arc), with: .color(FledgeTheme.Palette.ink2))
                }
            }
        }
        .aspectRatio(bounds.width / bounds.height, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// The one-colour glyph as a `Shape`, for masks and custom fills.
public struct FledgeGlyphShape: Shape {
    public var pose: FledgeBirdGeometry.Pose

    public init(_ pose: FledgeBirdGeometry.Pose = .sitting) {
        self.pose = pose
    }

    public func path(in rect: CGRect) -> Path {
        let transform = FledgeBirdGeometry.fit(FledgeBirdGeometry.glyphBounds(pose), in: rect.size)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY))
        return Path(FledgeBirdGeometry.glyph(pose)).applying(transform)
    }
}

#if canImport(UIKit)
extension Image {
    /// The glyph as a template image, for places that only take an `Image`: menus, toolbar labels, Lock Screen widgets.
    /// System surfaces that need an SF Symbol name (App Shortcuts, Control Center) keep `bird`.
    public static func fledgeGlyph(height: CGFloat = 18, pose: FledgeBirdGeometry.Pose = .sitting) -> Image {
        let bounds = FledgeBirdGeometry.glyphBounds(pose)
        let size = CGSize(width: (height * bounds.width / bounds.height).rounded(.up), height: height)
        let image = UIGraphicsImageRenderer(size: size).image { renderer in
            let ctx = renderer.cgContext
            ctx.concatenate(FledgeBirdGeometry.fit(bounds, in: size))
            ctx.addPath(FledgeBirdGeometry.glyph(pose))
            ctx.setFillColor(UIColor.black.cgColor)
            ctx.fillPath()
        }
        return Image(uiImage: image.withRenderingMode(.alwaysTemplate)).renderingMode(.template)
    }
}
#endif
