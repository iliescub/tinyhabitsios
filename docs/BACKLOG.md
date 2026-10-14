# Relaunch backlog

Spec: https://claude.ai/code/artifact/3570cc79-5f90-4826-9950-d1f0ee305d54 (offline copy: `docs/SPEC.md`)
Estimates are focused-work days (d). Cut order if late is at the bottom. ✅ = done.

## Start here (status as of 2026-10-14, 17:30, checked via `swift scripts/asc.swift status` / `iap-status`)

**Version 1.0 is back in Developer Rejected (editable)**: it was submitted at 13:30 UTC without the in-app purchases and the owner
withdrew it. Build **1.0 (3)** carries the paywall fix (full headline, wrapping comparison table, plan picker) and is attached.
**In-app purchases: all three READY_TO_SUBMIT** (localization, prices in 175 territories, App Review screenshot + note).
Listing, category, age rating, content rights, free price, copyright "© 2026 HealthyLiving" and App Review contact are set.
Release option is still **AFTER_APPROVAL**.

**To resubmit (owner, App Store Connect)**
1. **Enable GitHub Pages first** (code and `gh-pages` are pushed): Settings › Pages › Build and deployment › Source: **Deploy from a
   branch** › `gh-pages` / (root) › Save. The privacy, terms and support URLs return 404 until then; App Review opens the privacy link.
2. On the 1.0 version page, under **In-App Purchases and Subscriptions**, add yearly, monthly and lifetime (first products must go
   with a version), check build 3 is selected, decide manual vs automatic release, then **Submit for Review**.

**After that:** TestFlight device checks (HK-5, HEAD-2, WID-5, IPAD-2, POL-1 VoiceOver); decisions DEC-1, prices, ANA-1; rotate the
three secrets from the 2026-10-11 session.

**Ship the next build:** bump `CURRENT_PROJECT_VERSION` in both targets → `scripts/release.sh` → `swift scripts/asc.swift builds` →
`swift scripts/asc.swift attach-build <n>`.

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
  Status 2026-10-14 17:30: all three **READY_TO_SUBMIT** (App Review screenshot from the UI test + review note via `iap-review`).
  Still to do: add them to the 1.0 version and submit; revisit prices after the price decision
- [~] **REL-1** ✅ 2026-10-14: privacy policy (lists every HealthKit type), terms (Apple EULA + subscription terms) and support pages in
  `website/`, published by GitHub Pages; URLs set in the app (`AppLinks`) and in App Store Connect (privacy, support, marketing).
  Status 2026-10-14: pushed; `website/` is published to the `gh-pages` branch by the workflow — **enable Pages from `gh-pages`** to go live. App Privacy answered by the owner at submission
- [~] **REL-2** ✅ 2026-10-14: description, keywords, promotional text, subtitle and both screenshot sets uploaded via `scripts/asc.swift`
  (order: graduation → Today → head start → Flown → widgets → privacy). Still to do: 15 s preview video; Lock Screen and Siri shots from a device
- [~] **REL-3** ✅ 0.1 (1) uploaded 2026-10-11; **1.0 (2)** uploaded with the API key, VALID and attached to version 1.0 on 2026-10-14
  (redesign, iPad, differentiators). Still to do: review build by Nov 27
- [ ] **REL-4** Public TestFlight Nov 23 for first 100 waitlist users; triage daily (ongoing)
- [~] **REL-5** 1.0 (2) submitted 2026-10-14 without the in-app purchases and withdrawn the same day; resubmit with build 3 and
  the three products (review requirements set via `asc.swift review-setup` + owner). Still to do: In-app Event "New Year, 3 Habits"; New Year offer. Original plan: final submission Dec 4; In-app Event "New Year, 3 Habits" (Dec 26 → Jan 10); New Year offer (0.5d)
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
