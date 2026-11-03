<!-- Offline copy of https://claude.ai/code/artifact/3570cc79-5f90-4826-9950-d1f0ee305d54 — the online doc is the source of truth. Exported 2026-11-02. -->

# Yearling (formerly Fledge) — Product Spec & Launch Roadmap

Oct 11, 2026 · @Bogdan · v2.0 spec (Yearling, 2026-11-02)

## Update 2026-11-01: rejected as spam, relaunching as a resolution app

Version 1.0 (build 3) was **rejected under guideline 4.3 (Spam)**. We answer by making the New Year's resolution the product, not a marketing line, and by renaming the app so the listing no longer reads as "another habit tracker".

**Status 2026-11-02:** the resolution layer, UI round 2 (UXR-1–8) and the on-screen rename to Yearling are built, code-reviewed (15 findings, all fixed) and tested: 188 package tests at 96.9 % line coverage, plus 16 UI tests with the accessibility audit. Nothing is committed or uploaded yet. Listing, screenshots and review notes are prepared locally (`Design/AppStore/LISTING.md`). Open: the nine-question reply facts, EUIPO check, copyright, in-app purchase names, device checks, build 4 (backlog › Start here).

- **What App Store Connect shows:** version 1.0 is `REJECTED`; the review submission is complete; all three in-app purchases are back to `READY_TO_SUBMIT`. Apple's message cites \*\*4.3(a), 4.3(b) and 4.2.6\*\* (apps built from a template or app generation service) together and asks nine questions. We resubmit only after the changes below and answer all nine; draft in \`Design/AppStore/review-reply-4.3.md\`.
- **4.3(b), shelf:** the app is "indistinguishable from what's already widely available". Our own October review already found that Health auto-completion and a three-habit limit exist elsewhere, and the title literally said *Habit Tracker*. This is the likely reason.
- **4.3(a), portfolio:** two other apps on the same account (*Listwell: Allergy List*, *Tumbleland*) were rejected in the same window. If the message cites 4.3(a), the reply must explain that they are unrelated products; from now on, submit one app at a time.
- **4.2.6, template:** our answer is factual: no third-party packages or SDKs, no code shared with the other apps on the account (checked file by file), repository started November 2025. One thing to fix: the version's copyright says "© 2026 HealthyLiving", the name of another project; it must be the seller's name.
- **What doesn't fix it:** a new screenshot order or a few features. Apple wants a different product a reviewer can name in one sentence. The engine (three slots, Health auto-fill, graduation) stays; the product around it changes.

### The concept: one resolution, kept by December

**One sentence for App Review:** *Yearling turns one New Year's resolution into up to three small daily habits, fills them in from Apple Health, and lets each habit graduate once it sticks, so by next December the resolution is kept, not still being tracked.*

- **The unit is a resolution, not a habit list.** You make one resolution a year ("Sleep better in 2027"). The app breaks it into at most three habits, each with an if-then plan.
- **It's built for the year, not for day 1.** A 365-day year map, a letter to your December self, and fresh starts on Mondays and on the 1st of each month when the resolution wobbles.
- **It ends.** When all of a resolution's habits have graduated, the resolution is **kept**: a Kept moment, a share card, and the year map fills in. Graduation, our one unique mechanic, now has a story to sit in.
- **It works after January.** Any Monday or 1st of the month counts as a fresh start, so the app isn't useful for one week a year only (a 4.2 risk).
- **What stays:** `SlotPolicy.maxActive` = 3, Health auto-completion, head start, graduation, widgets, no guilt, no account. **What doesn't come in:** AI coach, social feed, unlimited goals.

### Name: Yearling (chosen 2026-11-01; trademark check pending)

A **yearling** is a young animal in its first year. It names the niche (a year-long resolution) and carries the bird brand on: the fledgling icon, sky palette and "fly" language stay, so no new icon is needed.

| Option | App Store title (≤ 30) | Subtitle (≤ 30) | For | Against |
| --- | --- | --- | --- | --- |
| **Yearling** (recommended) | Yearling: Keep Your Resolution (30) | One resolution. Three habits. (29) | Says "year"; keeps the bird; no App Store app found with the name | Also a horse term. USPTO: no live YEARLING mark for software; live only for beer and a children's book imprint. EUIPO still to check by hand |
| Fledge, retitled | Fledge: New Year Resolutions (28) | Keep this year's resolution (27) | Cheapest; brand book and site stay | Name still says nothing about resolutions; same name as the rejected listing |
| Twelvemonth | Twelvemonth: Resolution Plan (28) | One resolution, kept all year (29) | Distinctive, literal | Long; loses the bird |

Ruled out: *Kept* ("Kept: Task & Habit Tracker" is live), *Resolve* ("Resolve AI" is live), *Resolutions 2027* (the template-app pattern 4.3 targets).

### Brand: the mark stays, the words change

The rejection was about the product, not the look, so the icon (fledgling with a checkmark wing on sky-to-dawn), palette and type stay. The dawn now also reads as the first morning of the year. Full table: `docs/BRAND.md` › *Yearling brand (v3)*.

| Item | Fledge (v2) | Yearling (v3) |
| --- | --- | --- |
| Promise | Three habits. Done for you. Then they fly. | One resolution. Kept by December. |
| Campaign | This year, fewer habits. | This year, one resolution. Kept. |
| Pillars | Few, Effortless, Kind, Private, Native | Few, Effortless, Kind (fresh starts, not failures), Private, Year-long |
| Gold | Flight only | Flight and Kept |
| Words | habit tracker, nest, fly | resolution, plan, fresh start, kept; nest and fly stay; never "habit tracker" |
| Lockup | Fledge wordmark | Yearling wordmark, same geometry (RES-10) |

Guardrail: "yearling" is also a horse word; the bird is the only mascot.

### Differentiators: what the research says, what we build

Resolution apps on the store today ([Resolutions 2026](https://apps.apple.com/us/app/-/id1601071354), [Resolutely](https://apps.apple.com/app/id6755164358), [Resolvd](https://apps.apple.com/us/app/-/id6757732276)) are lists of goals with check-ins and few ratings. None turns a resolution into specific habits, fills them in from Health, or ends when the resolution is kept. Each feature below comes from a finding about why resolutions fail.

| # | Finding | Feature | Effort |
| --- | --- | --- | --- |
| R1 | Vague intentions fail; most resolutions are about physical health, weight and eating ([Oscarsson et al. 2020](https://doaj.org/article/c741d032c14542baa884d5ad7369c2a5)) | **Resolution → habits.** Pick or type a resolution; resolution packs (Move more, Sleep better, Calmer mind, Drink more water, Read more, Evenings off the phone) suggest up to three habits, Health ones first. Built on the existing pack JSON | 1.5 d |
| R2 | Approach goals ("start X") succeed more than avoidance goals ("stop Y"): 58.9% vs 47.1% after a year (Oscarsson et al. 2020) | **Approach reframe.** "Stop scrolling in bed" → "Read 10 minutes in bed". Rule-based ("stop", "no", "less", "quit"), no AI | 0.5 d |
| R3 | If-then plans have a medium-to-large effect on reaching goals, d = 0.65 over 94 tests ([Gollwitzer & Sheeran 2006](https://www.academia.edu/55735607/Implementation_intentions_Strong_effects_of_simple_plans)) | **If-then plan per habit.** "After I pour my coffee, I'll stretch." Shown on the card and used as the reminder text | 1 d |
| R4 | People start goals more at temporal landmarks: new week, month, year ([Milkman, Dai & Riis](https://strategy-business.com/article/00266)) | **Fresh starts.** After a lapse (≤ 2 of the last 7 days met), no streak loss screen: offer a restart next Monday or on the 1st, optionally a smaller goal. Resolutions can start on any of these days, not only Jan 1 | 1.5 d |
| R5 | Motivation is the top reason resolutions fail; self-chosen, meaningful goals last longer ([2026 survey](https://www.accelerantresearch.com/articles/2026-new-years-resolutions-survey-results)) | **Letter to December.** At setup, write why this matters; the letter is sealed and opens on Dec 1 (or when the resolution is kept). On device only | 1 d |
| R6 | Habits take about 66 days on average (Lally et al. 2010); apps that never end build dependency (Renfree et al. 2016) | **Year map + Kept.** A 365-dot map of the resolution year; when every habit has flown, the resolution is kept: celebration, share card, a Kept shelf by year | 1.5 d |
| R7 | Many resolutions fail in the second or third week of January ([YouGov via iHeart](https://theriver1059.iheart.com/content/2026-01-12-most-common-reasons-new-years-resolutions-fail)) | **Wobble week.** One quiet check-in around Jan 8, 2027 ("Most resolutions wobble this week. Want the 2-minute version of each habit?") | 0.5 d |

Total: about **7.5 days**, plus 1.5 days for the rename and 1 day for listing and screenshots. Schema: `SchemaV2` adds a `Resolution` model (text, why, letter, year, startedAt, keptAt) and `Habit.cue`, through a migration stage; CloudKit rules unchanged; the letter is not Health data.

### UI/UX changes

The nest design (DESIGN.md) stays; the resolution sits on top of it. Onboarding guidance points the same way: reach the "aha" (your own Health data, your resolution as a plan) before any ask, keep it to five screens or fewer, and request permissions in context ([vp0](https://vp0.com/blogs/ios-onboarding-screen-design-that-actually-converts), [trysonar](https://trysonar.app/blog/app-onboarding-that-protects-day-1-retention.md)).

| Screen | Today (Fledge) | Resolution version |
| --- | --- | --- |
| Today header | Date + "2 of 3" | The resolution as a sentence ("In 2027 I'm sleeping better"), a thin year-map strip, "Day 12 of 365 · 1 habit flown" |
| Habit card | Name, ring, source | Same, plus the if-then line under the name ("After coffee") |
| Onboarding | Promise → pick 3 → Health → reminders → paywall | 1 Your resolution (pick or type; reframe offered) → 2 Your habits (suggested from the pack, Health head start shown here) → 3 If-then plans → 4 Letter to December (skippable) → 5 Health + notifications in context → closable paywall |
| Lapse | Streak quietly resets | Fresh-start card: "Monday is a fresh start. Same plan or a smaller one?" No red, no lost-streak number |
| Habit detail | Heatmap, flight forecast | Unchanged, plus which resolution it serves |
| Graduation | Habit flies, slot frees | Same; the last habit to fly triggers **Kept** |
| Kept (new) | — | Full-screen moment, year map, letter opens, share card "Resolution kept: Sleep better, 2027" |
| Flown shelf | Graduated habits | Grouped by resolution and year |
| Widgets | Rings, next graduation | Rings + resolution name; Lock Screen inline "Sleep better · day 12" |

**Copy rule:** the UI and the listing say *resolution*, *plan*, *kept*, never *habit tracker*. Habits stay the unit inside a resolution. Accessibility, Reduce Motion and Liquid Glass rules from DESIGN.md are unchanged; check the year map at AX5 and in both appearances.

### UI/UX research, round 2 (2026-11-02)

The biggest gains for a resolution app come from the moment of commitment and from the first week, not from more screens. Round 1 (October: Streaks, (Not Boring) Habits, Gentler Streak, HabitKit, Structured, Tiimo, paywalls) still holds; this round looked at Atoms, Fabulous, Duolingo, Finch, Daylio, the 2026 Apple Design Awards and the research behind letters to your future self.

| # | Change | Evidence | Where | Effort | Priority |
| --- | --- | --- | --- | --- | --- |
| UXR-1 | **Seal the plan.** The last onboarding step shows the resolution, its habits and their cues as one card; press and hold to seal it (the ring fills, haptic, then Today) | Fabulous ends onboarding with a signed commitment ([UX Bites](https://uxbites.beehiiv.com/p/ux-bites-13-amie-peanut)); Duolingo's "commit to my goal" wording beat "continue" ([Lenny's](https://lennysnewsletter.com/p/behind-the-product-duolingo-streaks)); Atoms' hold-to-complete is its most-praised moment ([review](https://world.hey.com/luke.sizmur/my-atoms-review-1f3bd5df)) | Onboarding, after the letter | 0.5 d | P0 |
| UXR-2 | **Protect the first week.** Days 1–7 show a "First week" row of 7 dots instead of the year strip, and each habit offers its smallest version ("2 minutes counts") | Duolingo: retention is most fragile in the first 7 days; the jump from day 1 to day 2 is the largest | Today header, card | 0.5 d | P0 |
| UXR-3 | **Never miss twice.** After one missed day: a calm line on the card, "Missed yesterday. Today keeps it on track." After a real lapse: the fresh-start card (RES-5) | Duolingo's Streak Freeze exists so one missed day doesn't erase the commitment ([Duolingo blog](https://blog.duolingo.com/how-duolingo-streak-builds-habit)); Gentler Streak treats rest as normal | Card, Today | 0.5 d | P0 |
| UXR-4 | **Your words everywhere.** The "why" sits under the resolution sentence on Today; the paywall headline names the resolution ("Keep *Sleep better* with all three filling in"); reminders use the cue ("After lunch: walk") | Personalization amplifies the effect of commitment cues (a 150-person experiment seen in search results, not yet verified; related: [Fabulous critique](https://www.thebehavioralscientist.com/articles/fabulous-app-product-critique-onboarding)); Finch: setting your own goals is its best decision ([WhistleOut](https://www.whistleout.com/CellPhones/Guides/finch-self-care-app-review)) | Today, paywall, notifications | 0.5 d | P0 |
| UXR-5 | **Your year, full screen.** Tap the strip to open a 12 × 31 grid of the year (one cell per day, month columns), scrubbable, with month totals | Daylio's Year in Pixels shows a year at a glance and is its paid hook ([Daylio](https://daylio.net/)); 2026 Design Award winners Moonlitt and Tide Guide are time charts with Liquid Glass and a sky palette ([Apple](https://www.apple.com/newsroom/2026/06/apple-reveals-winners-of-the-2026-apple-design-awards/)) | New sheet from the resolution card | 1 d | P1 |
| UXR-6 | **One quiet reminder a day per habit, at a steady time,** worded from the cue, and none once it's done; the wobble-week check-in is the only extra | Irritating notifications get apps deleted; adaptive timing doesn't reliably beat fixed times ([PLOS ONE](https://pmc.ncbi.nlm.nih.gov/articles/PMC5207732)) | Reminders | 0.5 d | P1 |
| UXR-7 | **The letter reads as a moment.** On Dec 1 (or Kept) it opens full screen, envelope first; share card optional | Writing to a future self increased exercise in the following days (Rutchick, Hershfield et al. 2018) | Letter sheet | 0.5 d | P1 |
| UXR-8 | **Never by colour alone.** Year strip and grid also differ by height or shape; support Increased Contrast | 2026 Inclusivity winner Guitar Wiz is cited for Dynamic Type, Increased Contrast and Differentiate Without Color | Strip, grid, rings | 0.5 d | P1 |
| UXR-9 | **On-device help for typed resolutions.** With Apple Intelligence available, suggest an approach version and cues for a custom resolution; rules stay the fallback | Apple's Foundation Models run on device with no data leaving it; Streaks and Stoic already use them ([BGR](https://bgr.com/1983216/apple-foundation-models-framework-available-apps)) | Onboarding steps 1 and 3 | 1 d | 1.1 |

Not taken: a pet or mascot to care for (Finch; our bird is a mark, not a pet), currencies or paid streak freezes (Duolingo; against "no points"), long quizzes before the paywall (Fabulous; critics say it filters users out). Status 2026-11-02: UXR-1, 3 and 4 built; UXR-2 built except the 2-minute version. UXR-1–4 fit before the Nov 20 submission; UXR-5–8 before the Nov 29 freeze if R2 is on time.

### Revised roadmap

Release stays **Dec 15**; the resolution build goes to review on **Nov 20**, which leaves two weeks for a second round before the Dec 4 deadline. Freeze stays Nov 29. Tickets: `docs/BACKLOG.md`, section *Resolution relaunch*.

| Dates | Milestone | Done when |
| --- | --- | --- |
| Nov 2–3 | **R0** Review + name | Rejection message read in App Store Connect; Resolution Center reply sent; name chosen; trademark + App Store name check |
| Nov 3–8 | **R1** Resolution core | `SchemaV2` + migration (`Resolution`, `Habit.cue`); resolution packs; onboarding steps 1–3; approach reframe; HabitCore tests |
| Nov 9–15 | **R2** The year | Year map, letter to December, fresh starts, Kept moment + share card, wobble-week check-in |
| Nov 16–20 | **R3** Rename + listing | Display name, widget and Siri copy, website, metadata, screenshots (iPhone + iPad), review notes; UI tests green on both; build 4 submitted Nov 20 |
| Nov 21 – Dec 4 | Review buffer | Fixes only; a second submission by Dec 4 if needed; release set to manual |
| Dec 15 | Release | Release; email the waitlist |
| Dec 26 – Jan 10 | New Year push | In-app Event "Your 2027 resolution", New Year offer, creator videos |
| Jan 8, 2027 | Wobble week | Check-in ships to users; build-in-public post on what the data shows |
| Jan–Feb | 1.1 | Watch app, iCloud sync (no Health values), a second resolution slot only if data asks for it |

**Cut order if R1–R2 slip:** wobble week → Kept share card → letter to December. **Never cut:** resolution → habits, if-then plans, fresh starts, the rename. Without those the listing is the same product that was rejected.

### Getting it approved

Reply first, then resubmit with a listing a reviewer can tell apart in five seconds. Reviewers read the metadata and first screenshot before opening the app ([ptkd](https://ptkd.com/journal/guideline-4-3-a-design-spam-for-ai-habit-trackers), [newly.app](https://newly.app/guides/guideline-4-3-spam-rejection)).

1. **Read the exact clause** in App Store Connect › App Review (Resolution Center). 4.3(a) → explain that Listwell, Tumbleland and this app are separate products with separate code. 4.3(b) → reply that a new version is coming that changes the product, not just the listing.
2. **Listing:** title *Yearling: Keep Your Resolution*; subtitle *One resolution. Three habits.*; keywords: resolution, new year, 2027, goals, fresh start, plan, kept, apple health, sleep, steps, routine, focus. No "habit tracker" in title or subtitle.
3. **Screenshots:** 1 the resolution as a plan with real sample data, 2 Health filling in a habit, 3 if-then plans, 4 the year map, 5 Kept, 6 widgets. No generic hero shot.
4. **Review notes** open with the one-sentence concept, then name what no other app does (resolution → habits from Health; graduation; Kept), how to reach each with `-FledgeDemoData`-style sample data in a release-safe demo, and that Health data never leaves the device.
5. **Submit one app at a time** from this account. Hold Listwell and Tumbleland until this one is through.
6. **If rejected again:** reply once with the evidence, then appeal to the App Review Board and request a Meet with Apple consultation. Don't create a new bundle ID or account for the same app.

## Executive summary

We relaunch the TinyHabits codebase as **Yearling, a New Year's resolution app**. You make one resolution; the app turns it into at most three small habits with if-then plans, fills them in from Apple Health wherever possible, and lets each habit graduate once it sticks. When every habit has flown, the resolution is **kept**. Release on the App Store by **mid-December 2026**, before the New Year peak. (Version 1.0 as a general habit tracker, "Fledge", was rejected under guideline 4.3 on 2026-11-01; see the update above.)

**Pitch:** *One resolution. Kept by December.*

**Name: Yearling** (was Fledge, renamed 2026-11-01). A yearling is a young animal in its first year: the resolution's year, and the fledgling grown up. App Store title: *Yearling: Keep Your Resolution*. Subtitle: *One resolution. Three habits.* Icon unchanged (the fledgling with a checkmark wing).

**Why this angle**

- A general habit tracker is a saturated category (and was rejected as one). A resolution app that ends when the resolution is kept is a product a reviewer can name in one sentence.
- Most resolutions fail for known reasons: vague goals, "stop" framing, no plan, and giving up after one bad week. Each has a feature: resolution → habits, approach reframe, if-then plans, fresh starts.
- People abandon habit apps because logging is a chore. Auto-completion removes most of it; widgets and the Lock Screen handle the rest.
- The engine (three slots, Health auto-fill, graduation, widgets) is built and tested; the resolution layer sits on top of it.

**What it is not:** a list of goals, a coach, a social network, a journal or a to-do list.

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

The 1.0 audience is iPhone owners making a New Year's resolution about their health or routines, most of whom have dropped a habit or goal app before. Many already have data flowing into Apple Health.

| Persona | Situation | What they want | How the app fits |
| --- | --- | --- | --- |
| **The resolver** (primary) | Downloads between Dec 26 and Jan 10 with one resolution in mind | A plan that survives February | One resolution → three habits with if-then plans; under 2 minutes to set up |
| **The relapser** | Has tried 2+ habit apps and quit around week 3 | Something that doesn't feel like homework | Health auto-fill, no guilt, fresh starts instead of broken streaks |
| **The quantified-lite** | Wears an Apple Watch and checks the Activity rings | Habits that ride on data they already produce | Steps, exercise, sleep and mindful minutes complete on their own |
| **The restarter** | Starts later in the year: a birthday, a Monday, the 1st of a month | A fresh start that counts | Any landmark day starts a resolution; November and December starts are a head start on next year |

**Niche personas to watch for in usage data (Option B):** GLP-1 medication users, new parents, people with ADHD, desk workers, people in rehab or physio. Section *Option B* covers how to evaluate them.

## Product principles

When a feature request conflicts with one of these principles, the principle wins.

1. **One resolution, three habits.** One resolution at a time, never more than 3 active habits, and no paid tier that unlocks more.
2. **The best check-in is none.** If a habit can be measured, measure it. Manual taps are the fallback.
3. **Plans, not intentions.** Every habit gets an "after X" cue; "stop" resolutions are offered a "start" version.
4. **Fresh starts, not failures.** No red, no broken-streak screens. A lapse is answered with the next Monday or 1st of the month.
5. **Graduate, don't grind.** Habits fly once they stick; the resolution is kept when they all have. Celebrate that more than streaks.
6. **Outside the app first.** Widgets and the Lock Screen come first; a session in the app takes under 5 seconds.
7. **Private and native.** No account; Health data, the resolution and the letter stay on the device. System fonts, SF Symbols, Liquid Glass only on navigation.

## Brand and UI concept

The mark stays and the words change (brand v3, `docs/BRAND.md`). The resolution grows up over one year; its habits are fledglings that fly one by one until it's kept. One calm screen (Today) plus sheets, Liquid Glass on the navigation layer only. Full concept, palette, components and copy in `docs/DESIGN.md` in the repository.

&#91;image: Fledge app icon: a white fledgling with a checkmark wing on a sky-to-dawn gradient\]

**Icon:** a round white fledgling whose wing is a checkmark, so "done" becomes flight. It sits on a sky-to-dawn gradient with a gold beak. It has two layers for Icon Composer, and the dark and tinted variants were checked at 120 and 180 px. Source files are in `Design/Icon/`.

### Marketing theme

| Element | Choice |
| --- | --- |
| Positioning line | One resolution. Kept by December. (was: Three habits. Done for you. Then they fly.) |
| New Year campaign | "This year, one resolution. Kept." |
| Key visual | A small white bird on a wide dawn sky; lots of empty space to signal "less" |
| Voice | Calm, warm, brief. Light bird metaphors (nest, ready to fly, flown). No guilt, no hype |
| Avoided words | crush, fail, missed (as a label), streak broken, level up, coins, habit tracker |
| Versus Finch | Our bird is not a pet: no feeding, no currency. It appears only as the brand mark and as the graduation reward |

### Visual system

| Token | Light | Dark | Role |
| --- | --- | --- | --- |
| sky | #4F8DFF | #6FA3FF | Brand, rings, Health badge |
| skyText | #2563D6 | #8DB6FF | Links and prominent buttons (5.5:1 contrast) |
| dawn | #FF5F45 | #FF8169 | Completion |
| gold | #D0830E | #FFC15E | Graduation and Kept only |
| ink / ink2 | #1B2240 / #5B6280 | #E9ECF8 / #A3A9C2 | Text (14.3:1 and 6.0:1) |
| cloud / card | #F7F5F2 / #FFFFFF | #0E1120 / #191D33 | Backgrounds |

Brand colours are used for fills and rings at 3:1 contrast or better, never for body text. Type is SF Pro, with SF Pro Rounded for numbers and titles, and Dynamic Type throughout. Cards have a 24 pt radius, and rings are 64 pt on cards, 160 pt on detail and 28 pt in widgets. The only decoration is a sky header whose gradient follows the time of day.

### Screens

- **Today (the Nest):** the resolution card (sentence, "Day 12 of 365", year strip; a 7-dot first week on days 1–7) above three full-width habit cards. Each has a ring, the name, its "after X" cue, the value against the target, a Health or Tap badge, and a thin "days to fly" track. Card states are pending, in progress, done, rest day, ready to fly (gold), no Health data and empty slot. There is no red anywhere. A glass toolbar opens Flown and Settings, and a floating Add button appears only when a slot is free.
- **Habit detail (sheet):** a 160 pt ring, a Fledge progress track from day 0 to 66 with a tick at day 30, a 12-week heatmap, streak and rate tiles, and the habit's settings.
- **Add habit:** templates grouped into "Done for you" (Health) and "Tap to log", followed by a configure step.
- **Graduation (full-screen cover):** the ring morphs into a bird, which flies to the **Flown** shelf when the user taps "Let it fly".
- **Onboarding (resolution → habits → cues → letter → Health → reminders → seal), Kept moment, letter, year sheet, paywall and settings:** as described in the earlier sections, restyled with the bird and the sky.
- **Outside the app:** a small widget with three rings arranged as a nest, a medium widget with three rows, Lock Screen widgets, a Control Center control, Siri phrases, and reminders sent only when a habit is still undone.
- **Accessibility at launch:** Dynamic Type up to AX5 (cards switch to a vertical layout), one VoiceOver element per card with custom actions, Reduce Motion without the flight, and colour never as the only signal.

&#91;embedded content: screen map · 1 screen, 9 sheets and covers\]

There is no tab bar. Swiping down always returns to Today, and graduation always ends on the Flown shelf.

**Platform decision (DEC-1):** we recommend raising the minimum to **iOS 26**, from iOS 18 in the architecture table below. This gives native Liquid Glass without a fallback design and a single icon pipeline. Confirm with Apple's published adoption figures before switching.

**Mockups:** HTML mockups of every screen, state and widget, the bird in 4 poses, and App Store screenshot templates are being produced in a Claude cloud session into `Design/` (a pull request into `relaunch/v1`).

## Core loop: 3 slots, check-ins and graduation

A resolution owns up to three habits, one per slot (spec section "Update 2026-11-01"; \`Resolution\` in SchemaV2). The app has three slots. Each holds one active habit, which moves through four states: **active**, **ready to graduate**, **graduated** and **paused**. The Today screen shows the resolution card (sentence, day of the year, year strip) and the three slots.

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
- Graduated habits keep tracking quietly (auto habits at no cost). If one drops below 50% over 14 days, the app sends a single gentle nudge offering to bring it back to a slot.

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

Onboarding takes about two minutes and asks for nothing the app doesn't use. It ends with a commitment, then the paywall (closable).

### Onboarding: resolution to commitment

1. **Your resolution:** pick one of seven common resolutions or type your own. A typed one is matched to a template; "stop X" wording gets a "start" suggestion (RES-2/3). Built.
2. **Your habits:** the template's habits are pre-picked (within the free tier's one Health habit); the rest of the library sits below. Built.
3. **When will you do it?** An "after X" cue per habit, prefilled from the template, with a menu of everyday cues (RES-4). Built.
4. **A note to December:** why it matters, and a letter sealed until 1 December or the day the resolution is kept; skippable (RES-6). Built.
5. **Connect Health:** only if a Health habit was picked; shows the 30-day head start (HEAD-1). Built.
6. **Reminders + widget,** then **Seal the plan:** one card with the resolution, habits and cues; press and hold to commit (UXR-1). Then the paywall. Built.

### Reminders

- One optional reminder per habit at a steady time, worded from its cue ("After lunch: walk"). Scheduled only if the habit isn't done, removed as soon as it is (UXR-6).
- An optional evening summary: "2 of 3 done. Walk needs 1,800 steps." Not sent if all 3 are done.
- Resolution moments, at most one each: the wobble-week check-in (second Friday of January), a fresh-start offer after a lapse, and the letter on 1 December.

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
| Lock Screen widgets (Control Center and Siri are free: a control can't switch on Pro, and a dead toggle would hurt reviews) | — | ✓ |
| App icons, accent colours | 1 | All |
| CSV export; iCloud sync (1.1) | — | ✓ |
| Niche packs (Option B, later) | — | ✓ |

**Starting prices, to test later:** $2.99/month · $19.99/year with a 7-day trial · $39.99 lifetime. Check competitors' current prices before launch, and run a New Year offer (e.g. 40% off the annual plan from Dec 26 to Jan 10).

**Paywall placement:** at the end of onboarding (can be closed), when the user adds a second auto habit, when they tap a Pro widget, and once from the first graduation celebration. Never on launch.

**Implementation:** native StoreKit 2 with `SubscriptionStoreView`, so no third-party SDK is needed. Entitlements are checked through `Transaction.currentEntitlements`, and the Pro flag is cached in the App Group so widgets can read it. Revisit RevenueCat only if paywall A/B testing becomes a priority.

## Option B: niche packs

Option B is built into 1.0 as a data structure, not as a feature. Every template belongs to a **pack**, and 1.0 ships only the "Essentials" pack. On February 15, 2027 we choose one niche from the usage data. That niche either becomes a paid pack inside the app or, if it performs strongly, its own App Store listing built from the same codebase.

**Update 2026-11-01:** resolution templates (`Resources/Resolutions/resolutions.json`) are now the first-class packs: each is a resolution with up to three habits and suggested cues. The niche decision on February 15 becomes "which resolutions people actually make"; the same scoring applies.

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
| Minimum iOS version | 18.0 | Needed for Control Center controls. DEC-1 proposes iOS 26 for native Liquid Glass (see Brand and UI concept) |
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

**SchemaV2 (2026-11-01, built):** adds `Resolution` (text, templateID, why, letter, year, startDayKey, state active/kept/archived, keptAt, freshStartDayKey) and gives `Habit` a `cue` and a `resolutionID`. V1 → V2 is a lightweight migration, tested on a real store file. Logic: `ResolutionYear`, `FreshStart`, `ResolutionFraming`, `YearMap`, `KeptCheck`, `ResolutionLibrary` in HabitCore.

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

M0–M4 and the UI redesign were built by 2026-10-14; the chart below is that original plan. After the 4.3 rejection, the remaining work is the resolution relaunch (R0–R3) and UI round 2. Build 4 goes to review on **Nov 20**; freeze Nov 29; release Dec 15.

&#91;embedded content: relaunch roadmap · 5 build milestones, beta, 3 gates\]

Milestones overlap because the work is sequential in logic but parallel in practice. For example, the Health sources (M2) can be built while the Today screen (M1) is still being styled.

| Milestone | Dates | Done when |
| --- | --- | --- |
| M0–M4, UX redesign | Oct 11–14 (done) | Core loop, Health, widgets, intents, onboarding, paywall, iPad; 1.0 (3) submitted, rejected 4.3 |
| R0 Review + name | Nov 1–3 | Rejection read, nine answers drafted, Yearling chosen, US trademark checked (done); EUIPO and copyright to do |
| R1 Resolution core | Nov 1–8 | SchemaV2 + migration, templates, reframe, onboarding steps 1–4, Today resolution card (done) |
| R2 The year + UI round 2 | Nov 9–15 | Seal the plan, first week, never miss twice, your words, fresh-start card, Kept, letter opening |
| R3 Rename + listing | Nov 16–20 | Yearling everywhere, website, metadata, screenshots, review notes and the nine answers; build 4 submitted |
| Review buffer | Nov 21 – Dec 4 | Fixes only; UXR-5–8 if R2 is on time; second submission by Dec 4 if needed |
| Release | Dec 15 | Manual release; New Year push Dec 26 – Jan 15 |
| 1.1 | Jan–Feb 2027 | Watch app, iCloud sync (no Health values), on-device suggestions (UXR-9) |

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

- **Title:** `Yearling: Keep Your Resolution` (30). **Subtitle:** "One resolution. Three habits." Never "habit tracker" in title or subtitle (4.3).
- **Promotional text:** "Make one resolution. Yearling turns it into three small habits, fills them in from Apple Health, and lets each one fly once it sticks."
- **Keywords to target:** resolution, new year, 2027, goals, fresh start, plan, kept, apple health, sleep, steps, routine, focus.
- **Screenshots in this order:** the resolution as a plan → Health filling in a habit → if-then plans → the year strip → Kept → widgets (`Design/AppStore/`).
- **In-app Event:** "Your 2027 resolution" from Dec 26 to Jan 10. **Rating prompt** only after the 7th completed day or the first graduation.

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
| "Tiny Habits" trademark conflict (BJ Fogg) | Medium | Forced rename after launch | Resolved: renamed to Fledge, then Yearling (US search clear for software). Still to do: App Store Connect reservation and USPTO + EUIPO search |
| HealthKit data is missing or late | Medium | "Done for you" feels broken | Show when data was last updated, offer manual fallback during setup, show the no-data banner |
| Background delivery is throttled | Medium | Widget looks stale | Show a timestamp on widgets; refresh when the app opens; don't promise real-time updates |
| Health data in iCloud breaks the rules | Low (1.1) | Rejection of the sync update | Sync only definitions and done/skipped flags |
| No distribution traction | Medium | Few downloads despite a good product | Start building in public and creator outreach now, not at launch |
| Burnout from building and marketing alone | Medium | Quality drops | Fixed scope, a weekly review every Sunday, no new features after Nov 29 |
| Second 4.3 rejection | Medium | Misses the New Year window | Ship the resolution layer, not just a rename; answer all nine questions with facts; fix the copyright; one submission at a time; App Review Board appeal + Meet with Apple if rejected again |

### Decisions needed this week

- [x] **App name:** Yearling (2026-11-01). US trademark search clear for software; EUIPO check by hand still open.
- [x] **Free tier:** 1 auto habit (built).
- [x] **Prices:** $19.99/year, $2.99/month, $39.99 lifetime (built; test $24.99 from February).
- [ ] **Analytics:** TelemetryDeck or none.
- [ ] **Version copyright:** replace "© 2026 HealthyLiving" with the seller's name before build 4.

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

* Design research (search results, not independently verified): [SwiftUI Liquid Glass guide](https://www.atelier-socle.com/en/articles/swiftui-liquid-glass-guide) (glass only on the navigation layer), [Crafting Liquid Glass icons with Icon Composer](https://www.createwithswift.com/crafting-liquid-glass-app-icons-with-icon-composer/), [WWDC25 session 361](https://developer.apple.com/videos/play/wwdc2025/361), [habit tracker UI/UX paper](https://publikasi.mercubuana.ac.id/index.php/collabits/article/view/35091), [Tiimo, App Store Awards 2025](https://www.tiimoapp.com/resource-hub/tiimo-winner-2025-app-store-awards).

- Resolution relaunch (2026-11-01): [App Review Guidelines 4.2 and 4.3](https://developer.apple.com/app-store/review/guidelines/); [newly.app on 4.3(a) vs 4.3(b)](https://newly.app/guides/guideline-4-3-spam-rejection); [ptkd on 4.3 for habit trackers](https://ptkd.com/journal/guideline-4-3-a-design-spam-for-ai-habit-trackers); [MacRumors, June 2026 guideline update](https://www.macrumors.com/2026/06/09/app-store-guidelines-low-quality-apps/); [Oscarsson et al. 2020, PLOS ONE](https://doaj.org/article/c741d032c14542baa884d5ad7369c2a5); [Gollwitzer & Sheeran 2006](https://www.academia.edu/55735607/Implementation_intentions_Strong_effects_of_simple_plans); [Milkman on the fresh start effect](https://strategy-business.com/article/00266); [2026 resolutions survey](https://www.accelerantresearch.com/articles/2026-new-years-resolutions-survey-results); [Kept: Task & Habit Tracker](https://apps.apple.com/gb/app/id6760225477); [Resolve AI](https://apps.apple.com/us/app/resolve-ai/id6739989938).
