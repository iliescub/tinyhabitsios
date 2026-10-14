<!-- Offline copy of https://claude.ai/code/artifact/3570cc79-5f90-4826-9950-d1f0ee305d54 — the online doc is the source of truth. -->

# Fledge — Product Spec & Launch Roadmap

Oct 11, 2026 · @Bogdan · v1.0 spec

## Executive summary

We relaunch the existing TinyHabits codebase as a **"do less" habit app**. You get at most three active habits, they complete themselves from Apple Health wherever possible, and each one graduates once it sticks. Release on the App Store by **mid-December 2026** so the app has ratings and keyword rank before the New Year habit peak.

**Pitch:** *Three habits. Done for you. Then they fly.*

**Name: Fledge.** A habit is "in the nest" while active and "fledged" when it graduates; graduated habits live on the "Flown" shelf. App Store title: *Fledge: Habit Tracker*. Subtitle: *3 habits that track themselves*. Icon: a small bird or feather in the accent colour.

**Positioning (updated 2026-10-14, `docs/POSITIONING.md`): Fledge is the habit tracker that lets go.** A market check found that
auto-completion from Apple Health (Streaks, Habitify) and a three-habit limit (a common free-tier cap) already exist elsewhere;
**habits that graduate and leave the tracker** don't. Graduation is the headline; "done for you" and "three" are the proof.
Research behind it: habits take ~66 days on average (Lally et al.); habit apps can build dependency, and people who drop the app
often drop the habit (Renfree et al., CHI 2016); reminders support repetition but can hinder automaticity (CHI 2019).

**Why this angle**

- The category is crowded with "track everything" dashboards. A hard limit of 3 plus graduation is a position nobody clearly owns.
- People abandon habit apps because logging is a chore. Auto-completion removes most of the logging; widgets and the Lock Screen handle the rest.
- About 70% of the current code carries over: SwiftData models, the 3-habit focus screen, streaks, reminders and HealthKit reads.
- The same engine can later be re-skinned as niche **packs** (Option B) without a rewrite. We choose a niche from real usage data in February 2027, not by guessing now.

**What it is not:** a coach, a social network, a journal or a to-do list.

## Goals, non-goals and success metrics

Version 1.0 succeeds if people who connect Apple Health stay noticeably longer than typical habit-app users and a meaningful share of them pay. Download volume is secondary.

**Goals for 1.0**

1. Ship a polished 1.0 that is live on the App Store by mid-December 2026.
2. Make at least half of all completions happen without opening the app (auto-completion, widget or Lock Screen).
3. Have paid conversion working from day one, so January traffic turns into revenue.
4. Collect the data needed to decide on a niche (Option B) by February 2027.

**Non-goals for 1.0:** Android, iPad layouts, social features, AI coaching, Screen Time tracking, a full Apple Watch app, accounts or a backend.

**Success metrics.** These are first targets, not benchmarks; revise them after the first 4 weeks of data.

| Metric | Target by Feb 15, 2027 | Why it matters |
| --- | --- | --- |
| Day-30 retention (all installs) | ≥ 12% | Typical apps keep about 5–6% |
| Day-30 retention (≥1 auto habit) | ≥ 20% | Tests the core thesis |
| Completions not done in the app | ≥ 50% | Tests the "done for you" promise |
| Trial start rate (of installs) | ≥ 20% | Tests whether the paywall offer appeals |
| Trial → paid | ≥ 35% | Tests whether people pay |
| Downloads, Dec 15 – Jan 31 | 5,000 | Enough data for the niche decision |
| App Store rating | ≥ 4.7 from 100+ ratings | Affects ranking and featuring |

## Target users

The 1.0 audience is iPhone owners who already have health data flowing into Apple Health and have quit at least one habit app. Niche personas come later, once we have data.

| Persona | Situation | What they want | How the app fits |
| --- | --- | --- | --- |
| **The relapser** (primary) | Has tried 2+ habit apps and quit around week 3 | Something that doesn't feel like homework | Limit of 3, auto-completion, no guilt screens |
| **The quantified-lite** | Wears an Apple Watch and checks the Activity rings | Habits that ride on data they already produce | Steps, exercise, sleep and mindful minutes complete on their own |
| **The New Year starter** | Downloads in the first week of January | A fresh start without an overwhelming setup | Under 60 seconds to first habit; templates |

**Niche personas to watch for in usage data (Option B):** GLP-1 medication users, new parents, people with ADHD, desk workers, people in rehab or physio. Section *Option B* covers how to evaluate them.

## Product principles

When a feature request conflicts with one of these principles, the principle wins.

1. **Three is the product.** Never more than 3 active habits, and no paid tier that unlocks more. To add a fourth, one has to graduate or be paused.
2. **The best check-in is none.** If a habit can be measured, measure it. Manual taps are the fallback.
3. **Outside the app first.** Design the widget and Lock Screen first and the in-app screens second. A session in the app should take under 5 seconds.
4. **Graduate, don't grind.** The goal is a habit that runs on autopilot, not an endless streak. Celebrate graduations more than streaks.
5. **No guilt.** Allow rest days, show no red failure screens, and make a broken streak cost nothing.
6. **Private by default.** No account, no analytics SDK that sees health data, and Health data never leaves the device.
7. **Native and quiet.** Use system fonts, SF Symbols and Apple materials. One accent colour, and no pop-ups at launch.

## Brand and UI concept

Theme **"Leave the nest"**: three habits in a nest that fill up by themselves and fly once they stick. One calm screen (Today) plus sheets,
native iOS 26 Liquid Glass on the navigation layer only. Icon: a white fledgling whose wing is a checkmark, on a sky-to-dawn gradient
(`Design/Icon/`). Full concept — research, palette with contrast values, typography, motion, every screen, state and widget,
accessibility, screenshots — in **`docs/DESIGN.md`**. Platform decision DEC-1: raise the minimum to iOS 26 (recommended).

## Core loop: 3 slots, check-ins and graduation

The app has three slots. Each holds one active habit, which moves through four states: **active**, **ready to graduate**, **graduated** and **paused**. The Today screen shows the three slots and nothing else.

### Habit definition

| Field | Values | Notes |
| --- | --- | --- |
| Name, icon, colour | Free text, SF Symbol, 1 of 8 palette colours | Name up to 30 characters |
| Source | Manual, or a HealthKit metric | See *Automatic completion* |
| Target | A number + unit (e.g. 6,000 steps, 10 min, 1 time) | Manual habits default to 1 time |
| Cadence | Every day, or N days a week (1–7) | Weekly cadence tolerates rest days |
| Reminder | Off, or one time of day | Cancelled automatically once the habit is done |
| Started on | Date | Graduation is measured from here |

### Daily check-in

- **Auto habits** fill their progress ring from Health in near real time and turn to done once they hit the target. The user can still override with a manual tap.
- **Manual habits** have one tap to mark done, from the widget, the Lock Screen, Siri, Control Center or the app. Long-press to log a partial amount.
- **Skip / rest day:** marks the day as intentionally skipped. On a weekly cadence it doesn't break the streak; on a daily cadence it uses one of 2 "free passes" per month.
- A "day" ends at a user-set hour (default 3:00 AM), so late-night completions count for the right day.

### Graduation

- A habit becomes **ready to graduate** once it has been active for at least 30 days **and** met its cadence in at least 80% of the last 30 days. The app offers graduation; it never forces it.
- The default suggestion is 66 days, the median time to automaticity in Lally et al. (2010). The 30-day minimum keeps the first win reachable.
- Graduating frees the slot, plays a celebration and adds the habit to the **Graduates** shelf with its start date, days to graduate and completion rate.
- Graduated habits keep tracking quietly (auto habits at no cost). If one drops below 50% over 14 days, the app sends a single gentle nudge offering to bring it back to a slot. **Built (GRAD-3):** `SlipCheck` + `HoldingRate` in HabitCore; one nudge per slip, re-armed when the habit holds again (≥ 80%); sent between 9:00 and 19:00 (else 10:00 next morning); tapping it opens the Flown shelf. Tap-to-log graduates aren't logged any more, so they're never nudged.
- **Flight forecast (GRAD-4):** the detail shows "On track to fly around 30 Nov" (or "Keep it going and it can fly around…") — the first day the habit would be ready if it's met every day from now (`FlightForecast`).

### Health head start (HEAD-1, added 2026-10-14)

When a Health habit is added (Add › Configure, or onboarding after connecting Health), Fledge reads the **last 30 days** for that
metric on the device and shows: the average on days with data, how many of the 30 days met the goal, and one of four verdicts
(`HealthBaseline`): *not enough data* (< 7 days), *already a habit* (≥ 80% met → "aim higher, or pick something new"), *within reach*
(≥ 50%), *start smaller* (suggest a goal just above the usual level). Suggestions are opt-in. After the habit is added, those 30 days
are recorded as "Before Fledge" days: the heatmap shows them faded, while streaks and graduation still count from the start date.

### Pausing and replacing

- Pausing a habit frees its slot and keeps its history. Resuming needs a free slot.
- There are no hard deletes from the Today screen. Deleting lives in the habit's settings and asks for confirmation.

### Streaks

Streaks count days on which the cadence was met, so rest days within a weekly cadence don't break them. Streaks appear on the habit detail screen, not on Today. The headline number is "days until graduation".

## Automatic completion

Version 1.0 completes habits automatically from eight Apple Health metrics. These are read-only; we never write to Health. Any other habit falls back to a one-tap manual check-in.

### Supported sources in 1.0

| Template | HealthKit type | Aggregation | Default target |
| --- | --- | --- | --- |
| Walk | `stepCount` | Daily sum | 6,000 steps |
| Move / exercise | `appleExerciseTime` | Daily sum | 20 min |
| Workout | `HKWorkout` (any type, or a chosen type) | Count or minutes | 1 workout |
| Stand | `appleStandHour` | Count of hours stood | 10 hours |
| Mindful minutes | `mindfulSession` | Daily sum | 5 min |
| Sleep | `sleepAnalysis` (asleep stages) | Main session, already in the code | 7 h |
| Drink water | `dietaryWater` | Daily sum | 2.0 L |
| Daylight | `timeInDaylight` | Daily sum | 20 min |

After 1.0, the same mechanism can add `dietaryProtein` (a GLP-1 pack), `distanceWalkingRunning`, `flightsClimbed`, and Screen Time through `DeviceActivity`. Screen Time needs the Family Controls entitlement, which Apple has to approve, so it is not in scope for 1.0.

### Behaviour rules

- **Foreground:** run an `HKStatisticsQuery` for today on launch and every time the app becomes active. Values refresh within about 1 second of opening the app.
- **Background:** register an `HKObserverQuery` with `enableBackgroundDelivery` for each type in use. Apple limits some types, such as step count, to roughly hourly delivery. When an update arrives, recompute the day, save it, reload widgets and cancel today's reminder if the habit is done.
- **Widgets** cannot query HealthKit when the device is locked, so they show the last value the app saved, along with its age ("updated 14 min ago").
- **Read permission is invisible.** HealthKit doesn't tell an app whether read access was denied; denial looks the same as zero data. If an auto habit shows 0 by 6 PM on 3 days in a row, show a single banner: "Not seeing any data? Check Health access."
- **Manual override:** the user can always tap "done" on an auto habit. Store it as `completedBy = manual`, and don't let a later Health value undo it.
- **Partial Health data** (e.g. no Apple Watch for exercise minutes): offer to switch that habit to manual during setup if there are no samples from the last 7 days.

### Privacy and App Review constraints

- App Review Guideline 5.1.3(ii) says apps "may not store personal health information in iCloud." Any future iCloud sync must therefore exclude raw Health values and sync only habit definitions and done/skipped flags. Confirm this interpretation before building sync.
- The App Store description and onboarding must say clearly that the app reads from Apple Health and why (Guideline 2.5.1).
- The privacy policy must list every HealthKit type the app reads (Guidelines 5.1.1 and 5.1.3).

## Widgets, Lock Screen, Watch and Siri

Widgets and App Intents ship in 1.0. A full Apple Watch app moves to 1.1 (January). Health data recorded on the Watch already completes habits through auto-completion, so a Watch app is not needed for that.

### Surfaces in 1.0

| Surface | Content | Interaction |
| --- | --- | --- |
| Home Screen, small | 3 rings + days until next graduation | Tap a manual ring → done (interactive `Button(intent:)`) |
| Home Screen, medium | 3 rows: name, progress, source icon | Tap the checkmark on manual habits |
| Lock Screen, circular | One habit's ring (user picks the habit) | Opens the app |
| Lock Screen, rectangular | 3 mini rings + "2 of 3" | Opens the app |
| Lock Screen, inline | "2/3 habits · 41 days to graduate" | — |
| Control Center control (iOS 18) | "Mark \[habit\] done" | Runs the intent without opening the app |
| StandBy | Large widget variant | — |

### App Intents, which also power Siri, Shortcuts and Spotlight

- `CompleteHabitIntent(habit)`: marks a habit done for today.
- `LogProgressIntent(habit, amount)`: adds to a manual habit's quantity.
- `SkipTodayIntent(habit)`.
- `HabitStatusIntent`: returns "2 of 3 done; Walk needs 1,800 more steps" for Siri to read aloud.
- `AppShortcutsProvider` with phrases such as "Mark meditate done in \[App\]".
- `HabitEntity` conforms to `AppEntity`, so habits appear in Shortcuts and as widget configuration choices.

### Planned for 1.1 (January–February 2027)

- A watchOS app with a 3-ring complication and tap-to-complete for manual habits, sharing data through the same App Group storage.
- A Live Activity for timed habits (e.g. "Stretch 5 min") started from the widget.

## Onboarding, reminders, stats and settings

Onboarding takes under 60 seconds and asks for nothing that the app doesn't use. The current profile step (name, age, height, weight) is removed.

### Onboarding: 4 screens

1. **Promise:** "Three habits. Done for you." One animation of a ring filling by itself, and a Continue button.
2. **Pick up to 3** from 8 templates (the auto ones are marked with a Health icon) or create a custom habit. Targets can be adjusted inline.
3. **Connect Health:** shown only if an auto template was picked. Explain why first, then show the system prompt. Skipping turns those habits into manual ones.
4. **Reminders + widget:** ask for notification permission (optional), then show a 5-second animation of adding the widget. This ends on the paywall, which offers the free trial and can be closed.

### Reminders

- One optional time per habit. A reminder is scheduled only if the habit isn't done yet, and is removed as soon as it is completed (by Health, a widget or the app).
- An optional evening summary at a time the user picks: "2 of 3 done. Walk needs 1,800 steps." It is not sent if all 3 are done.
- Drop the current daily-quote overlay. Quotes become an optional line in the evening summary.

### Stats (habit detail)

- A 12-week heatmap, current and best streak, completion rate over the last 30 days, and a "days to graduation" countdown.
- The Graduates shelf shows the date each habit graduated, how many days it took and how it has held up since.
- The current `StatsView` and `HabitDetailView` are reused and trimmed.

### Settings

Appearance (accent colour, app icon), day-end hour, reminders, Health access status, iCloud sync (1.1), export to CSV, privacy policy, restore purchases and contact. The four separate tabs (Focus, Stats, Settings, Profile) become a single Today screen, with Graduates and Settings opened from toolbar buttons.

## Monetization

The model is freemium. Free users get the whole core loop with one auto habit. Pro unlocks "done for you" across all three slots, plus every surface outside the app. Pro is sold as an annual subscription with a 7-day trial, alongside a lifetime option.

| Feature | Free | Pro |
| --- | --- | --- |
| 3 slots, graduation, streaks, Graduates shelf | ✓ | ✓ |
| Manual check-ins, reminders | ✓ | ✓ |
| Auto-completed habits | 1 | All 3 |
| Home Screen widget | Small | All sizes + StandBy |
| Lock Screen widgets, Control Center, Siri phrases | — | ✓ |
| App icons, accent colours | 1 | All |
| CSV export; iCloud sync (1.1) | — | ✓ |
| Niche packs (Option B, later) | — | ✓ |

**Starting prices, to test later:** $2.99/month · $19.99/year with a 7-day trial · $39.99 lifetime. Check competitors' current prices before launch, and run a New Year offer (e.g. 40% off the annual plan from Dec 26 to Jan 10).

**Paywall placement:** at the end of onboarding (can be closed), when the user adds a second auto habit, when they tap a Pro widget, and once from the first graduation celebration. Never on launch.

**Implementation:** native StoreKit 2 with `SubscriptionStoreView`, so no third-party SDK is needed. Entitlements are checked through `Transaction.currentEntitlements`, and the Pro flag is cached in the App Group so widgets can read it. Revisit RevenueCat only if paywall A/B testing becomes a priority.

## Option B: niche packs

Option B is built into 1.0 as a data structure, not as a feature. Every template belongs to a **pack**, and 1.0 ships only the "Essentials" pack. On February 15, 2027 we choose one niche from the usage data. That niche either becomes a paid pack inside the app or, if it performs strongly, its own App Store listing built from the same codebase.

### What a pack is

A pack is a bundled JSON file with no code changes and no backend:

```json
{
  "id": "glp1",
  "name": "On GLP-1",
  "tagline": "Protect muscle while the scale moves",
  "accent": "teal",
  "templates": [
    { "name": "Protein", "symbol": "fork.knife", "source": "hk.dietaryProtein", "target": 100, "unit": "g" },
    { "name": "Lift", "symbol": "dumbbell.fill", "source": "hk.workout.traditionalStrengthTraining", "target": 1, "cadence": { "perWeek": 3 } },
    { "name": "Water", "symbol": "drop.fill", "source": "hk.dietaryWater", "target": 2.5, "unit": "L" }
  ],
  "copy": { "onboardingTitle": "...", "graduationLine": "..." },
  "graduation": { "minDays": 30, "threshold": 0.8 }
}
```

A standalone niche app is the same Xcode project with a second target. It has its own bundle ID, App Store listing, icon and default pack, and it hides the pack picker.

### Candidate niches

| Niche | Habits that can auto-complete | Where to reach them | Willingness to pay | Main risk |
| --- | --- | --- | --- | --- |
| GLP-1 users | Protein, water, strength training, steps | Large Reddit and Facebook communities | High (already paying for treatment) | Health claims; must avoid giving medical advice |
| Desk workers | Stand, steps, daylight, mindful minutes | LinkedIn, r/productivity, ergonomics creators | Medium | Generic, so weak positioning |
| New parents | Sleep, steps, mindful minutes, water | Parenting forums, Instagram | Low–medium | Little free time; irregular days |
| ADHD | Few (mostly manual) | Large TikTok and Reddit communities | High | Tiimo and others are strong; needs different UX |
| Rehab / physio | Workouts, steps | Clinicians recommending apps | Medium–high | Hard to reach clinics as a solo developer |

### How we decide on February 15, 2027

Score each candidate from 1 to 5 on each of these:

1. **Organic pull:** custom habits in the 1.0 data that match the niche (from on-device analytics of template names, opt-in only).
2. **Auto share:** the share of the pack's habits that complete without manual input.
3. **Reach:** whether one person can reach 10,000 of them for free in 30 days.
4. **Willingness to pay**, tested with a landing page for the pack and a waitlist counter.
5. **Competition:** the number of dedicated apps in the top 50 for the niche's keywords.

Pick the highest total. If no niche scores at least 18 out of 25, stay general and invest in distribution instead.

## Technical architecture and data model

The app keeps SwiftUI and SwiftData. All logic moves into a shared local Swift package, **HabitCore**, that the app, the widget extension and (later) the Watch app all link against. One SwiftData store lives in an App Group container, so every target sees the same data.

### Platform decisions

| Decision | Choice | Reason |
| --- | --- | --- |
| Minimum iOS version | 18.0 | Needed for Control Center controls. DEC-1 proposes iOS 26 for native Liquid Glass |
| Language / concurrency | Swift 6, strict concurrency | Catches data races between HealthKit callbacks and the UI |
| State | `@Observable` view models | Replaces `ObservableObject` / `@Published` |
| Persistence | SwiftData with `VersionedSchema` from V1 | Avoids the current "reset the store on migration failure" path |
| Shared storage | App Group `group.<bundle-id>` | Lets the widget, controls and intents read and write the same store |
| CloudKit readiness | No `.unique` attributes, every property defaulted, relationships optional | Lets iCloud sync be switched on in 1.1 without a migration |
| Tests | Swift Testing for HabitCore; one UI smoke test | The engine is pure and easy to test |
| Analytics | TelemetryDeck (anonymous) or none; never sends Health values | Needed for the retention-by-source metric; App Store Connect can't segment by source |
| Payments | StoreKit 2 | See *Monetization* |

### Project layout

```
TinyHabits.xcodeproj
├─ App/                 SwiftUI screens, onboarding, paywall
├─ WidgetsExtension/    WidgetKit widgets + ControlWidget
├─ Packages/HabitCore/
│   ├─ Model/           Habit, DayLog, SchemaV1, migration plan
│   ├─ Engine/          DayEvaluator, StreakCalculator, GraduationEvaluator
│   ├─ Sources/         HabitSource protocol, HealthKitSource, ManualSource
│   ├─ Sync/            HealthSyncActor (observer queries, background delivery)
│   ├─ Intents/         AppIntents, HabitEntity, AppShortcuts
│   ├─ Notifications/   ReminderReconciler
│   ├─ Packs/           Pack model + bundled JSON
│   └─ Store/           SharedModelContainer, ProStatus
└─ Tests/
```

### Data model (SchemaV1)

```swift
@Model final class Habit {
    var id: UUID = UUID()
    var name: String = ""
    var symbol: String = "circle"
    var colorKey: String = "blue"
    var stateRaw: String = HabitState.active.rawValue   // active | graduated | paused
    var slot: Int? = nil                                 // 0...2 when active
    var sourceRaw: String = "manual"                    // "manual" | "hk.stepCount" | ...
    var target: Double = 1
    var unit: String = "times"
    var perWeek: Int = 7                                 // 7 = daily cadence
    var reminderMinutes: Int? = nil                     // minutes after midnight
    var packID: String = "essentials"
    var startedAt: Date = Date.now
    var graduatedAt: Date? = nil
    @Relationship(deleteRule: .cascade, inverse: \DayLog.habit) var logs: [DayLog]? = []
}

@Model final class DayLog {
    var dayKey: String = ""            // "2026-12-15", computed with the day-end hour
    var value: Double = 0
    var statusRaw: String = "pending"  // pending | done | skipped
    var completedByRaw: String? = nil  // manual | auto | widget | intent
    var updatedAt: Date = Date.now
    var habit: Habit? = nil
}
```

**Key rules**

- `dayKey` replaces the current `Date` range queries. It avoids time-zone and daylight-saving bugs, and makes "one log per habit per day" a simple lookup.
- Only one writer at a time: every write goes through a `@ModelActor` (`HabitWriter`). Widgets and intents call the same actor.
- Notifications are never scheduled one by one from views. `ReminderReconciler.reconcile()` rebuilds all pending requests from the current state after every write.
- After each write: `WidgetCenter.shared.reloadAllTimelines()` and `ControlCenter.shared.reloadAllControls()`.

## Gap analysis: current code vs this spec

The current 4,160 lines of Swift are a usable base: the HealthKit queries, the 3-habit Today concept, the habit detail screen and the design tokens carry over. The data layer and the navigation need rewriting. The profile, quote and swipe-navigation code is removed.

| Area | Current files | Action | What changes |
| --- | --- | --- | --- |
| Models | `Habit.swift`, `HabitEntry.swift`, `HabitProgress.swift` | **Rewrite** | SchemaV1 above: `dayKey`, state, slot, source, cadence; remove `.unique` |
| Persistence | `PersistenceController.swift`, `HabitStore.swift` | **Rewrite** | App Group store, `VersionedSchema`, `HabitWriter` actor; remove the reset-on-failure path |
| Today logic | `FocusViewModel.swift` | **Refactor** | Move progress and toggle logic into `DayEvaluator`; remove the duplicated `todayEntry` code |
| HealthKit | `HealthKitManager.swift` | **Refactor** | Keep the queries (sleep-session logic is good); make them generic per type, async/await, observer + background delivery |
| HealthKit UI | `HealthKitView.swift` | **Remove** | Health values appear on the habit rings instead |
| Notifications | `NotificationManager.swift` | **Refactor** | Becomes `ReminderReconciler`: skip reminders for habits already done |
| Today screen | `FocusView.swift`, `HabitsView.swift`, `ProgressRing.swift` | **Refactor** | Show 3 slots, auto/manual badges, "days to graduate" |
| Habit detail | `HabitDetailView.swift`, `StatsView.swift`, `StatsViewModel.swift` | **Refactor** | Add heatmap and graduation; stop querying every entry (`@Query` of all `HabitEntry`) |
| Navigation | `MainTabView.swift`, `SwipeGuard.swift` | **Replace** | A single Today screen with toolbar sheets; remove the custom swipe-between-tabs gesture |
| Onboarding | `OnboardingView.swift`, `OnboardingViewModel.swift`, `ProfileStatsView.swift` | **Rewrite** | 4-screen flow; no name, age, height or weight |
| Profile | `ProfileView.swift`, `ProfileViewModel.swift`, `ProfileImagePicker.swift` | **Remove** | No profile in a no-account app |
| Motivation | `MotivationProvider.swift`, `DailyQuoteOverlay.swift`, `MotivationBanner.swift` | **Remove** | Drop the launch overlay; quotes may return as a line in the evening summary |
| Design | `DesignTokens.swift`, `Theme.swift`, `ThemeView.swift`, `HeroHeader.swift` | **Keep / trim** | Keep the tokens and accent theme; replace the Unsplash hero images with SF Symbols and materials |
| Haptics, errors | `HapticManager.swift`, `ErrorBanner.swift`, `EmptyStateView.swift` | **Keep** | — |
| Settings | `SettingsView.swift`, `SettingsViewModel.swift` | **Refactor** | The new list from *Settings* above |
| New | — | **Add** | Widget extension, App Intents, StoreKit paywall, packs, Swift Testing target |

The repository currently has about 20 uncommitted modified files on `main`. Commit or stash them before the relaunch branch is created.

## Roadmap

The plan is five overlapping 2-week build milestones, then a 2-week beta. Features freeze on Nov 29, the app goes to review on Dec 4 and releases on Dec 15, leaving a 10-day buffer before the New Year push.

&#91;embedded content: relaunch roadmap · 5 build milestones, beta, 3 gates\]

Milestones overlap because the work is sequential in logic but parallel in practice. For example, the Health sources (M2) can be built while the Today screen (M1) is still being styled.

| Milestone | Done when |
| --- | --- |
| M0 Foundations | HabitCore linked; shared App Group store; profile, quote and swipe code removed; the app runs on the new schema |
| M1 Core loop | 3 slots, check-in, skip, cadence, graduation and the Graduates shelf work end to end, with engine tests passing |
| M2 Auto-completion | 8 Health sources fill rings in the foreground and background; reminders are reconciled after each write |
| M3 Widgets and intents | Small and medium widgets, 3 Lock Screen widgets, a Control Center control, App Intents and Siri phrases |
| M4 Onboarding, paywall | 4-screen onboarding, StoreKit paywall, settings, app icon, accessibility pass, App Store screenshots |
| TestFlight beta | Bug fixes only; crash-free rate of at least 99.5%; a review build sent in by Nov 27 |
| 1.1 (Jan–Feb) | Watch app and complication; iCloud sync of definitions and flags; Live Activity for timed habits |

The full ticket list per milestone is in `docs/BACKLOG.md` in the repository.

## Launch and distribution

Release on December 15 and push hardest from December 26 to January 15, when people search for habit apps. HabitKit, built by one developer, made $112k in January 2025 alone. That came from a creator video landing during the New Year rush, followed by a top-5 rank for "habit tracker" in the US ([source](https://sebastianroehl.substack.com/p/2025-the-year-that-changed-everything)). The same channels are open to us.

### Before launch (October – mid-December)

- **Name + landing page by Oct 25:** one page with a 15-second video of a ring filling by itself, and a waitlist. Goal: 500 sign-ups by Dec 15.
- **Build in public, 2 posts a week:** on X and r/iOSProgramming / r/SideProject, showing real progress (widgets, graduation animation, Health auto-fill). Avoid hard selling.
- **TestFlight public beta from Nov 23:** the first 100 waitlist users, with an in-app feedback link. Ratings from beta testers carry no weight, but their bug reports do.
- **Creator outreach, Nov 15 – Dec 10:** 30 YouTube and TikTok creators who do "apps you'll actually use", "iPhone setup" or "minimal productivity" content. Offer free lifetime Pro and a short brief. Aim for 3 videos in the week of Dec 28.
- **Apple featuring nomination** in App Store Connect, submitted around Nov 15 for a launch on Dec 15, with the angle "Apple-native, private, Health-powered".
- **Press kit by Dec 1:** icon, 6 screenshots, the 15-second video, a 100-word description and the founder's story.

### App Store optimisation

- **Title:** `Fledge: Habit Tracker` (30 characters max). **Subtitle:** "Habits that stick, then fly" (was "3 habits that track themselves", which describes what Streaks already does).
- **Promotional text:** "Most habit apps want you forever. Fledge fills in three habits from Apple Health and lets each one go once it sticks, about 66 days on average."
- **Keywords to target:** habit tracker, apple health, automatic, routine, minimalist, streak, new year, goals, self improvement, 66 days.
- **Screenshots in this order:** graduation → Today (done for you) → head start → Flown shelf → widgets → privacy (`Design/AppStore/`, `scripts/appstore-screenshots.sh`).
- **In-app Events:** "New Year, 3 Habits" from Dec 26 to Jan 10, shown on the App Store.
- **Rating prompt** (`requestReview`) appears only after the 7th completed day or the first graduation, never earlier.

### Launch window

| Date | Action |
| --- | --- |
| Dec 15 | Release to the App Store; email the waitlist |
| Dec 26 | Start the New Year offer and In-app Event |
| Dec 28 – Jan 3 | Creator videos go live |
| Jan 5 (Tue) | Product Hunt launch |
| Jan 15 | End the offer; review the first 4 weeks of data |

## Risks, open questions and decisions

The biggest risk is the schedule. This is about 9 weeks of build time for one person, and App Review slows down around the holidays. Every scope cut below is decided now, so a slip costs features, not the launch window.

### Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Build slips past Dec 4 submission | High | Misses the New Year window | Cut in this order: Control Center control → Lock Screen inline/circular → Workout and Daylight sources → Graduates shelf polish. Never cut: widgets, auto-completion, paywall |
| App Review rejection (HealthKit wording, paywall) | Medium | 3–7 day delay | Submit a build for review by Nov 27 even if not final; Health purpose strings reviewed against 2.5.1 and 5.1.3 |
| "Tiny Habits" trademark conflict (BJ Fogg) | Medium | Forced rename after launch | Resolved: renamed to Fledge. Still to do: App Store Connect reservation and USPTO + EUIPO search |
| HealthKit data is missing or late | Medium | "Done for you" feels broken | Show when data was last updated, offer manual fallback during setup, show the no-data banner |
| Background delivery is throttled | Medium | Widget looks stale | Show a timestamp on widgets; refresh when the app opens; don't promise real-time updates |
| Health data in iCloud breaks the rules | Low (1.1) | Rejection of the sync update | Sync only definitions and done/skipped flags |
| No distribution traction | Medium | Few downloads despite a good product | Start building in public and creator outreach now, not at launch |
| Burnout from building and marketing alone | Medium | Quality drops | Fixed scope, a weekly review every Sunday, no new features after Nov 29 |

### Decisions needed this week

- [ ] **App name.** It must work as a 30-character App Store title and be free of "Tiny Habits". Decided: Fledge (reserve it in App Store Connect and run a USPTO + EUIPO search). Other candidates considered: *Three*, *Trio Habits*, *Autopilot Habits*, *Quietly*, *Graduate*.
- [ ] **Free tier:** 1 auto habit (as specified) or a trial-only model.
- [ ] **Prices:** confirm $19.99/year and $39.99 lifetime after checking competitors.
- [ ] **Analytics:** TelemetryDeck or none.
- [ ] **Commit or discard** the current uncommitted changes on `main`.

### Open questions

- Is the app being built only for iPhone, or should it also run on iPad as an iPhone app? (Spec assumes iPhone only.)
- Which language besides English, if any, ships in 1.0? (Spec assumes English only.)
- Is there an existing Apple Developer account with the HealthKit capability, and who is the legal seller (personal name or a company)?

## Implementation kickoff checklist

The repository already contains the starting pieces: `CLAUDE.md` (conventions), `docs/BACKLOG.md` (tickets by milestone), and a `Packages/HabitCore` Swift package with SchemaV1, the day/streak/graduation engine, the Essentials pack and unit tests. The rest of this list is setup that only you can do.

### Apple and accounts (week of Oct 12)

- [ ] Confirm the Apple Developer Program membership and the legal seller name
- [ ] Reserve the app name in App Store Connect (create the app record)
- [ ] Create an App Group `group.<bundle-id>.shared` and add it to the app and widget targets
- [ ] Turn on the HealthKit capability, including **Background Delivery**
- [ ] Create the StoreKit products: `pro.monthly`, `pro.yearly` (with a 7-day intro offer), `pro.lifetime`, and a local `.storekit` configuration file for testing
- [ ] Write a privacy policy listing each HealthKit type read, and host it (e.g. on the landing page)
- [ ] Register the domain and set up the landing page with a waitlist
- [ ] Do a trademark and App Store search for the final name

### Repository (day 1)

- [ ] Commit or stash the current changes on `main`, then create the branch `relaunch/v1`
- [ ] Add `Packages/HabitCore` to the Xcode project (File → Add Package Dependencies → Add Local) and link it to the app
- [ ] Run `swift test` in `Packages/HabitCore`; it should pass
- [ ] Add the Widget Extension target and link HabitCore to it
- [ ] Set the deployment target to iOS 18.0 and the Swift 6 language mode

### First week of code (M0)

- [ ] Point the app's `ModelContainer` at the shared App Group store using `HabitCore.SharedStore`
- [ ] Delete the profile, quote overlay and swipe-navigation code (see the gap analysis)
- [ ] Rebuild the Today screen on `DayEvaluator`
- [ ] Make `HealthKitManager` generic and async, and wire it to `HabitWriter`
- [ ] Build a TestFlight internal build and install it on your own phone; dogfood it daily from here on

## Sources

- [HabitKit 2025 year in review (Sebastian Röhl)](https://sebastianroehl.substack.com/p/2025-the-year-that-changed-everything): $602k total revenue, $112k in January, and growth from a creator video plus a top-5 US ranking.
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/): 2.5.1, 5.1.1 and 5.1.3 (no personal health information in iCloud).
- Market context, from search results and not independently verified: [Braze on app retention](https://www.braze.com/resources/articles/mobile-app-retention), [Habitify Screen Time and NFC changelog](https://feedback.habitify.me/changelog/habitify-ios-1390-tracking-with-nfc-screen-time-integration-and), [Habitify early story (Failory)](https://failory.com/interview/habitify), [HabitTime on the App Store](https://apps.apple.com/us/app/-/id6446266347).
- Lally, van Jaarsveld, Potts & Wardle (2010), *How are habits formed: Modelling habit formation in the real world*, European Journal of Social Psychology: a median of 66 days to automaticity.
