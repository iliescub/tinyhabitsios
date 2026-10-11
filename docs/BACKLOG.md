# Relaunch backlog

Spec: https://claude.ai/code/artifact/3570cc79-5f90-4826-9950-d1f0ee305d54 (offline copy: `docs/SPEC.md`)
Estimates are focused-work days (d). Cut order if late is at the bottom. ✅ = done.

## Start here (status as of 2026-10-11)
**Decided:** name **Fledge** · positioning: max 3 habits, auto-completed from Apple Health, graduation (Option A) · niche packs (Option B) decided 2027-02-15 · release 2026-12-15.
**Done:** spec + roadmap (link above, offline copy in `docs/SPEC.md`) · `CLAUDE.md` · this backlog · `Packages/HabitCore` (19 tests passing) · `.gitignore`.
**M2 status (2026-10-11):** Apple Health auto-completion (8 sources, background delivery) and reminders done in code; 54 package tests pass; device verification is HK-5 (yours, checklist below).
**M1 status (2026-10-11):** core loop complete — add/edit, check-in, amounts, rest days, detail + heatmap, graduation, Flown, day-end setting. 42 package tests pass. Screens can be opened directly in DEBUG with `-FledgeDemoData -FledgeDemoScreen detail|graduation|add|flown|settings`.
**M0 status (2026-10-11):** app runs on HabitCore/FledgeUI with the new Today screen; 33 package tests pass; debug launch argument `-FledgeDemoData` shows sample habits from an in-memory store. Remaining in M0: CI-1, ACC-1 (yours). HealthKit code was removed and is rewritten in M2 (old sleep-session logic: `git show a43acee:TinyHabits/Services/HealthKitManager.swift`).
**Design:** brand + full UI concept in `docs/DESIGN.md`, icon in `Design/Icon/` (2026-10-11). HTML mockups: cloud session → `Design/mockups/`.
**Open decisions:** DEC-1 minimum iOS 26 (recommended in DESIGN.md §4) · prices ($19.99/yr, $39.99 lifetime proposed) · analytics (TelemetryDeck or none) · iPhone-only + English-only assumed.

**Next session, in order:**
1. Commit or stash the current changes on `main`, then `git checkout -b relaunch/v1` and commit the relaunch scaffolding.
2. CORE-2 → CORE-3 → CLEAN-1 → NAV-1 (M0 below). Run the tests after each step.
3. In parallel (you): ACC-1 and MKT-1 — App Store Connect record for "Fledge", trademark search, domain, App Group + HealthKit capabilities.

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
- [ ] **ACC-1** Apple setup: App Group, HealthKit + Background Delivery, app record, name reserved (0.5d)
- [x] **CORE-1** ✅ `HabitCore` package: SchemaV1, DayKey, DayEvaluator, StreakCalculator, GraduationEvaluator, HabitWriter, Essentials pack, 19 tests
- [x] **CORE-2** ✅ HabitCore + FledgeUI linked as local package; Swift 6 language mode; iPhone-only, portrait; display name Fledge; entitlements (App Group, HealthKit background delivery). Deployment target stays 18.6 until DEC-1
- [x] **CORE-3** ✅ App uses `SharedStore.makeContainer()` (App Group store, error screen instead of reset); old models/persistence deleted; write API = `ModelContext` extension shared with `HabitWriter`
  - The app's own `Habit` type conflicts with `HabitCore.Habit` — remove the old models in the same change.
- [x] **CLEAN-1** ✅ Removed Profile (`ProfileView`, `ProfileViewModel`, `ProfileImagePicker`, `ProfileStatsView`), quote overlay (`DailyQuoteOverlay`, `MotivationProvider`, `MotivationBanner`), `SwipeGuard` + swipe gesture, `HealthKitView`, Unsplash URLs (0.5d)
- [x] **NAV-1** ✅ Single Today screen (sky header, 3 slot cards, glass toolbar → Flown/Settings sheets, floating Add) replacing `MainTabView`; basic Add (template grid), Flown and Settings (paused habits) sheets
- [ ] **CI-1** Xcode Cloud or GitHub Actions: build + `swift test` on push (0.5d)

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
- [ ] **INT-1** `HabitEntity` (AppEntity) + query; `CompleteHabitIntent`, `LogProgressIntent`, `SkipTodayIntent`, `HabitStatusIntent` (1.5d)
- [ ] **INT-2** `AppShortcutsProvider` phrases (0.5d)
- [ ] **WID-1** Widget extension target, shared store, timeline provider with "updated X min ago" (1d)
- [ ] **WID-2** Small + medium widgets, interactive buttons for manual habits (1.5d)
- [ ] **WID-3** Lock Screen: circular (configurable habit), rectangular, inline; StandBy (1d)
- [ ] **WID-4** Control Center `ControlWidget` "Mark [habit] done" (0.5d)

## M4 Onboarding, paywall, polish — Nov 16 → Nov 29 (feature freeze Nov 29)
- [ ] **ONB-1** 4-screen onboarding: promise → pick ≤3 → Health → reminders + widget demo (2d)
- [ ] **PAY-1** StoreKit 2 products + `.storekit` config; `SubscriptionStoreView` paywall; `ProStatus` cached in App Group for widgets (1.5d)
- [ ] **PAY-2** Gates: 2nd/3rd auto habit, Pro widgets, Lock Screen, Control, icons, export (0.5d)
- [ ] **SET-1** Settings: appearance, app icons, ~~day-end hour~~ ✅, ~~Health/notification status~~ ✅, evening summary notification, export CSV, privacy, restore purchases, contact (1d)
- [ ] **POL-1** Accessibility pass (VoiceOver labels on rings, Dynamic Type), dark mode, localization-ready strings (1d)
- [ ] **POL-2** App icon, launch screen, celebration animation polish (1d)
- [ ] **ANA-1** Anonymous analytics (TelemetryDeck or none): install, onboarding step, habit added (source kind only), completion (by), trial, purchase. Never Health values (0.5d)
- [ ] **REV-1** `requestReview` after 7th completed day or first graduation (0.25d)

## Beta and release — Nov 23 → Dec 15
- [ ] **REL-1** Privacy policy page listing HealthKit types; App Privacy nutrition label (0.5d)
- [ ] **REL-2** Screenshots (Lock Screen → auto ring → graduation → privacy), 15 s preview video, description, keywords (1.5d)
- [ ] **REL-3** Early review build submitted by Nov 27 (HealthKit wording, paywall) (0.25d)
- [ ] **REL-4** Public TestFlight Nov 23 for first 100 waitlist users; triage daily (ongoing)
- [ ] **REL-5** Final submission Dec 4; In-app Event "New Year, 3 Habits" (Dec 26 → Jan 10); New Year offer (0.5d)
- [ ] **REL-6** Release Dec 15; email waitlist

## Marketing (parallel, ~3 h/week)
- [ ] **MKT-1** Name decided: **Fledge**. Reserve in App Store Connect, USPTO + EUIPO search, buy fledgehabits.com (or bid on fledge.app), landing page + waitlist by Oct 25
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
