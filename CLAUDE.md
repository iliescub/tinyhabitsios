# Fledge (relaunch of TinyHabits)

"Three habits. Done for you. Then they fly." — at most 3 active habits, auto-completed from Apple Health where possible,
graduating once they stick. Full product spec and roadmap:
https://claude.ai/code/artifact/3570cc79-5f90-4826-9950-d1f0ee305d54 · offline copy: `docs/SPEC.md` · tickets: `docs/BACKLOG.md`.

Target: App Store release **2026-12-15**, feature freeze 2026-11-29, submit 2026-12-04.

## Layout
- `TinyHabits/` — current SwiftUI app (being migrated; see the gap analysis in the spec).
- `Packages/HabitCore/` — shared logic for app, widgets, intents, Watch: SwiftData `SchemaV1`, `DayKey`,
  `DayEvaluator`, `StreakCalculator`, `GraduationEvaluator`, `HabitWriter` (single writer), packs (JSON).
- Planned targets: `WidgetsExtension` (WidgetKit + ControlWidget), Watch app in 1.1.

## Rules
- Product: never more than `SlotPolicy.maxActive` (3) active habits; no paid tier unlocks more.
- All writes go through `HabitWriter`; after a write reload widgets/controls and run the reminder reconciler.
- One `DayLog` per habit per `DayKey` ("yyyy-MM-dd", day ends at 3 AM by default). Don't query by `Date` ranges.
- Manual/widget/intent "done" is sticky; HealthKit values never undo it.
- Schema must stay CloudKit-compatible: no `@Attribute(.unique)`, defaults on every property, optional relationships.
  Change the schema only through a new `VersionedSchema` + migration stage. Never reset the store.
- Health data never leaves the device; never put raw Health values in iCloud (App Review 5.1.3(ii)).
- Swift 6 strict concurrency, `@Observable` view models, iOS 18 minimum. Business logic belongs in HabitCore with
  Swift Testing coverage, not in views.

## Commands
- Tests (build dir outside Documents, which is iCloud-synced and breaks codesign with xattrs):
  `cd Packages/HabitCore && swift test --scratch-path /tmp/habitcore-build`
- App: open `TinyHabits.xcodeproj`, scheme `TinyHabits`.
