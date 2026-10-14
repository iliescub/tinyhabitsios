import CoreGraphics
import Testing
import HabitCore
@testable import FledgeUI

@Suite("FledgeBird geometry")
struct FledgeBirdTests {
    @Test func sittingMatchesTheIconMarkBounds() {
        // Same box as Design/Icon/render-icon.swift and the SVG symbol viewBox (236 236 626 468).
        let bounds = FledgeBirdGeometry.bounds(.sitting)
        #expect(abs(bounds.minX - 256) < 1)   // beak tip
        #expect(abs(bounds.maxX - 842) < 1)   // wing tip + half the stroke
        #expect(abs(bounds.minY - 256) < 1)   // top of the body
        #expect(abs(bounds.maxY - 684) < 1)   // bottom of the body
    }

    @Test func wingTipBreaksOutOfTheBody() {
        let parts = FledgeBirdGeometry.parts(.sitting)
        let tip = CGPoint(x: 810, y: 300)
        #expect(parts.wing.contains(tip))
        #expect(!parts.body.contains(tip))
    }

    @Test func sleepingWingStaysFolded() {
        let parts = FledgeBirdGeometry.parts(.sleeping)
        #expect(parts.body.boundingBoxOfPath.contains(parts.wing.boundingBoxOfPath))
    }

    @Test func flyingTurnsTheNoseUp() {
        // Facing left: a nose-up tilt lifts the beak tip above where it sits.
        let sitting = FledgeBirdGeometry.parts(.sitting).beak.boundingBoxOfPath
        let flying = FledgeBirdGeometry.parts(.flying).beak.boundingBoxOfPath
        #expect(flying.minY < sitting.minY)
    }

    @Test func peekingHidesTheBodyBehindTheNest() {
        let parts = FledgeBirdGeometry.parts(.peeking)
        #expect(parts.nest.count == 3)
        #expect(!parts.body.contains(CGPoint(x: 548, y: 660)))   // below the rim
        #expect(parts.body.contains(CGPoint(x: 548, y: 300)))    // above it
    }

    @Test func glyphCutsTheEyeAndSeparatesTheWing() {
        let glyph = FledgeBirdGeometry.glyph(featureScale: 1)
        #expect(!glyph.isEmpty)
        #expect(!glyph.contains(CGPoint(x: 430, y: 404)))   // eye is a hole
        #expect(glyph.contains(CGPoint(x: 650, y: 640)))    // body, away from the wing
        #expect(glyph.contains(CGPoint(x: 558, y: 598)))    // wing joint
        // A point just outside the wing stroke but inside the body falls in the gap.
        #expect(!glyph.contains(CGPoint(x: 558, y: 598 + 32 + 10)))
    }

    @Test func glyphEnlargesEyeAndBeakForSmallSizes() {
        let plain = FledgeBirdGeometry.glyph(featureScale: 1)
        let bold = FledgeBirdGeometry.glyph()
        // A point just outside the normal eye is body in the plain glyph and part of the bigger eye hole in the bold one.
        let nearEye = CGPoint(x: 430 + 27, y: 404)
        #expect(plain.contains(nearEye))
        #expect(!bold.contains(nearEye))
        #expect(bold.boundingBoxOfPath.minX < plain.boundingBoxOfPath.minX)   // longer beak
    }

    @Test func fitKeepsAspectRatioAndCentres() {
        let rect = FledgeBirdGeometry.bounds(.sitting)
        let t = FledgeBirdGeometry.fit(rect, in: CGSize(width: 200, height: 200))
        let fitted = rect.applying(t)
        #expect(abs(fitted.width - 200) < 0.01)
        #expect(abs(fitted.midY - 100) < 0.01)
    }
}

@Suite("HabitRing v2")
struct HabitRingTests {
    @Test func badgesFollowStatus() {
        #expect(HabitRing.badge(for: .done, size: 72, idle: nil) == .done)
        #expect(HabitRing.badge(for: .skipped, size: 72, idle: nil) == .rest)
        #expect(HabitRing.badge(for: .pending, size: 72, idle: nil) == nil)
        #expect(HabitRing.badge(for: .pending, size: 72, idle: .health) == .health)
        #expect(HabitRing.badge(for: .done, size: 72, idle: .health) == .done)
    }

    @Test func smallRingsHaveNoBadgeAndShowACheck() {
        #expect(HabitRing.badge(for: .done, size: 28, idle: nil) == nil)
        #expect(HabitRing.centreSymbol("book.fill", status: .done, size: 28) == "checkmark")
        #expect(HabitRing.centreSymbol("book.fill", status: .done, size: 72) == "book.fill")
        #expect(HabitRing.centreSymbol("book.fill", status: .pending, size: 28) == "book.fill")
    }
}
