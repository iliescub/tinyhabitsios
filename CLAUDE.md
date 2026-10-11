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
- One screen (Today) + sheets; no tab bar. Liquid Glass only on the navigation layer (toolbar, floating Add, sheets), never on cards.
- Colours from `FledgeTheme`/asset catalog only; brand colours never for body text (use `ink`, `ink2`, `skyText`).
- No guilt UI: no red failure states, no points/coins. Every animation has a Reduce Motion variant; Dynamic Type to AX5.

## Commands
- Tests (build dir outside Documents, which is iCloud-synced and breaks codesign with xattrs):
  `cd Packages/HabitCore && swift test --scratch-path /tmp/habitcore-build`
- App: open `TinyHabits.xcodeproj`, scheme `TinyHabits` (app display name "Fledge").
- CLI build (DerivedData outside Documents): `xcodebuild -project TinyHabits.xcodeproj -scheme TinyHabits -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/fledge-dd build`
- Demo data (DEBUG, in-memory, real data untouched): launch argument `-FledgeDemoData`; add `-FledgeDemoScreen detail|graduation|add|flown|settings|paywall|onboarding` to open a screen (screenshots). `-FledgePro` forces Pro.
- StoreKit testing: the shared scheme uses `Configuration/Fledge.storekit` (run from Xcode; CLI `simctl launch` doesn't load it).
- Pro rules: `ProPolicy` (free = 1 Health habit); widgets read `ProStatus` from the App Group. Never sell more than 3 slots.
