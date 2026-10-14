Fledge · UI/UX review and redesign plan · 14 Oct 2026

# Fledge Redesign Plan

The engine, the copy and the concept are strong. The interface is not yet doing them justice. It reads as a careful prototype: generic symbols where the brand should be, half an empty screen, and four competing signals on every card. This plan brings the app icon's character into the product, gives every screen one clear hero, and fits inside the time left before the 29 November feature freeze.

**12**issues found on 9 screens

**8**comparable apps studied

**5**phases, \~14 focused days

**29 Nov**feature freeze; this fits before it

## Where the app stands today

Simulator captures from build 0.1 with demo data (iPhone 17, iOS 27). The paywall shows only a spinner because the command-line launch doesn't load the StoreKit configuration, but a slow network leaves real users looking at the same blank sheet.

![Current Today screen in light mode](shots/today-light.jpg)

Today: the lower 45% of the screen is empty

![Current Today screen in dark mode](shots/today-dark.jpg)

Dark mode works, but cards are flat on a flat background

![Current habit detail sheet](shots/detail.jpg)

Detail: the bird marker sits on the tick, and the heatmap has no labels

![Current add habit sheet](shots/add.jpg)

Add: 8 Pro badges and 8 Health labels; manual habits are off-screen

![Current onboarding first page](shots/onboarding.jpg)

Onboarding: one ring, a lot of empty sky

![Current graduation screen](shots/graduation.jpg)

Graduation: the peak moment uses a stock hummingbird

![Current Flown shelf](shots/flown.jpg)

Flown: one tile on a blank sheet

![Current settings sheet](shots/settings.jpg)

Settings: the upsell looks like any other row

![Current paywall loading](shots/paywall.jpg)

Paywall: no designed loading state

### Diagnosis

| Issue | What we see | Why it matters | Impact |
| --- | --- | --- | --- |
| Brand missing | The icon is a round white fledgling with a checkmark wing. In the app, every bird is SF Symbols' `bird.fill`, a hummingbird: toolbar, onboarding, graduation, Flown, paywall | The one distinctive asset never shows up where users spend time. This is the biggest gap between "prototype" and "product" | High |
| Today feels empty | Three short cards, then about 380 pt of blank background. The summary "1 of 3 done." is 15 pt grey text | The home screen sets the impression in screenshots and in the first five seconds. Empty space reads as unfinished, not calm | High |
| Card hierarchy | Ring, value, source badge and flight track all carry about the same weight. "4.210 / 6.000 steps" puts value and goal in one style | The answer to "how am I doing?" needs one glance. Today it takes a read | High |
| Status language | Done swaps the habit's symbol for a generic check. Rest day's dashed ring looks like a loading spinner. The flight track's grey fill and orange tick have no labels | Users lose which habit is which, and the graduation concept, the main differentiator, goes unexplained | High |
| Colour noise | The CTA is blue, the header peach, rings use habit colours, and every "Health" label is also blue | Blue is everywhere, so it no longer marks the action. Habit colour shows only inside the ring | Medium |
| Add sheet | Tall tiles in identical blue. A free user sees "Pro" on all 8 Health tiles, and "Tap to log" and Custom are below the fold | It reads as a wall of locks, and it slows the most important flow, adding a habit | High |
| Detail sheet | "Fledge progress" is internal jargon. The bird icon overlaps the day-30 tick. The heatmap has no weekday or month labels, its cells are oversized, and stats are below the fold | The stats screen is where people judge whether the app is "serious" | Medium |
| Graduation | A stock bird, a line of stats, mostly empty space. Nothing to share | This is the moment that makes Fledge different, and the best organic marketing asset it has | High |
| Flown shelf | One tile on a blank sheet. No totals, no "holding" rate | The reward for the whole loop feels like an afterthought | Medium |
| Paywall | Stock `SubscriptionStoreView` layout. No free-vs-Pro comparison, no trial timeline, no designed loading state | The paywall drives revenue. Trial-timeline paywalls are now the norm in health apps | High |
| Onboarding | One walking ring on screen 1. Plain progress dots and no back button | Under 60 seconds is right. The first screen should show the whole idea: three rings that fill by themselves, then fly | Medium |
| Settings | Plain form. "Get Fledge Pro" looks like any other row. "Restore purchases" is near the top for free users | Small, but it is where reviewers look for polish | Low |

## What similar apps get right

| App | What works | Take for Fledge |
| --- | --- | --- |
| Streaks | Apple Design Award. Big tappable circles, one gesture to complete, very low friction, widgets whose ring fills as you go | Make the ring the main control and enlarge it. Keep one gesture per action |
| (Not Boring) Habits | Treats each check-off as an event, with 3D, sound and haptics. Focus on building one habit at a time | Make "done" the best 0.8 s in the app: ring closes, check draws in, feathers lift |
| Gentler Streak | Apple Design Award 2024. Rest is a first-class state, numbers are shown simply, and the home view changes with the time of day | Show rest as calm, not as a broken loop. One plain summary sentence. Keep the time-of-day sky |
| Apple Fitness rings | One glyph tells the whole day | A "nest" glyph of three mini rings in the Today header, matching the small widget |
| HabitKit | A GitHub-style grid as its visual identity. Strong widgets. A solo developer that took off in January | Label the heatmap properly and use it on the graduation recap and the share card |
| Structured, Tiimo | Award-winning calm: soft colour, generous type, inclusive by default | Use habit colour as a soft card wash, not just a stroke. Keep AX5 and VoiceOver as launch features |
| Health and fitness paywalls | Trial timeline (today, reminder on day 5, billed on day 7), annual price shown per month, the user's own goals on the paywall, a visible way to cancel | Name the user's habits in the headline, add a free-vs-Pro table, show the timeline, and design a loading state |
| Liquid Glass guidance | Glass on the navigation layer only, grouped in one `GlassEffectContainer`, with consistent shapes | Already in DESIGN.md. Keep it, and keep cards solid |

## Design direction: quiet sky, warm nest

Keep everything DESIGN.md already gets right: one screen plus sheets, no guilt, glass only on navigation, SF Pro Rounded numbers. Change how it is expressed.

**The fledgling is the brand**

A vector `FledgeBird` drawn in SwiftUI, with poses for sitting, peeking, flying and sleeping. It replaces every `bird.fill`, in the app and in widgets.

**One hero per screen**

Today: the day's summary. Detail: today's number. Graduation: the bird. Everything else steps back.

**Numbers big, labels small**

Values in rounded 800 weight. Goals, units and sources in small secondary text.

**Colour means identity**

Habit colour runs through the ring, the card wash and the heatmap. The CTA is ink, links are skyText, gold is for flying.

**Every state has a shape**

Done: a full ring with a check badge, and the symbol stays. Rest: a soft moon badge. Ready: a gold edge and a button.

**Celebrate, quietly**

Feather burst on done, a flight path on graduation, a shareable recap card. Reduce Motion gets cross-fades.

### System changes in FledgeUI

- **Primary button:** an ink-filled capsule (white label, 14:1 contrast), light ink in dark mode, glass prominent on iOS 26. The current skyText fill competes with the Health colour.
- **Elevation:** one card shadow token (`y 1/6, blur 2/18, 5–6 %`) in light mode and a 1 pt hairline stroke in dark mode. Cards currently disappear on the cloud background.
- **Type ramp additions:** `metric` (title2, rounded, heavy, monospaced digits), `eyebrow` (caption2, semibold, tracked, uppercase), `meta` (caption, ink2).
- **Ring v2:** 72 pt on cards (up from 64). The symbol stays on done, with a corner badge for check, moon or heart. Rest becomes a soft full track with a moon badge, replacing the dashed stroke.
- **Components:** `FledgeBird`, `NestGlyph`, `WeekStrip`, `JourneyTrack` (milestones at day 1, 30 and 66), `IconSquare` (settings and template rows), `MetricText`, `FeatherBurst` (Canvas), `ShareRecapCard` (ImageRenderer).

ink · CTA, text

skyText · links

dawn · slot 1

sky · slot 2, Health

meadow · slot 3

gold · flying only

cloud · screen

## Proposed screens

HTML mockups at iPhone proportions, drawn from the app's own tokens. They follow your light or dark setting, so switch themes to check the dark variant.

9:41●●● ▮

Wednesday · 14 Oct

1 of 3 done

Walk is 1,790 steps away.

M

T

W

T

F

S

W

Walk

4,210 / 6,000 steps

✦ Ready to flyHealth · 4 min ago

Read

Done · 20 pages

Day 12 · flies from day 30

☾

Meditate

Rest day

1 rest day left in October

**Stretch flew** on 30 Sep after 67 days. See the Flown shelf ›

### Today: the nest

- The title is the day's status. The date becomes an eyebrow line.
- The nest glyph matches the small widget, so the app and Home Screen look alike.
- The week strip shows "progress, not perfection" at a glance. Rest days appear as open dots.
- Big numbers. The habit symbol stays on done, with a check badge and a soft colour wash.
- The Flown shelf preview fills the empty space with the reward, not with decoration.

9:41●●● ▮

Walk

Today

4,210

of 6,000 steps

♥ Apple Health · 4 min ago

**12**day streak

**21**best streak

**87%**last 30 days

#### Journey to fly

Day 1\
4 SepDay 30\
can flyDay 66\
automatic

Day 40 · 87% of the last 30 days. **Ready whenever you are.**

#### Last 12 weeks

donerest

JulAugSepOct

Let it fly

### Habit detail

- The hero is today's number, with the source and freshness under it.
- Stats move above the fold.
- "Journey to fly" replaces "Fledge progress": three labelled milestones, and the bird rides the line without overlapping it.
- The heatmap gets weekday and month labels, a legend and smaller cells.
- When the habit is ready, a gold "Let it fly" button is pinned to the bottom.

9:41●●● ▮

Add a habit

Free includes **one** Health habit, and you're using it on Walk. **Pro does all three ›**

Done for you · Apple Health

**Move**20 min a dayPRO

**Sleep**7 h a nightPRO

**Meditate**5 min a dayPRO

**Drink water**2 L a dayPRO

**Get daylight**20 min a day›

Tap to log

**Read**10 pages a day›

**Stretch**Once a day›

**Your own habit**Name, icon, goal›

### Add a habit

- Compact rows: all 11 templates and Custom fit on 1.3 screens instead of 3.
- One explanatory banner replaces 8 Pro and 8 Health badges. Small lock pills remain.
- Each template has its own colour in an icon square.
- Configure step (not shown): a live preview of the card at the top, so people see exactly what they'll get.

9:41●●● ▮

Day 40

Walk is ready to fly

It stuck. You don't need to watch it anymore.

**40**days

**87%**last 30 days

**21**best streak

Started 4 Sep · 6,000 steps a day

Let it fly

Keep it in the nestShare ↑

### Graduation

- The brand fledgling hops out of the ring, then flies along the dotted path on "Let it fly".
- A recap card shows days, rate, best streak and a 30-day strip.
- Share renders the recap as an image, at a 1080×1920 story size with the app name. This is free marketing during the January push.
- Reduce Motion: a cross-fade, with the same haptics.

9:41●●● ▮

Restore

Fledge Pro

Let Walk, Sleep and Meditate fill in by themselves

FreePro Habits from Apple Health13 Lock Screen, StandBy, all widgets–✓ App icons and CSV export–✓

*7 DAYS FREE***$19.99/yr**$1.67 a month

**$2.99/mo**Cancel anytime

**Today**Everything unlocks

**Day 5**We remind you the trial is ending

**Day 7**$19.99 is charged. Cancel before and pay nothing

Start 7-day free trial

Or $39.99 once, for life · Terms · Privacy

### Fledge Pro

- The headline names the habits the user picked.
- A three-row free-vs-Pro table, using the tier rules in `ProPolicy`.
- The trial timeline removes the fear of a surprise charge. The yearly plan shows its monthly price.
- Built on `SubscriptionStoreView` with a custom header and a `ProductView` skeleton while it loads.

9:41●●● ▮

Flown

2 habits flew

They keep tracking quietly. We'll nudge you only if one slips.

**Stretch**Flew 30 Sep · 67 days

**92%** holding

**Floss**Flew 2 Aug · 41 days

**71%** holding

The nest has room for one more.

### Flown shelf

- The header gives totals: how many flew and what they add up to.
- Each graduate is its own coloured fledgling, with a 14-day "holding" sparkline. Gold means 80% or more.
- Rows are tappable: open a mini detail with "Bring back to the nest".
- Empty state: the sleeping bird, with "Your first habit can fly from day 30."

### Also in scope (not drawn)

- **Onboarding:** screen 1 shows three rings filling one by one, then the fledgling hops out. A segmented progress bar and a back button replace the dots. The "pick" step uses the new rows with a sticky "2 of 3" bar whose mini rings fill as you choose. The widget step shows the real widget view, not a drawing.
- **Configure habit:** a live card preview at the top. Icon and colour pickers move into a compact sheet. The goal is a large number with −/+ instead of a list stepper.
- **Settings:** a Pro card at the top (bird and "Try 7 days free"), or a "Pro active" card. Rows get coloured icon squares in the iOS Settings style. Restore moves into About.
- **Widgets:** the same ring v2, badges and nest glyph. The fledgling appears in empty and all-done states ("Nest is quiet").
- **Motion:** on done, the ring closes, the check draws in and six feathers drift up 40 pt over 0.8 s, with `.success`. A partial log steps the ring forward with `.light`. Ready to fly pulses the gold edge once.

## Implementation plan

Ticket IDs continue the backlog's naming. The estimates are focused days for one developer. The work is UI-only: no schema changes and no write-API changes, and business logic stays in HabitCore under test.

**Phase 1**15–21 Oct · 2.5 d

- **UX-1 Tokens:** elevation, ink CTA (`FledgeButtonStyle`), type ramp (`metric`, `eyebrow`, `meta`). FledgeTheme.swift
- **UX-2 FledgeBird:** a SwiftUI `Shape` set in four poses, plus snapshot tests. Replace every `bird.fill`. FledgeUI, widgets
- **UX-3 Ring v2:** 72 pt, symbol persists, corner badges, soft rest state, Reduce Motion. HabitRing.swift
- **UX-4 Screenshot harness:** a script that captures every `-FledgeDemoScreen` in light and dark, at default and AX3 text sizes, for before/after review.

**Phase 2**22 Oct – 1 Nov · 4 d

- **UX-5 Today:** eyebrow and status title, `NestGlyph`, `WeekStrip` (needs a 7-day `WeekModel` in FledgeUI, tested), Flown shelf preview. TodayView.swift
- **UX-6 Card:** new hierarchy, done wash, "Health · 4 min ago" freshness, ready state with an inline button. AX layout kept. HabitCardView.swift
- **UX-7 Detail:** hero row, stats above the fold, `JourneyTrack`, labelled heatmap and legend, pinned "Let it fly". HabitDetailSheet.swift
- **UX-8 FeatherBurst:** Canvas particles on done, with a Reduce Motion variant.

**Phase 3**2–12 Nov · 3 d

- **UX-9 Add:** row list with `IconSquare`, one Pro banner, per-template colours. AddHabitSheet.swift
- **UX-10 Configure:** live card preview, large goal control, compact icon and colour sheet. HabitEditorView.swift
- **UX-11 Onboarding:** three-ring promise animation, progress bar and back button, sticky pick bar, real widget preview. OnboardingView.swift

**Phase 4**13–22 Nov · 3 d

- **UX-12 Graduation:** bird hops out of the ring, flight path, recap card. **UX-13 Share card** (`ImageRenderer` + `ShareLink`). GraduationView.swift
- **UX-14 Flown:** totals header, fledgling rows, 14-day holding sparkline (a `HoldingRate` model in HabitCore, tested), empty state. FlownSheet.swift
- **UX-15 Paywall:** personalised headline, comparison, trial timeline, loading skeleton. PaywallView.swift
- **UX-16 Settings:** Pro card, icon squares, Restore moved into About. SettingsSheet.swift

**Phase 5**23–29 Nov · 1.5 d

- **UX-17 Widgets:** ring v2, badges, bird in empty and all-done states. NestWidgets.swift
- **UX-18 Accessibility and QA:** VoiceOver labels for the new elements, AX5 layouts, contrast check of the ink CTA in both themes, Reduce Motion and Reduce Transparency.
- **UX-19 App Store screenshots:** regenerate from the harness, then REL-2.

### How we'll know it worked

- **Glance test:** 5 people shown Today for 3 seconds can say how many habits are done and which one is closest to flying.
- **Time to first habit** under 60 s in onboarding (unchanged target). Measure it on TestFlight.
- **Paywall:** trial start rate of at least 20% of installs (spec target). Compare the TestFlight cohorts once ANA-1 is decided.
- **Quality bar:** every screen passes light, dark, AX3 and AX5, VoiceOver and Reduce Motion in the harness before the freeze.

## Decisions and risks

- **Primary button colour:** ink (recommended: most legible, calmest) or dawn. Dawn with a white label is only 3:1, below AA, so it would need an ink label.
- **DEC-1, minimum iOS 26:** still open. The plan works on 18.6 with fallbacks. Moving to iOS 26 removes the fallback branches in UX-1 and UX-15.
- **Week strip:** read-only in 1.0 (recommended). Editing past days stays in the detail sheet.
- **Schedule risk:** about 14 days of UI work alongside HK-5, WID-5 and the release tasks. If it slips, cut in this order: UX-13 share card, then UX-14 sparkline, then UX-11 animation polish. Never cut: UX-2 bird, UX-5 and UX-6 Today, UX-15 paywall.

## Sources

- [MacStories: Streaks 3 review](https://www.macstories.net/reviews/streaks-3-review/) · [Daring Fireball on Streaks](https://daringfireball.net/linked/2024/november)
- [TapSmart: (Not Boring) Habits review](https://www.tapsmart.com/apps/review-not-boring-habits/) · [Behind the Design: (Not Boring) Habits](https://cur.at/wicwETc?m=web)
- [Gentler Streak on the App Store](https://apps.apple.com/us/app/gentler-streak-fitness-tracker/id1576857102) · [Sketch: designing Gentler Streak](https://go.sketch.com/blog/gentler-streak/) · [BGR: Gentler Streak redesign](https://bgr.com/tech/gentler-streak-gets-a-major-redesign-focused-on-your-wellbeing/)
- [Apple: 2026 Apple Design Awards](https://www.apple.com/newsroom/2026/06/apple-reveals-winners-of-the-2026-apple-design-awards/) · [9to5Mac: ADA 2026 finalists (Structured, Harvee)](https://9to5mac.com/2026/05/18/apple-unveils-30-apple-design-award-app-finalists/)
- [Best habit tracker for iPhone (2026)](https://habitdoom.com/blog/best-habit-tracker-iphone-2026) (written by a competitor) · [Toolfinder: habit trackers for iOS](https://toolfinder.com/best/habit-trackers-ios)
- [Effective paywall examples in health and fitness apps](https://paywallpro1.substack.com/p/effective-paywall-examples-in-health) · [Airbridge: onboarding before the paywall](https://www.airbridge.io/en/blog/5-steps-app-onboarding-before-the-paywall)
- [SwiftUI Liquid Glass guide](https://www.atelier-socle.com/en/articles/swiftui-liquid-glass-guide) · [Liquid Glass best practices](https://dev.to/diskcleankit/liquid-glass-in-swift-official-best-practices-for-ios-26-macos-tahoe-1coo)
- Repository: `docs/DESIGN.md`, `docs/SPEC.md`, `docs/BACKLOG.md`, and the screenshots in `Design/review/current/`