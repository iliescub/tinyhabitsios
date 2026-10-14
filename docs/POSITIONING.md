# Fledge 1.0: positioning and scope review (2026-10-14)

Visual version with the evidence tables: `Design/review/positioning.html` (published as an artifact).
Status: **accepted 2026-10-14; GRAD-3, HEAD-1 and GRAD-4 implemented the same day** (spec, design and brand docs updated).

## Finding
- **Not unique:** auto-completion from Apple Health (Streaks, Habitify, smaller apps) and a three-habit limit (common free-tier cap:
  TrackHabits, Habits/steps.app, Everyday; Habit3 by design).
- **Unique:** habits that **graduate** and leave the tracker; no app found does this (guides recommend it as a manual practice).
  Research backs it: Lally et al. (66 days average, 18–254; one missed day = small dip), Renfree et al. CHI 2016 (habit apps build
  dependency; quitting the app often means quitting the habit), CHI 2019 (reminders support repetition but hinder automaticity).
- **Positioning:** *Fledge is the habit tracker that lets go.* "Done for you" and "three" are the proof, not the headline.

## Scope change (before the 29 Nov freeze)
- **GRAD-3 (P0, 1d)** Slip check for flown Health habits: one notification when `HoldingRate` < 50% over 14 days, none again until
  ≥ 80%. The app already promises "We'll nudge you only if it slips" — build it or remove the line.
- **HEAD-1 (P0, 2d)** Health head start: read the last 30 days when a Health habit is added; show average and days met; suggest a
  goal just above baseline; flag "already a habit" when ≥ 80% met; pre-fill the heatmap as "before Fledge" (graduation still counts
  from the start date). Pure `BaselineModel` in HabitCore with tests.
- **GRAD-4 (P1, 0.5d)** Flight forecast on detail: "On track to fly around 12 Nov".
- **Not in 1.0:** AI coach, social/accountability, app blocking, more slots, Watch app (stays 1.1), Android.

## Messaging (MKT-6)
- Subtitle: **"Habits that stick, then fly"** (27) replaces "3 habits that track themselves". Alt: "The habit app that lets go".
- Promo text: "Most habit apps want you forever. Fledge fills in three habits from Apple Health and lets each one go once it sticks,
  about 66 days on average."
- Screenshots: graduation first, then Today, head start, Flown, widgets, privacy. New Year line: "This year, fewer habits. Then none to track."
- Channels: landing page headline + research piece; build-in-public pillars (science, design, numbers); featuring pitch "built to make
  itself unnecessary"; creator hook "the habit app that wants you to need it less"; #FledgeFlew share cards from late January.

## Price
Keep $19.99/yr (Streaks $5.99 once, Way of Life $29.99/yr, Atoms ~$39.99/yr, Habitify $49.99/yr) for January; test $24.99 from February.
