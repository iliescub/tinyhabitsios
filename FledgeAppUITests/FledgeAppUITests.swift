import XCTest
import StoreKitTest

/// End-to-end checks of the main flows on demo data (`-FledgeDemoData`: an in-memory store, real data untouched),
/// plus Xcode's accessibility audit on every main screen. Run on iPhone and iPad (see CLAUDE.md › Commands).
final class FledgeAppUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @discardableResult
    private func launch(_ screen: String? = nil, on day: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FledgeDemoData"] + (screen.map { ["-FledgeDemoScreen", $0] } ?? [])
            + (day.map { ["-FledgeDemoToday", $0] } ?? [])
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, labelContains text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    // MARK: - Today

    func testTodayShowsTheNest() {
        let app = launch()
        XCTAssertTrue(element(app, labelContains: "1 of 3 done").waitForExistence(timeout: 10))
        for name in ["Walk,", "Read,", "Meditate,"] {
            XCTAssertTrue(element(app, labelContains: name).exists, "card \(name) is missing")
        }
        XCTAssertTrue(element(app, labelContains: "have flown").exists, "Flown preview row is missing")
        XCTAssertTrue(app.buttons["Settings"].exists)
    }

    func testDetailRingChecksInAndUndoes() {
        let app = launch(isPad ? nil : "detail-2")   // Read: done today
        if isPad { element(app, labelContains: "Read,").tap() }
        let undo = app.buttons["Undo done"]
        XCTAssertTrue(undo.waitForExistence(timeout: 10))
        undo.tap()
        XCTAssertTrue(app.buttons["Mark done"].waitForExistence(timeout: 5))
        app.buttons["Mark done"].tap()
        XCTAssertTrue(app.buttons["Undo done"].waitForExistence(timeout: 5))
    }

    func testDetailShowsJourneyAndForecast() {
        let app = launch(isPad ? nil : "detail-2")
        if isPad { element(app, labelContains: "Read,").tap() }
        XCTAssertTrue(app.staticTexts["Journey to fly"].waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, labelContains: "fly around").exists, "flight forecast (GRAD-4) is missing")
        XCTAssertTrue(app.staticTexts["Last 12 weeks"].exists)
    }

    // MARK: - Add and head start (HEAD-1)

    func testConfigureShowsHeadStartAndAppliesTheSuggestion() {
        let app = launch("configure")
        XCTAssertTrue(app.staticTexts["Your last 30 days"].waitForExistence(timeout: 10) || element(app, labelContains: "Your last 30 days").exists)
        let aim = element(app, labelContains: "Aim for")
        XCTAssertTrue(aim.waitForExistence(timeout: 5), "head start suggestion is missing")
        aim.tap()
        // The preview card shows the new goal ("… / 35 min").
        XCTAssertTrue(element(app, labelContains: "/ 35 min").waitForExistence(timeout: 5), "suggested goal wasn't applied")
        XCTAssertTrue(app.buttons["Add to nest"].exists)
    }

    // MARK: - Flown, graduation, settings

    func testFlownShelfOffersToBringAHabitBack() {
        let app = launch("flown")
        XCTAssertTrue(app.staticTexts["2 habits flew"].waitForExistence(timeout: 10))
        let water = element(app, labelContains: "Drink water")
        XCTAssertTrue(water.exists)
        XCTAssertTrue(element(app, labelContains: "holding").exists, "holding rate is missing")
        water.tap()
        XCTAssertTrue(app.buttons["Bring back"].waitForExistence(timeout: 5))
    }

    func testGraduationLetsTheHabitFly() {
        let app = launch("graduation")
        XCTAssertTrue(element(app, labelContains: "is ready to fly").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, labelContains: "Share").exists, "share card button is missing")
        // On iPad the detail pane behind the cover has its own "Let it fly"; tap the one on the cover.
        let fly = app.buttons.matching(identifier: "Let it fly").allElementsBoundByIndex.last { $0.isHittable }
        XCTAssertNotNil(fly)
        fly?.tap()
        // Back on Today with Walk gone from the nest and on the shelf.
        XCTAssertTrue(element(app, labelContains: "Walk flew").waitForExistence(timeout: 10)
                      || element(app, labelContains: "have flown").waitForExistence(timeout: 2))
        XCTAssertFalse(element(app, labelContains: "Walk,").exists)
    }

    func testSettingsOpens() {
        let app = launch("settings")
        XCTAssertTrue(element(app, labelContains: "Yearling Pro").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, labelContains: "Day ends at").exists)
        // Restore lives in About at the bottom; rows off screen don't exist until scrolled to.
        let restore = element(app, labelContains: "Restore purchases")
        for _ in 0..<6 where !restore.exists { app.swipeUp() }
        XCTAssertTrue(restore.exists)
    }

    // MARK: - Resolution (RES-5…RES-9, UXR-1…UXR-5); demo day pinned to Friday 12 Feb 2027

    func testResolutionCardOpensTheYear() {
        let app = launch(on: "2027-02-12")
        let card = element(app, labelContains: "In 2027 I'm feeling calmer")
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, labelContains: "Day 43 of 365").exists)
        XCTAssertTrue(element(app, labelContains: "After lunch").exists, "if-then cue missing on the Walk card")
        card.tap()
        XCTAssertTrue(element(app, labelContains: "Your 2027:").waitForExistence(timeout: 5), "year grid missing")
        XCTAssertTrue(element(app, labelContains: "Sealed until 1 December").exists)
        XCTAssertTrue(app.buttons["Let this resolution go"].exists)
        app.buttons["Edit"].tap()
        XCTAssertTrue(app.navigationBars["Edit resolution"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        app.buttons["Done"].firstMatch.tap()
    }

    func testFirstWeekRow() {
        let app = launch("firstweek", on: "2027-02-12")
        XCTAssertTrue(element(app, labelContains: "First week · day 3 of 7").waitForExistence(timeout: 10))
    }

    func testFreshStartSmallerSteps() {
        let app = launch("freshstart", on: "2027-02-12")
        let smaller = app.buttons["Smaller steps"]
        XCTAssertTrue(smaller.waitForExistence(timeout: 10), "fresh-start card missing after a quiet week")
        XCTAssertTrue(element(app, labelContains: "is a fresh start").exists)
        smaller.tap()
        XCTAssertFalse(smaller.waitForExistence(timeout: 2), "the offer should go away once a plan is picked")
        // Halved to 3,000 steps: the 6,000 goal is gone, and today's 4,210 steps are re-checked against it.
        let walk = element(app, labelContains: "Walk,")
        XCTAssertTrue(walk.waitForExistence(timeout: 5))
        // Any grouping separator ("3,000", "3.000", "3 000"): compare digits only.
        let digits = walk.label.filter(\.isNumber)
        XCTAssertFalse(digits.contains("6000"), "Walk's goal should be halved: \(walk.label)")
        XCTAssertTrue(walk.label.contains("Done") || digits.contains("3000"), "unexpected Walk card: \(walk.label)")
    }

    func testKeptOpensTheLetter() {
        let app = launch("kept", on: "2027-02-12")
        XCTAssertTrue(element(app, labelContains: "Every habit flew").waitForExistence(timeout: 10))
        app.buttons["Open your letter"].tap()
        app.buttons["Open it"].tap()
        XCTAssertTrue(element(app, labelContains: "I hope the walks stuck").waitForExistence(timeout: 5))
        app.buttons["Close"].tap()
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(element(app, labelContains: "Kept · every habit flew").waitForExistence(timeout: 5))
    }

    func testNewResolutionAdoptsTheNest() {
        let app = launch("newresolution", on: "2027-02-12")
        XCTAssertTrue(app.navigationBars["New resolution"].waitForExistence(timeout: 10))
        app.buttons["Sleep better"].tap()
        app.buttons["Start"].tap()
        XCTAssertTrue(element(app, labelContains: "In 2027 I'm sleeping better").waitForExistence(timeout: 5))
    }

    // MARK: - Onboarding with head start, then the paywall

    func testOnboardingFlow() {
        let app = launch("onboarding")
        // RES-9: resolution → habits → if-then plans → letter → Health → reminders.
        XCTAssertTrue(element(app, labelContains: "resolution").firstMatch.waitForExistence(timeout: 5))
        element(app, labelContains: "Sleep better").firstMatch.tap()
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Your habits"].waitForExistence(timeout: 5))
        element(app, labelContains: "Read").firstMatch.tap()
        XCTAssertTrue(element(app, labelContains: "2 of 3 chosen").exists || element(app, labelContains: "2/3").exists)
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["When will you do it?"].waitForExistence(timeout: 5))
        let sleepCue = app.textFields["When you'll do Sleep"]
        XCTAssertEqual(sleepCue.value as? String, "When my alarm for bed goes off", "template cue missing")
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["A note to December"].waitForExistence(timeout: 5))
        app.buttons["Skip for now"].tap()
        XCTAssertTrue(app.staticTexts["Connect Apple Health"].waitForExistence(timeout: 5))
        app.buttons["Connect"].tap()
        XCTAssertTrue(element(app, labelContains: "Your head start").waitForExistence(timeout: 10)
                      || element(app, labelContains: "YOUR HEAD START").exists, "head start (HEAD-1) is missing in onboarding")
        app.buttons["Continue"].tap()
        XCTAssertTrue(element(app, labelContains: "Check in without opening the app").waitForExistence(timeout: 5))
        app.buttons["Continue"].tap()
        // UXR-1: the plan on one card, then press and hold to commit.
        XCTAssertTrue(app.staticTexts["Your plan"].waitForExistence(timeout: 5))
        element(app, labelContains: "Commit to my resolution").firstMatch.press(forDuration: 1.8)
        // Paywall: products can't load outside Xcode's StoreKit configuration, so the offline state shows.
        let close = app.buttons["Close"]
        XCTAssertTrue(close.waitForExistence(timeout: 15), "paywall didn't open")
        XCTAssertTrue(element(app, labelContains: "Let all three fill in").exists)
        close.tap()
        XCTAssertTrue(element(app, labelContains: "of 3 done").waitForExistence(timeout: 10), "Today didn't open after onboarding")
    }

    // MARK: - App Review screenshot of the paywall (REL-0)

    /// Loads `Fledge.storekit` with StoreKitTest so the paywall shows the real plans and prices, then saves a screenshot
    /// (attachment "paywall-review") for the App Review screenshot of each in-app purchase.
    func testPaywallShowsPlansForAppReview() throws {
        let session = try SKTestSession(configurationFileNamed: "Fledge")
        session.disableDialogs = true
        session.clearTransactions()
        let app = launch("paywall")
        XCTAssertTrue(element(app, labelContains: "Let all three fill in").waitForExistence(timeout: 15))
        XCTAssertTrue(element(app, labelContains: "19.99").waitForExistence(timeout: 20), "yearly plan didn't load")
        XCTAssertTrue(element(app, labelContains: "2.99").exists, "monthly plan is missing")
        sleep(2)
        let screenshot = XCUIScreen.main.screenshot()
        // On the simulator the runner can write to the Mac's /tmp, so the release scripts can pick the file up directly.
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/fledge-paywall-review.png"))
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "paywall-review"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - iPad

    func testIPadOpensTheDetailBesideTheNest() throws {
        try XCTSkipUnless(isPad, "iPad only")
        let app = launch()
        XCTAssertTrue(element(app, labelContains: "1 of 3 done").waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Journey to fly"].waitForExistence(timeout: 5), "detail pane is missing")
        element(app, labelContains: "Meditate,").tap()
        XCTAssertTrue(element(app, labelContains: "Rest day").exists)
    }

    // MARK: - Accessibility audit

    /// Collects audit issues from the handler (which Swift 6 sends across isolation, so it can't capture a `var`).
    private final class IssueLog: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [String] = []
        func add(_ item: String) { lock.withLock { items.append(item) } }
        var all: [String] { lock.withLock { items } }
    }

    /// Issues checked by hand and accepted, so any *new* issue still fails the test (docs/UI-REDESIGN.md, UX-18).
    /// Every entry was verified against the token contrast table and the AX5 screenshots.
    private static let accepted: [(screen: String?, label: String?, kind: String, reason: String)] = [
        (nil, "Done", "Contrast", "System toolbar button on Liquid Glass; fails in any tint, ink text is 14 : 1"),
        (nil, "Done", "Dynamic Type", "System toolbar button; text size is set by the system"),
        ("flown", "They keep tracking quietly. We'll nudge you only if one slips.", "Contrast", "Ink on the sky (14 : 1); measured under the navigation bar's scroll-edge effect"),
        ("onboarding-pick", nil, "Contrast", "Rows and the solid ink Continue button (15 : 1) measure low while the step transition settles"),
        ("onboarding-pick", nil, "Text clipped", "Title, subtitle and the resolution eyebrow wrap in full at default and AX3 (screenshots, RES-9); measured while the step transition settles"),
        ("graduation", "Keep it in the nest", "Contrast", "Ink on near-white (≈ 14 : 1, screenshot); measured while the bird animates"),
        ("graduation", "Share", "Contrast", "Ink on near-white (≈ 14 : 1, screenshot); measured while the bird animates"),
        ("configure", "Aim for 35 min", "Text clipped", "Renders in full at default and AX5 sizes (screenshots)"),
        ("settings", "Evening summary", "Text clipped", "Renders in full at default and AX5 sizes (screenshots)"),
        ("settings", nil, "Dynamic Type font sizes are unsupported", "No element; system list chrome"),
    ]

    /// Advisory results that aren't failures: "partially" scaling text (checked at AX5) and contrast that "nearly passed".
    private static func isAdvisory(_ description: String) -> Bool {
        description.contains("partially unsupported") || description.contains("nearly passed")
    }

    func testAccessibilityAudit() throws {
        // On iPad, sheets are form sheets over the dimmed split view and the audit measures that dimmed background
        // (heatmap letters, the pane's own buttons, "no element" issues). iPad gets the VoiceOver pass on a device (IPAD-2).
        try XCTSkipIf(isPad, "audit runs on iPhone; iPad modals expose the dimmed background to the audit")
        let log = IssueLog()
        for screen in [nil, "detail", "configure", "flown", "settings", "onboarding-pick", "graduation"] {
            let app = launch(screen)
            sleep(3)
            let name = screen ?? "today"
            try app.performAccessibilityAudit { issue in
                // Collect every issue that isn't advisory or accepted, then fail once with the full list.
                let description = issue.compactDescription
                let label = issue.element?.label
                let accepted = Self.accepted.contains { entry in
                    (entry.screen == nil || entry.screen == name)
                        && (entry.label == nil || entry.label == label)
                        && description.contains(entry.kind)
                }
                if !Self.isAdvisory(description) && !accepted {
                    let element = issue.element.map { "\($0.elementType.rawValue) '\($0.label)'" } ?? "no element"
                    log.add("\(name): \(description) – \(element)")
                }
                return true
            }
            app.terminate()
        }
        XCTAssertTrue(log.all.isEmpty, "Accessibility audit:\n" + log.all.joined(separator: "\n"))
    }
}
