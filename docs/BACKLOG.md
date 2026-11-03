# Relaunch backlog

Spec: https://claude.ai/code/artifact/3570cc79-5f90-4826-9950-d1f0ee305d54 (offline copy: `docs/SPEC.md`)
Estimates are focused-work days (d). Cut order if late is at the bottom. ✅ = done.

## Start here (status as of 2026-11-03)

**Yearling is built** (resolution layer, UI round 2, rename) and **not committed**: everything is in the working tree on
`relaunch/v1`. 1.0 (3) was rejected under 4.3(a), 4.3(b) and 4.2.6; build 4 isn't uploaded yet. Nothing was sent to App
Store Connect. Listing prepared locally: `Design/AppStore/LISTING.md`.

**Next steps (you)**
1. Review and commit the working tree (one commit per area is fine: HabitCore, app, docs, App Store assets).
2. Fill in the **[FILL IN]** parts of `Design/AppStore/review-reply-4.3.md` (beta testing, Shapewright/Torn, WellFit's account).
3. EUIPO/TMview search for "Yearling" (classes 9, 42) by hand; fix the version copyright ("© 2026 HealthyLiving").
4. Device checks (TestFlight): HK-5, HEAD-2, WID-5, IPAD-2, POL-1 (VoiceOver, Increased Contrast), the new resolution screens,
   and the letter / wobble-week notifications (set the device date).
5. Push `relaunch/v1` (publishes the Yearling website), then follow `Design/AppStore/LISTING.md` › "Before uploading":
   `asc.swift iap-rename` → `iap-review` → `metadata` → `screenshots` → `review-notes` → `scripts/release.sh` (build 4,
   already bumped) → `attach-build 4` → reply with the nine answers → submit (RES-12). One app at a time.

**Sent to App Store Connect — 2026-11-03:** IAP store names → "Yearling Pro" (`iap-rename`) + new review screenshot and
note (`iap-review`; all three READY_TO_SUBMIT); name "Yearling: Keep Your Resolution", subtitle, description, keywords,
promo, URLs (`metadata`); 7 iPhone + 7 iPad screenshots; review notes; copyright "© 2026 Bogdan Iliescu"; build 4
uploaded (`release.sh`), VALID and attached to 1.0 (now PREPARE_FOR_SUBMISSION). **Not done:** the reply to the nine questions and the submission itself.

**Pre-submission pass — 2026-11-03:** package tests 188/188 (115 + 67 + 6); Debug and Release builds clean, no warnings;
UI tests 16/16 on iPhone 17 and on iPad Pro 13" (one by-design skip each: the iPad pane test / the iPhone-only audit);
`/tmp/fledge-paywall-review.png` retaken (iPad, shows "Yearling Pro"). Fixed: `Fledge.storekit` names → "Yearling Pro" (the IAP review screenshot comes from
it); 10 orphaned "Fledge" keys removed from `Localizable.xcstrings`; `asc.swift iap-rename` added (store names of the group
and all three products; IDs and reference names stay) and the IAP review note says Yearling; `CURRENT_PROJECT_VERSION` = 4
in both targets. Reviewed: V1 → V2 migration (on-disk test), Kept/graduation path (one entry point), notification budget
(≤ 30 pending of iOS's 64), hold-to-commit with VoiceOver, no `try!`/`fatalError`/debug code outside `#if DEBUG`.

**Ship the next build:** bump `CURRENT_PROJECT_VERSION` in both targets → `scripts/release.sh` → `swift scripts/asc.swift builds` →
`swift scripts/asc.swift attach-build <n>`.

## Code review — 2026-11-02 (xhigh, whole working tree): 15 findings, all fixed
| # | Finding | Fix |
| --- | --- | --- |
| 1 | Onboarding saved a keyword-matched template for a typed resolution ("Learn the cello" → "In 2027 I'm reading more") | Only a picked template is stored (`pickedTemplateID`); keyword prefixes need 5+ letters |
| 2 | `FreshStart.hasLapsed` ignored each habit's start (a habit added yesterday "lapsed"; backfilled Health days counted) | Only habits in the nest for the whole week count (`FreshStart.Habit`) |
| 3 | Header excluded paused habits but Kept counted them | Paused habits count as not flown ("1 of 3 flown") and leave the year map |
| 4 | Deleting the last unflown habit never kept the resolution | `deleteHabit` runs `updateKeptState` |
| 5 | "Missed yesterday" / "First week" hints hid "Ready to fly" | Hints sit above the flight row |
| 6 | Year map treated weekly habits as due every day | `YearMap.Habit.perWeek`: weekly habits only planned on days they were done |
| 7 | Kept showed again for a resolution that was already kept | Shown only when this graduation completed it |
| 8 | Resolution year logic assumed Gregorian dates while `DayKey` used the user's calendar | `Calendar.fledge` (Gregorian, device time zone) is the default everywhere in HabitCore/FledgeUI |
| 9 | A whitespace-only letter looked written but never got its notification | Why/letter stored trimmed; views check trimmed text |
| 10 | Resolution header rebuilt per card; templates JSON decoded on every pass | Built once per Today pass; `ResolutionLibrary` caches the decode |
| 11 | Structural writes reconciled reminders twice (AppRefresh + Health refresh) | One path: Health refresh when it runs, otherwise AppRefresh |
| 12 | Header/year-map construction copied in three views | `ResolutionHeaderModel(resolution:habits:today:)` + `YearMap.Habit(_:)` in FledgeUI |
| 13 | Follow-up modals chained with sleeps | `onDismiss` of the cover/sheet presents Kept / New resolution |
| 14 | `.white` instead of palette colours | `FledgeTheme.Palette.onInk` / `.card` |
| 15 | Demo seed wrote models directly | Seed uses the write API only (resolution first, habits attach) |
Also found while testing: the year grid said "0 days with all of them" because flown habits stayed on the plan (fixed:
`YearMap.Habit.endedOn`); `HabitDetailStats.flightFraction` was dead code (removed); the Add sheet didn't attach habits to
the resolution (fixed in the write API).

## Tests and coverage — 2026-11-02
- HabitCore package: **187 tests** (114 HabitCore, 67 FledgeUI incl. render tests of every shared view in light/dark,
  6 FledgeHealth). Line coverage **96.9 %** (`swift test --enable-code-coverage`, all three bundles). 100 % isn't reachable on
  a Mac: HealthKit observer/reader paths need a device with Health data (~55 lines), and the rest are `?? fallback`
  branches for calendar maths that can't fail. ("More than 100 %" isn't a measurable target.)
- UI tests (`FledgeAppUITests`, 16 tests incl. the resolution card/sheet, first week, fresh start, Kept + letter, new
  resolution, onboarding seal, accessibility audit): **all pass on iPhone 17 (16) and iPad Pro 13" (15; the audit is
  iPhone-only)**, final runs 2026-11-02. App-target line coverage from the UI tests: **83.4 %** (9,302 / 11,157,
  `xcodebuild -enableCodeCoverage YES`). The widget extension shows 2.7 % because WidgetKit renders it outside the tests;
  its views live in FledgeUI and are covered by the render tests there.
- Found by the tests and fixed: after "Smaller steps" (or any goal edit) today stayed "not done" until the next Health sync →
  `updateHabit(…, reevaluating: today)`; the configure screen's new section header failed the Dynamic Type audit → removed.
- App Store screenshots regenerated after the fixes (7 iPhone, 7 iPad).

## Remaining tasks (2026-11-02)
- **You:** commit; nine-answer facts; EUIPO check; copyright; rename IAPs to "Yearling Pro" (and retake the IAP review
  screenshot, `testPaywallShowsPlansForAppReview` → `/tmp/fledge-paywall-review.png`); device checks; upload + build 4 (RES-12).
- **Code (small):** ✅ 2026-11-03 `Fledge.storekit` names say "Yearling Pro". Open: brand book images (`docs/Fledge Brand
  Book.md` is untracked); the iPad screenshot status bar weekday reads one day ahead (simctl quirk).
- **1.1:** UXR-9 on-device suggestions, Watch app, iCloud sync.

## Resolution relaunch — Nov 2 → Nov 20 (proposed 2026-11-01; spec section "Update 2026-11-01")
Concept: *one New Year's resolution → up to three habits, filled in from Apple Health, graduating until the resolution is kept.*
Name **Yearling** (chosen 2026-11-01; brand v3 in `docs/BRAND.md`) (title "Yearling: Keep Your Resolution", subtitle "One resolution. Three habits."); alternatives Fledge
retitled "Fledge: New Year Resolutions", Twelvemonth. Engine and `SlotPolicy.maxActive` = 3 unchanged.
- [~] **RES-0** (P0, 0.5d) ✅ Rejection read (2026-11-01): **4.3(a), 4.3(b) and 4.2.6** (template/app-generation), with nine questions.
  Apple: don't resubmit without significant changes, or reply if it already complies → we resubmit build 4 with the changes and
  answer all nine (draft: `Design/AppStore/review-reply-4.3.md`; fill in beta-testing facts). ✅ US trademark check: no live
  YEARLING mark for software (classes 9/42/41); live marks only for beer (Eagle Rock Brewery) and a children's book series
  (Penguin Random House "Yearling" imprint). To do: EUIPO/TMview check by hand (automated access is blocked); fix the version
  copyright ("© 2026 HealthyLiving" names another project) via `review-contact`.
- [x] **RES-1** ✅ 2026-11-01 (P0, 1d) `SchemaV2` + migration stage: `Resolution` (text, why, letter, year, startedAt, keptAt; defaults, optional
  relationship to habits) and `Habit.cue`. CloudKit rules hold; never reset the store. Tests.
- [x] **RES-2** ✅ (P0, 1.5d) Data + matcher (`Resources/Resolutions/resolutions.json`, `ResolutionLibrary.match`, 7 templates); onboarding step 1 picks or matches one and pre-picks its habits (within the free Health limit). Resolution packs (JSON on the existing pack format): Move more, Sleep better, Calmer mind, Drink more water,
  Read more, Evenings off the phone; each suggests ≤ 3 habits, Health first.
- [x] **RES-3** ✅ (P0, 0.5d) `ResolutionFraming.isAvoidance` + keyword match; onboarding shows the "start, not stop" hint with a one-tap swap. Approach reframe: "stop/no/less/quit …" → suggested "start" version (rule-based, `ResolutionFraming` in HabitCore).
- [x] **RES-4** ✅ (P0, 1d) `Habit.cue`, template cues, onboarding step 3 with a cue menu, cue line on cards, "Plan" section in the habit editor, reminder titles "After lunch: Walk". If-then plan per habit ("After …, I'll …"): set in onboarding and Configure; shown on the card; reminder text.
- [x] **RES-5** ✅ (P0, 1.5d) `FreshStart` + `scheduleFreshStart`; Today `FreshStartCard` (same plan / smaller steps halves goals / not now), once per lapse. Demo: `-FledgeDemoScreen freshstart`. Fresh starts: lapse (≤ 2 of last 7 days met) → card offering a restart next Monday or the 1st, same or
  smaller goal; resolutions can start on any landmark day. No streak-loss UI. `FreshStart` in HabitCore with tests.
- [x] **RES-6** ✅ 2026-11-02 (P1, 1d) Why + letter in onboarding and in the resolution sheet (editable while sealed); `LetterView` opens on 1 December or Kept; a 1 December 9:00 notification (`ReminderPlan.resolutionMoments`) routes to the resolution.
- [x] **RES-7** ✅ 2026-11-02 (P1, 1.5d) Resolution card + `YearStrip`; `ResolutionSheet` (year grid, habits, letter, edit, let go / start next); `KeptView` full-screen cover with a share image (`KeptShareCard`); Flown shelf grouped by resolution (`FlownGroups`); "Make it a resolution" card for habits without one (`NewResolutionSheet`, adopts the nest).
- [x] **RES-8** ✅ 2026-11-02 (P2, 0.5d) Wobble-week notification on the second Friday of January, 10:00, only if the resolution started before it.
- [x] **RES-9** ✅ (P0, 1d) Onboarding: resolution → habits (suggested + head start) → if-then plans → letter (skippable) → Health (only with a Health habit) → reminders → paywall. UI test updated. Device check still to do.
- [~] **RES-10** (P0, 2d) Rename + brand v3. ✅ 2026-11-02: all on-screen text, widgets, Siri, notifications, Health usage
  strings and `CFBundleDisplayName` (app + widget) say Yearling; type names, bundle IDs, App Group, product IDs and the
  StoreKit file stay. To do: Yearling lockup (`render-icon.swift`), brand book images, website (`website/`), `AppLinks`.
- [~] **RES-11** (P0, 1d) Listing. ✅ Prepared locally (not uploaded): `Design/AppStore/LISTING.md`, `metadata.en-US.json`
  (name, subtitle, promo, keywords, description), 7 iPhone + 7 iPad screenshots (demo pinned to Fri 12 Feb 2027,
  `-FledgeDemoToday`), `review-notes.txt`. ✅ `asc.swift metadata` sets `name`; ✅ `asc.swift iap-rename`
  (2026-11-03). To do: run `iap-rename` + `iap-review` (screenshot retaken by the UI tests); fix the copyright.
- [ ] **RES-12** (P0, 0.5d, Nov 20) UI tests on iPhone + iPad, build 4, attach, submit with the products (website flow).
Cut order if late: RES-8 → RES-7 share card → RES-6. Never cut RES-1…5, RES-9…12.

## UI/UX round 2 — Nov 2 → Nov 29 (spec › "UI/UX research, round 2")
- [x] **UXR-1** ✅ 2026-11-02 (P0, 0.5d) Seal the plan: final onboarding card (resolution + habits + cues), press and hold to seal; copy "Commit to my resolution".
- [x] **UXR-2** ✅ 2026-11-02 (P0, 0.5d) First-week row on the resolution card; tap-to-log cards say "First week: 2 minutes counts."
- [x] **UXR-3** ✅ 2026-11-02 (P0, 0.5d) `MissCheck` line on cards + `FreshStartCard` (same plan / smaller steps / not now). Never miss twice: one missed day → calm line on the card; lapse → fresh-start card (RES-5).
- [x] **UXR-4** ✅ 2026-11-02 (P0, 0.5d) "Why" on the resolution card, paywall line names the resolution, reminder titles lead with the cue. Your words: "why" under the resolution on Today; paywall headline names the resolution; reminder text from the cue.
- [x] **UXR-5** ✅ 2026-11-02 (P1, 1d) `YearGrid` (12 × 31, `YearGridModel`) in the resolution sheet, on Kept and in the share image; month totals spoken by VoiceOver.
- [x] **UXR-6** ✅ 2026-11-02 (P1, 0.5d) Reminder titles lead with the cue; reminders are now rebuilt after structural writes too (adding/graduating a habit used to skip it).
- [x] **UXR-7** ✅ 2026-11-02 (P1, 0.5d) `LetterView`: envelope first, then the letter and the reason; Reduce Motion cross-fades.
- [x] **UXR-8** ✅ 2026-11-02 (P1, 0.5d) Strip, first-week dots and grid differ by shape (height, check, half-fill, outline), not colour alone. Increased Contrast on a device: still to check (POL-1).
- [ ] **UXR-9** (1.1, 1d) On-device Foundation Models: approach reframe and cue ideas for typed resolutions; rules stay the fallback.

## UI/UX redesign — Oct 15 → Nov 29 (proposal)
Plan, diagnosis and tickets UX-1…UX-19: `docs/UI-REDESIGN.md` · mockups: `Design/review/redesign-plan.html`.
- [x] **UX-1…UX-19** ✅ All five phases done 2026-10-14 (commits on `relaunch/v1`). Brand v2 "First flight" + new icon: `docs/BRAND.md`.
  Screens per phase in `Design/review/screens/`; App Store images (6 of 8 planned) in `Design/AppStore/` — feeds **REL-2**.
- [x] **IPAD-1** ✅ Native iPad (2026-10-14; changes the spec's "no iPad layouts" non-goal): device family iPhone + iPad, all
  orientations, split Today (nest + detail pane ≥ 700 pt wide), ⌘N / ⌘, / ⌘1–3, hover, readable-width covers, tap-to-log
  fallback when Apple Health isn't available, device-neutral copy, extra-large widget. Concept: `docs/DESIGN.md` §12.
  13" App Store set: `Design/AppStore/iPad/` (`scripts/appstore-screenshots.sh --ipad`).
- [ ] **HEAD-2** Device check for HEAD-1/GRAD-3: Health sheet appears when Configure opens; 30-day values match the Health app;
  backfill shows "Before Fledge" days; force a flown Health habit below 50% (or wait) and confirm one nudge that opens Flown.
- [ ] **IPAD-2** On a real iPad: Health permission and data (synced from iPhone), widgets incl. extra large, Lock Screen widget,
  Control Center control, Stage Manager resizing between split and single column, keyboard shortcuts.

## Differentiation — accepted 2026-10-14 (`docs/POSITIONING.md`); GRAD-3, HEAD-1, GRAD-4 built the same day
Positioning: **the habit tracker that lets go** (graduation is the one claim no competitor makes).
- [x] **GRAD-3** ✅ (P0, 1d) Slip check for flown Health habits: one nudge when `HoldingRate` < 50% / 14 days; none again until ≥ 80%.
  The UI already promises it ("We'll nudge you only if it slips") — never cut; drop the copy instead.
- [x] **HEAD-1** ✅ (P0, 2d) Health head start: last-30-days baseline in setup, suggested goal, "already a habit" check, heatmap pre-filled
  "before Fledge" (graduation counts from the start date). `BaselineModel` in HabitCore with tests.
- [x] **GRAD-4** ✅ (P1, 0.5d) Flight forecast on detail ("On track to fly around 12 Nov").
- [~] **MKT-6** (0.5d) ✅ Docs, captions, screenshot order, and App Store Connect (subtitle, promo text, keywords, description) done 2026-10-14. Still to do: landing page. Messaging: subtitle "Habits that stick, then fly", promo text, screenshot order (graduation first),
  landing headline, creator brief and featuring pitch around graduation.

## Design — Oct 11 → Oct 25 (parallel to M0; mockups run in Claude cloud)
- [x] **DES-0** ✅ Research, marketing theme "Leave the nest", brand palette (contrast-checked), typography, full screen/widget spec → `docs/DESIGN.md`
- [x] **DES-2a** ✅ Icon concept: fledgling with checkmark wing; SVG + 1024 PNG + dark/tinted + two layers (`Design/Icon/`)
- [ ] **DEC-1** Decide minimum iOS 26 (recommended) vs 18; update CORE-2 accordingly (0.1d)
- [ ] **DES-7** HTML mockups of every screen, state and widget → `Design/mockups/` (cloud) — review and comment (0.5d review)
- [ ] **DES-2** Build `Fledge.icon` in Icon Composer from the two layers; check all 6 appearances on device (0.5d)
- [x] **DES-1** ✅ `FledgeTheme` in `FledgeUI` (code-defined light/dark colours, shared with widgets), plus `HabitRing`, `SkyBackground`, `HabitCardModel`/`TodaySummary` (tested); new app icon + accent colour in the asset catalog
- [ ] **DES-3** Bird vector in 4 poses (sitting, ready, flying, sleeping) as SF-Symbol-style SVG/PDF assets (1d, cloud draft + local polish)
- [~] **DES-4** `HabitRing`: ✅ app version with done bounce; `widgetAccentable` comes with WID-2
- [ ] **DES-5** `SkyHeader` time-of-day gradient with Reduce Transparency fallback (0.25d, M1)
- [~] **DES-6** Graduation animation: ✅ first version (matched geometry ring → SF bird, flight, Reduce Motion); polish with custom bird art after DES-3
- [ ] **DES-8** App Store screenshot templates (6, captions from DESIGN.md §9) (cloud draft, final in M4)

## M0 Foundations — Oct 12 → Oct 25
- [x] **ACC-1** ✅ Done 2026-10-11 (App IDs via API, App Group configured, app record created). Apple setup: App Group `group.com.smartapps.TinyHabits` on both IDs (`com.smartapps.TinyHabits`, `com.smartapps.TinyHabits.Widgets`), HealthKit + Background Delivery on the app, app record, name reserved (0.5d)
- [x] **CORE-1** ✅ `HabitCore` package: SchemaV1, DayKey, DayEvaluator, StreakCalculator, GraduationEvaluator, HabitWriter, Essentials pack, 19 tests
- [x] **CORE-2** ✅ HabitCore + FledgeUI linked as local package; Swift 6 language mode; iPhone-only, portrait; display name Fledge; entitlements (App Group, HealthKit background delivery). Deployment target stays 18.6 until DEC-1
- [x] **CORE-3** ✅ App uses `SharedStore.makeContainer()` (App Group store, error screen instead of reset); old models/persistence deleted; write API = `ModelContext` extension shared with `HabitWriter`
  - The app's own `Habit` type conflicts with `HabitCore.Habit` — remove the old models in the same change.
- [x] **CLEAN-1** ✅ Removed Profile (`ProfileView`, `ProfileViewModel`, `ProfileImagePicker`, `ProfileStatsView`), quote overlay (`DailyQuoteOverlay`, `MotivationProvider`, `MotivationBanner`), `SwipeGuard` + swipe gesture, `HealthKitView`, Unsplash URLs (0.5d)
- [x] **NAV-1** ✅ Single Today screen (sky header, 3 slot cards, glass toolbar → Flown/Settings sheets, floating Add) replacing `MainTabView`; basic Add (template grid), Flown and Settings (paused habits) sheets
- [ ] **CI-1** Xcode Cloud or GitHub Actions: build + `swift test` + `FledgeAppUITests` on push (0.5d)

## M1 Core loop — Oct 26 → Nov 8
- [x] **LOOP-1** ✅ Today: 3 slot cards (ring, name, value/target, source badge, flight track / countdown, ready-to-fly), empty slots, tap card → detail
- [x] **LOOP-2** ✅ Add (templates + custom → configure) and Edit share `HabitEditorView`: name, symbol, colour, unit, target stepper, cadence, reminder time (stored; scheduling is NOTIF-1). `HabitDraft` validation tested
- [x] **LOOP-3** ✅ Ring tap done/undo; long-press menu: +increment, Log amount…, Rest day; haptics + symbol bounce
- [x] **LOOP-4** ✅ `RestDayPolicy`: 2 rest days/month for daily habits (enforced in `skip`), unlimited for weekly cadence; shown on detail
- [x] **LOOP-5** ✅ Ready state (gold), graduation cover (ring → bird, flight, Reduce Motion fade), slot freed, Flown grid with Bring back
- [x] **LOOP-6** ✅ Pause/resume/delete with confirmation; `SlotPolicy` enforced in the write API
- [x] **LOOP-7** ✅ Habit detail sheet: hero ring, Fledge progress track (day 30 tick, bird marker), 12-week heatmap (rest days hatched), streak/best/30-day tiles, Edit/Pause/Delete menu. `HeatmapModel`/`HabitDetailStats` tested
- [x] **LOOP-8** ✅ Settings › Day ends at (midnight–5 AM) in App Group defaults (`FledgeSettings`), `DayKey.today()`; Today switches day live

## M2 Auto-completion — Nov 2 → Nov 15
- [x] **HK-1** ✅ `FledgeHealth`: `HealthMetric` mapping (all 8 Essentials sources + protein, distance, flights, workout types) and async `HealthReader` (statistics/sample query descriptors), day windows honour the day-end hour
- [x] **HK-2** ✅ Sleep (main session of the night, 20-min gap merging, naps ignored), stand hours ("stood" count), mindful minutes, workouts (count or minutes, optional activity) — aggregation pure and tested in HabitCore
- [x] **HK-3** ✅ `HealthSync` (MainActor, writes via main context so @Query updates): launch, app active, after adding/editing; `HealthObserver` with background delivery started at launch; syncs today + yesterday; graduates keep syncing; unchanged values don't save
- [x] **HK-4** ✅ Read access requested when adding a Health habit; no samples in 7 days → offer "Track by tapping instead"; card hint "Not seeing data?" (3 days of zeros after 6 PM) opens Health; Settings › Apple Health
- [x] **NOTIF-1** ✅ `ReminderPlan` (tested) + `Reminders.reconcile`: 7 days ahead, today's skipped when done/resting, "N to go" text, rebuilt after every write/sync/activation; permission asked when a reminder is first set. Evening summary moved to SET-1
- [ ] **HK-5** Device test matrix (needs a real iPhone; HealthKit permission sheets can't be automated here):
  - [ ] Add Walk → Health sheet appears once → steps fill the ring within ~1 s of opening the app
  - [ ] Walk 1,000+ steps with the app closed → ring updated on next open (background delivery ≈ hourly for steps)
  - [ ] Deny access → card shows "Not seeing data?" after 3 days at 6 PM; Add shows "No recent data" alert
  - [ ] Sleep habit with Apple Watch → morning value = last night's main session (naps excluded)
  - [ ] Work out 3×/week habit → only workouts count; weekly streak correct
  - [ ] Reminder at 20:00 for an undone habit fires; marking done before 20:00 cancels it
  - [ ] Change "Day ends at" to midnight/5 AM → Today switches day correctly around midnight

## M3 Widgets and intents — Nov 9 → Nov 22
- [x] **INT-1** ✅ `HabitEntity` + string query; Complete, Toggle (widgets), LogProgress, SkipToday, HabitStatus (spoken summary), SetHabitDone (control), Select-habit configuration intents — in `Shared/` (app + widget targets); intent writes mark an external write, reconcile reminders, reload widgets/controls
- [x] **INT-2** ✅ `FledgeShortcuts`: "Mark ‹habit› done in Fledge", "How are my habits in Fledge", "Rest day for ‹habit› in Fledge"; parameters refreshed after structural changes
- [x] **WID-1** ✅ `FledgeWidgetsExtension` target (bundle `com.smartapps.TinyHabits.Widgets`, App Group), `NestSnapshot` (tested) from the shared store, refresh every 15 min and at day end, "Health updated … ago"
- [x] **WID-2** ✅ Small (3 rings as a nest + count), medium (3 rows), large/StandBy; tap-to-log rings are interactive (`ToggleHabitIntent`), Health rings open the app; rings are `widgetAccentable`
- [x] **WID-3** ✅ Lock Screen circular (choose habit), rectangular (3 mini rings + line), inline ("2/3 · Walk 1.8K steps left")
- [x] **WID-4** ✅ Control Center toggle "Mark ‹habit› done" (choose habit; defaults to first tap-to-log habit)

- [ ] **WID-5** Visual check on a device or simulator (needs taps): add each widget size, Lock Screen widgets, the control; tinted/clear Home Screen; tap a ring in a widget → app shows it done on next open; Siri: "How are my habits in Fledge"

## M4 Onboarding, paywall, polish — Nov 16 → Nov 29 (feature freeze Nov 29)
- [x] **ONB-1** ✅ 4 screens: promise (ring fills → bird), pick up to 3 (Pro badge on a 2nd Health habit), connect Health (or "track by tapping"), reminders + widget how-to → paywall (dismissible) → Today. Shown only on first run with an empty nest
- [x] **PAY-1** ✅ `Purchases` (entitlements + `Transaction.updates`), `ProStatus` in App Group, `PaywallView` (SubscriptionStoreView yearly/monthly + lifetime, restore, policies), `Configuration/Fledge.storekit` wired in the shared scheme. DEBUG `-FledgePro`
- [x] **PAY-2** ✅ Gates: 2nd/3rd Health habit (Add + onboarding), medium/large/StandBy and Lock Screen widgets, app icon, CSV export. Changed vs spec: Control Center and Siri stay free (a control can't branch on Pro; dead toggle = bad reviews)
- [x] **SET-1** ✅ Settings: Pro status/manage/restore, day end, notifications + evening summary, Health, app icon (Dawn/Night), paused habits, CSV export, privacy, help & feedback, version
- [~] **POL-1** ✅ Dark mode and AX5 Dynamic Type checked in the simulator; String Catalog added (`Localizable.xcstrings`, Xcode fills it on build). Still to do on device: full VoiceOver pass
- [~] **POL-2** ✅ Dawn + Night app icons (alternate icon). Still to do: Icon Composer `.icon` (DES-2), branded launch screen, feather burst on done
- [ ] **ANA-1** ⏸ Waiting on your decision (TelemetryDeck or none). Anonymous analytics (TelemetryDeck or none): install, onboarding step, habit added (source kind only), completion (by), trial, purchase. Never Health values (0.5d)
- [x] **REV-1** ✅ Review prompt once: after 7 days with something done, or the first graduation

## Beta and release — Nov 23 → Dec 15
- [~] **REL-0** ✅ 2026-10-14 via API (`scripts/asc.swift iap`): group "Fledge Pro" with `.pro.yearly` ($19.99, 7-day free trial in all
  175 territories) and `.pro.monthly` ($2.99), non-consumable `.pro.lifetime` ($39.99); en-US names; available in 175 territories.
  Status 2026-10-14: all three submitted with 1.0 (WAITING_FOR_REVIEW). Still to do: revisit prices after the price decision
- [~] **REL-1** ✅ 2026-10-14: privacy policy (lists every HealthKit type), terms (Apple EULA + subscription terms) and support pages in
  `website/`, published by GitHub Pages; URLs set in the app (`AppLinks`) and in App Store Connect (privacy, support, marketing).
  Status 2026-10-14: **live** at https://iliescub.github.io/tinyhabitsios/ (served from `gh-pages`, updated by the workflow). App Privacy answered by the owner at submission
- [~] **REL-2** ✅ 2026-10-14: description, keywords, promotional text, subtitle and both screenshot sets uploaded via `scripts/asc.swift`
  (order: graduation → Today → head start → Flown → widgets → privacy). Still to do: 15 s preview video; Lock Screen and Siri shots from a device
- [~] **REL-3** ✅ 0.1 (1) uploaded 2026-10-11; **1.0 (2)** uploaded with the API key, VALID and attached to version 1.0 on 2026-10-14
  (redesign, iPad, differentiators). Still to do: review build by Nov 27
- [ ] **REL-4** Public TestFlight Nov 23 for first 100 waitlist users; triage daily (ongoing)
- [~] **REL-5** ✅ 1.0 (3) submitted 2026-10-14 17:44 UTC with the subscription group and all three products (after two withdrawn
  attempts). Still to do: In-app Event "New Year, 3 Habits"; New Year offer. Original plan: final submission Dec 4; In-app Event "New Year, 3 Habits" (Dec 26 → Jan 10); New Year offer (0.5d)
- [ ] **REL-6** Release Dec 15; email waitlist

## Marketing (parallel, ~3 h/week)
- [ ] **MKT-1** (site live on GitHub Pages from `website/`; custom domain later = change `AppLinks.base` + a CNAME) Name decided: **Fledge**. Reserve in App Store Connect, USPTO + EUIPO search, buy fledgehabits.com (or bid on fledge.app), landing page + waitlist by Oct 25
- [ ] **MKT-2** Build-in-public posts, 2/week from Oct 14
- [ ] **MKT-3** Creator list (30) + outreach Nov 15 → Dec 10, free lifetime Pro codes
- [ ] **MKT-4** Apple featuring nomination ~Nov 15
- [ ] **MKT-5** Press kit Dec 1; Product Hunt Jan 5

## 1.1 — Jan 11 → Feb 7
- [ ] Watch app + 3-ring complication · iCloud sync (definitions + done/skipped flags only) · Live Activity for timed habits

## Niche decision — Feb 15, 2027
- [ ] Score candidates (pull, auto share, reach, willingness to pay, competition); ≥18/25 → build the pack JSON and decide in-app pack vs separate target.

## Cut order if behind schedule
1. WID-4 Control Center → 2. WID-3 inline/circular → 3. Workout + daylight sources → 4. LOOP-4 free passes → 5. Graduates shelf polish.
Never cut: auto-completion (HK-1/3), WID-2, PAY-1, ONB-1.
