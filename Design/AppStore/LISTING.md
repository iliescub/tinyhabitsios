# Yearling — App Store Connect listing (prepared 2026-11-02, not uploaded)

Everything below is local. Nothing has been sent to App Store Connect. Upload later with `scripts/asc.swift` (see "Before
uploading") or paste by hand. Concept: spec › "Update 2026-11-01"; words: `docs/BRAND.md` › v3; screens: `docs/DESIGN.md` §13.6.

## Text (en-US) — source: `metadata.en-US.json`

| Field | Value | Length |
| --- | --- | --- |
| Name (app info) | Yearling: Keep Your Resolution | 30 / 30 |
| Subtitle (app info) | One resolution. Three habits. | 29 / 30 |
| Promotional text | Make one resolution. Yearling turns it into three small habits with a plan, fills them in from Apple Health, and lets each one fly once it sticks. | 146 / 170 |
| Keywords | new year,goals,2027,fresh start,plan,apple health,sleep,steps,routine,focus,self improvement,kept | 97 / 100 |
| Description | in `metadata.en-US.json` | 2,555 / 4,000 |
| Support / marketing / privacy URLs | unchanged (GitHub Pages) | |
| Copyright | **change** "© 2026 HealthyLiving" → the seller's legal name (`Configuration/review-contact.json`) | |

Keywords leave out words already in the name and subtitle (Apple indexes those) and avoid "habit tracker" (4.3).

## Screenshots

iPhone 6.9" (1320 × 2868): `Design/AppStore/01…07-*.png` · iPad 13" (2064 × 2752): `Design/AppStore/iPad/01…07-*.png`.
Regenerate: `scripts/appstore-screenshots.sh [--no-build] [--ipad]` (demo data pinned to Friday 12 Feb 2027, US English).

| # | Screen | Headline | Subline |
| --- | --- | --- | --- |
| 1 | Today with the resolution card | One resolution. Three small habits. | Yearling turns your New Year's resolution into a plan you can keep. |
| 2 | Onboarding, "stop" reframed | Start something, don't just stop. | Resolutions about starting are kept more often. Yearling helps you phrase yours. |
| 3 | If-then plans | A plan for every habit. | "After lunch, walk." If-then plans make habits happen. |
| 4 | Health head start | Done for you, from Apple Health. | Habits fill in by themselves, starting from your own last 30 days. |
| 5 | Fresh-start card | A quiet week isn't the end. | No broken streaks. Monday is a fresh start, with smaller steps if you like. |
| 6 | Graduation | When a habit sticks, it flies. | When every habit has flown, your resolution is kept. |
| 7 | Widgets | Check in without opening the app. | Widgets for the Home Screen, Lock Screen and StandBy (iPad: Home Screen and Lock Screen). |

Known cosmetic issue: on iPad the simulator's status bar writes the weekday one day ahead ("Sat 12 Feb" while the app
says "Friday · Feb 12"); the iPhone status bar shows no date.

## App Review

- Notes: `review-notes.txt` (2,481 characters; opens with what changed since the 4.3 rejection and a 3-minute test path).
- Reply to the nine questions: `review-reply-4.3.md` — fill in the **[FILL IN]** parts (beta testing, Shapewright and
  Torn one-liners, WellFit's account) before sending.

## Before uploading (checked 2026-11-03)

Done in code: the letter and Kept moment are built (RES-6, RES-7); `asc.swift metadata` sets the **name**; the website
says Yearling; `Fledge.storekit` and `asc.swift` use "Yearling Pro"; `CURRENT_PROJECT_VERSION` is **4** in both targets.

Still to do, in this order (one app at a time from this account):
0. Commit and push `relaunch/v1`: the push publishes `website/` (the live privacy/terms/support pages still say Fledge
   until then, and App Review opens them).
1. Fill in the **[FILL IN]** parts of `review-reply-4.3.md`; fix the copyright in `Configuration/review-contact.json`,
   then `swift scripts/asc.swift review-contact`.
2. `swift scripts/asc.swift iap-rename` (store names of the group and all three products → "Yearling Pro"), then
   `iap-review` with the fresh `/tmp/fledge-paywall-review.png` from `testPaywallShowsPlansForAppReview`, then `iap-status`.
3. `metadata` → `screenshots` → `review-notes`.
4. `scripts/release.sh` (build 4) → `builds` until VALID → `attach-build 4`.
5. Reply to the nine questions in App Review, add the group and products to the draft on the website, `submit-prepare`,
   check App Review › Drafts, submit.
