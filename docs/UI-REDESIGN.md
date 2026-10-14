# Fledge UI/UX redesign plan (UX-*)

Status: proposal, 2026-10-14 · Visual version with mockups: `Design/review/redesign-plan.html` (published as an artifact; link in BACKLOG)
Before screenshots: `Design/review/current/` (simulator, demo data, iPhone 17). `docs/DESIGN.md` stays the source of truth;
this plan changes how it is expressed, not the concept (one screen + sheets, no guilt, glass only on navigation).

## Diagnosis (from the 0.1 build)
| # | Issue | Impact |
| --- | --- | --- |
| 1 | The brand fledgling (icon) never appears in the app; every bird is SF `bird.fill` (a hummingbird) | High |
| 2 | Today: lower ~45 % of the screen empty; the summary is small grey text | High |
| 3 | Cards: ring, value, source badge and flight track compete; value and goal share one style | High |
| 4 | Done replaces the habit symbol with a check; rest's dashed ring reads as loading; flight track unlabeled | High |
| 5 | Blue everywhere (CTA, Health labels, links), so it no longer marks the action | Medium |
| 6 | Add: 8 Pro and 8 Health badges for free users; manual habits and Custom are below the fold | High |
| 7 | Detail: "Fledge progress" jargon, bird overlaps the day-30 tick, unlabeled heatmap, stats below the fold | Medium |
| 8 | Graduation: stock bird, empty space, nothing to share | High |
| 9 | Flown: one tile on a blank sheet, no totals or holding rate | Medium |
| 10 | Paywall: stock layout, no comparison or trial timeline, no loading state | High |
| 11 | Onboarding: one ring on screen 1, dots only, no back button | Medium |
| 12 | Settings: the Pro row looks like any row; Restore is prominent for free users | Low |

## Research takeaways
- Streaks (ADA): big tappable circles, one gesture → make the ring the primary control, 72 pt.
- (Not Boring) Habits (ADA): completion as an event → feather burst + haptic on done.
- Gentler Streak (ADA 2024): rest is first-class, numbers shown simply → soft rest state, one summary sentence.
- Apple Fitness rings: one glyph for the day → `NestGlyph` (3 mini rings) in the Today header, same as the small widget.
- HabitKit: the grid is the identity → labeled heatmap, reused on the graduation recap and share card.
- Structured / Tiimo: soft colour, inclusive → habit-colour wash on cards; AX5 and VoiceOver as launch features.
- Health paywalls: trial timeline (today / reminder day 5 / billed day 7), annual shown per month, the user's own goals in the headline.

## Direction: "quiet sky, warm nest"
1. The fledgling is the brand: a vector `FledgeBird` (sitting, peeking, flying, sleeping) replaces every `bird.fill`.
2. One hero per screen. 3. Numbers big, labels small. 4. Colour means identity (habit colour = ring + wash + heatmap;
CTA = ink; links = skyText; gold = flying only). 5. Every state has a shape (badges: check, moon, heart). 6. Celebrate quietly.

FledgeUI changes: ink capsule primary button (glassProminent on iOS 26), one card elevation token (shadow in light,
hairline in dark), type ramp `metric` / `eyebrow` / `meta`, ring v2 (72 pt, symbol persists, corner badges, soft rest).
New components: `FledgeBird`, `NestGlyph`, `WeekStrip`, `JourneyTrack`, `IconSquare`, `MetricText`, `FeatherBurst`, `ShareRecapCard`.

## Tickets
UI only: no schema or write-API changes. New logic (week model, holding rate) goes in HabitCore/FledgeUI with tests.

### Phase 1: foundation (Oct 15–21, 2.5d) — ✅ done 2026-10-14
Notes: `FledgeBird` (FledgeUI) draws the mark in 4 poses + a one-colour glyph (`Image.fledgeGlyph`, `FledgeGlyphShape`);
SF `bird` stays only where the system needs a symbol name (App Shortcuts, Control Center). Ring v2 keeps the symbol and adds
badges (check, moon, heart) from 40 pt; smaller rings keep v1 behaviour. Screens: `Design/review/screens/phase1/index.html`.
- [x] **UX-1** ✅ Tokens: elevation, `FledgeButtonStyle` (ink CTA), type ramp
- [x] **UX-2** ✅ `FledgeBird` Shape in 4 poses + snapshot tests; replace every `bird.fill` (app + widgets)
- [x] **UX-3** ✅ `HabitRing` v2: 72 pt, symbol persists, corner badges, soft rest state, Reduce Motion
- [x] **UX-4** ✅ Screenshot harness: every `-FledgeDemoScreen` × light/dark × default/AX3 → `Design/review/`

### Phase 2: Today, card, detail (Oct 22 – Nov 1, 4d)
- [ ] **UX-5** Today: eyebrow date + status title, `NestGlyph`, `WeekStrip` (tested `WeekModel`), Flown shelf preview
- [ ] **UX-6** Card: new hierarchy, done wash, "Health · 4 min ago", ready state with an inline "Let it fly"
- [ ] **UX-7** Detail: hero row, stats above the fold, `JourneyTrack` (day 1 / 30 / 66), labeled heatmap + legend, pinned CTA
- [ ] **UX-8** `FeatherBurst` on done (Canvas) + Reduce Motion variant

### Phase 3: add and onboarding (Nov 2–12, 3d)
- [ ] **UX-9** Add: compact rows with `IconSquare`, one Pro banner, per-template colours
- [ ] **UX-10** Configure: live card preview, large goal control, compact icon/colour sheet
- [ ] **UX-11** Onboarding: three-ring promise animation, progress bar + back, sticky "2 of 3" bar, real widget preview

### Phase 4: rewards and money (Nov 13–22, 3d)
- [ ] **UX-12** Graduation: bird hops out of the ring, flight path, recap card (days, rate, best, 30-day strip)
- [ ] **UX-13** Share card: `ImageRenderer` 1080×1920 + `ShareLink`
- [ ] **UX-14** Flown: totals header, fledgling rows, 14-day holding sparkline (`HoldingRate` in HabitCore, tested), empty state
- [ ] **UX-15** Paywall: personalised headline, free-vs-Pro table, trial timeline, loading skeleton
- [ ] **UX-16** Settings: Pro card, icon squares, Restore moved into About

### Phase 5: surfaces and QA (Nov 23–29, 1.5d)
- [ ] **UX-17** Widgets: ring v2, badges, bird in empty/all-done states
- [ ] **UX-18** Accessibility pass: VoiceOver for new elements, AX5, contrast of the ink CTA, Reduce Motion/Transparency
- [ ] **UX-19** Regenerate App Store screenshots from the harness (feeds REL-2)

Cut order if late: UX-13 → UX-14 sparkline → UX-11 animation polish. Never cut: UX-2, UX-5/6, UX-15.

## Decisions needed
- Primary button: **ink** (recommended) or dawn (white label is only 3:1, so it would need an ink label).
- DEC-1 (iOS 26 minimum) is still open; the plan works on 18.6 with fallbacks.
- Week strip read-only in 1.0 (recommended).

## Success checks
3-second glance test (5 people can say how many habits are done and which is closest to flying) · first habit < 60 s ·
trial start ≥ 20 % of installs · every screen passes light/dark, AX3/AX5, VoiceOver and Reduce Motion before the freeze.
