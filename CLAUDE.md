# Fledge (relaunch of TinyHabits)

"Three habits. Done for you. Then they fly." — at most 3 active habits, auto-completed from Apple Health where possible,
graduating once they stick. Full product spec and roadmap:
https://claude.ai/code/artifact/3570cc79-5f90-4826-9950-d1f0ee305d54 · offline copy: `docs/SPEC.md` · tickets: `docs/BACKLOG.md`.

Target: App Store release **2026-12-15**, feature freeze 2026-11-29, submit 2026-12-04.

## Layout
- `TinyHabits/` — the app target (display name Fledge).
- `FledgeWidgets/` — widget extension target: widgets, Lock Screen, Control Center control.
- `Shared/` — compiled into BOTH targets: App Intents + `HabitEntity`, `IntentStore`, `Reminders`. Keep it free of app-only code.
- `Packages/HabitCore/` — local package with two products:
  - `HabitCore`: SwiftData `SchemaV1`, `DayKey`, `DayEvaluator`, `StreakCalculator`, `GraduationEvaluator`, write API, packs (JSON).
  - `FledgeUI`: `FledgeTheme` tokens, `HabitRing`, `SkyBackground`, `HabitCardModel`, `TodaySummary` (shared with widgets).
  - `FledgeHealth`: `HealthMetric` (source → HealthKit query), `HealthReader` (read-only daily values), `HealthObserver`
    (observer queries + background delivery). Aggregation math lives in HabitCore (`HealthAggregation`).
- App services: `HealthSync` (started at launch; never in demo mode) and `Reminders` (rebuilds notifications from `ReminderPlan`).
- Planned: Watch app in 1.1.

## Rules
- Product: never more than `SlotPolicy.maxActive` (3) active habits; no paid tier unlocks more.
- All writes go through the HabitCore write API: `ModelContext` extension (`addHabit`, `setDone`, `skip`, `record`, `pause`,
  `resume`, `graduate`, `deleteHabit`) on the main context, or `HabitWriter` (same code) off the main actor.
  In the app, finish every write with `AppRefresh.afterWrite` (widgets, controls, reminders, Siri parameters).
  Writes from other processes (widgets, Siri) go through `IntentStore.write`, which calls `FledgeSettings.markExternalWrite()`;
  the app reopens its container on activation when that marker moved (`AppModel.reloadIfChangedElsewhere`).
- One `DayLog` per habit per `DayKey` ("yyyy-MM-dd", day ends at 3 AM by default). Don't query by `Date` ranges.
- Manual/widget/intent "done" is sticky; HealthKit values never undo it.
- Schema must stay CloudKit-compatible: no `@Attribute(.unique)`, defaults on every property, optional relationships.
  Change the schema only through a new `VersionedSchema` + migration stage. Never reset the store.
- Health data never leaves the device; never put raw Health values in iCloud (App Review 5.1.3(ii)).
- Swift 6 language mode (app default isolation MainActor), `@Observable` view models, iOS 18.6 minimum until DEC-1. Business logic belongs in HabitCore with
  Swift Testing coverage, not in views.

## Design
- UI concept, palette, components and copy: `docs/DESIGN.md` (source of truth); mockups in `Design/mockups/`; icon in `Design/Icon/`.
- One screen (Today) + sheets; no tab bar. iPad (≥ 700 pt wide): the detail opens as a pane beside the nest (`NestLayout`, DESIGN.md §12). Liquid Glass only on the navigation layer (toolbar, floating Add, sheets), never on cards.
- Primary buttons are solid ink (`FledgePrimaryButtonStyle`), not glass; app tint is ink (both from the accessibility audit, DESIGN.md §4).
- Colours from `FledgeTheme`/asset catalog only; brand colours never for body text (use `ink`, `ink2`, `skyText`).
- No guilt UI: no red failure states, no points/coins. Every animation has a Reduce Motion variant; Dynamic Type to AX5.

## Commands
- **Run every long command through the watchdog** (`scripts/watchdog.sh`): it kills the whole process tree on a hard timeout (exit 124)
  or when output stalls (exit 125) and prints the log tail, so a hung build never blocks the session. Don't pass `-quiet` to
  xcodebuild under the watchdog (no output looks like a stall). Full log path is printed at the end.
- Tests (build dir outside Documents, which is iCloud-synced and breaks codesign with xattrs):
  `scripts/watchdog.sh --timeout 600 --idle 180 --name tests -- swift test --package-path Packages/HabitCore --scratch-path /tmp/habitcore-build`
- App: open `TinyHabits.xcodeproj`, scheme `TinyHabits` (app display name "Fledge").
- UI tests (`FledgeAppUITests`: main flows on demo data + Xcode accessibility audit with a documented allowlist); run on iPhone and iPad:
  `scripts/watchdog.sh --timeout 1800 --idle 600 --name ui -- xcodebuild test -project TinyHabits.xcodeproj -scheme TinyHabits -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/fledge-dd -only-testing:FledgeAppUITests`
  (and `name=iPad Pro 13-inch (M5)`). These runs take ~5 min each; run them in the background, not as a blocking command.
- App Store Connect listing via API (key in `~/APIkeys/appstoreconnect`, never printed): `swift scripts/asc.swift status|metadata|screenshots`
  — metadata in `Design/AppStore/metadata.en-US.json`, screenshots from `Design/AppStore/` and `Design/AppStore/iPad/`. Edits the
  editable 1.0 version only; never submits.
- CLI build (DerivedData outside Documents): `scripts/watchdog.sh --timeout 900 --idle 300 --name build -- xcodebuild -project TinyHabits.xcodeproj -scheme TinyHabits -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/fledge-dd build`
- Simulator steps (boot, install, screenshots) also go through the watchdog with `--timeout 180`; shut the simulator down when done (`xcrun simctl shutdown all`).
- Screenshots of every demo screen × light/dark × default/AX3 + contact sheet: `scripts/screenshots.sh [LABEL] [--no-build]`
  → `Design/review/screens/LABEL/index.html` (builds and boots through the watchdog; shuts the simulator down after).
- App Store screenshots (iPhone 1320 × 2868; `--ipad` for the 13" set 2064 × 2752; captions in `Design/AppStore/compose.swift`): `scripts/appstore-screenshots.sh [--no-build] [--ipad]`. iPad screens in the harness: `scripts/screenshots.sh LABEL --device "iPad Pro 13-inch (M5)"`.
- Demo data (DEBUG, in-memory, real data untouched): launch argument `-FledgeDemoData`; add `-FledgeDemoScreen detail|graduation|add|configure|flown|settings|paywall|sharecard|widgets|onboarding[-pick|-health|-headstart|-reminders]` to open a screen or onboarding step (screenshots). `-FledgePro` forces Pro.
- StoreKit testing: the shared scheme uses `Configuration/Fledge.storekit` (run from Xcode; CLI `simctl launch` doesn't load it).
- Pro rules: `ProPolicy` (free = 1 Health habit); widgets read `ProStatus` from the App Group. Never sell more than 3 slots.

## Release (App Store Connect)
- App record: "Fledge: Habit Tracker" (Apple ID 6821628229), bundle IDs `com.smartapps.TinyHabits` + `.Widgets`, App Group `group.com.smartapps.TinyHabits`, team `USASBWPY7T`.
- Signing: **Xcode cloud signing** (automatic). No local distribution certificate — don't create one (it triggers keychain password prompts).
- Before each upload bump `CURRENT_PROJECT_VERSION` in both targets (app + widget must match).
- Archive + upload, signed with the App Store Connect API key (no Xcode account needed): `scripts/release.sh` (run it in the background;
  `--archive` for archive only). Then `swift scripts/asc.swift builds` until the build is VALID, and
  `swift scripts/asc.swift attach-build <number>` to put it on the 1.0 version.
- Or in Xcode: Product › Archive › Distribute App › App Store Connect › Upload.
- In-app purchases (REL-0) were created by `swift scripts/asc.swift iap` (resumable; checks what exists). App Review screenshot +
  note: the UI test `testPaywallShowsPlansForAppReview` (StoreKitTest loads `Fledge.storekit`) writes `/tmp/fledge-paywall-review.png`,
  then `swift scripts/asc.swift iap-review` uploads it to all three products; `iap-status` checks them (READY_TO_SUBMIT).
  First-time products must be submitted together with an app version, and **only the website can do that**: the API refuses
  (`FIRST_SUBSCRIPTION_MUST_BE_SUBMITTED_ON_VERSION`, `FIRST_NON_CONSUMABLE_MUST_BE_SUBMITTED_ON_VERSION`). Select them in the
  version page's "In-App Purchases and Subscriptions" section, then Add for Review. Later products can use `submit-prepare`.
- App Review notes: `Design/AppStore/review-notes.txt` → `swift scripts/asc.swift review-notes` (contact details untouched).
- Submissions: `submission-status` (read-only), `submit-prepare` (draft with the version + products), `submit-send`,
  `submit-cancel` (empties a draft; drafts can't be canceled).
- Review checklist: `swift scripts/asc.swift review-status` (read-only), `review-setup` (category, content rights, age rating, free
  price), `review-contact` (contact + copyright from git-ignored `Configuration/review-contact.json`). `status` also lists review
  submissions and in-app purchase states. 1.0 (2) was submitted 2026-10-14 without the products, then withdrawn; build 3 has the paywall fix.
- Website (privacy, terms, support) lives in `website/`. `.github/workflows/pages.yml` copies it to the `gh-pages` branch on every
  push that changes it; GitHub Pages serves that branch at `https://iliescub.github.io/tinyhabitsios/` (privacy/, terms/, support/).
  Live since 2026-10-14 (Pages enabled on `gh-pages`). Links in the pages are relative; app URLs: `AppLinks.swift`.
- App Store Connect API key: `~/APIkeys/appstoreconnect/AuthKey_YLSMVZ7F79.p8` (issuer ID in the .rtf next to it). Never print files from `~/APIkeys`; reference paths only.
- Required for validation (already set): privacy manifests (`PrivacyInfo.xcprivacy` in app + widget), `ITSAppUsesNonExemptEncryption = NO`, `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription`.
