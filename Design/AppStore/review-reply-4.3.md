# Reply to App Review: guidelines 4.3 and 4.2.6 (1.0 rejected, message received 2026-11-01)

Apple's message: if the app already complies, reply without resubmitting; otherwise don't resubmit until significant
changes are made. **We do the second:** build 4 changes the product (resolution layer, new name, new listing; spec section
"Update 2026-11-01"). When build 4 is submitted (RES-12), paste the answers below into the Resolution Center reply, and put a
shortened version at the top of `review-notes.txt`, so the reviewer of the new build sees them.

Before sending: fill in every **[FILL IN]**, and read it once as a stranger would. Plain facts only; no marketing language.

---

Hello, and thank you for the detailed questions. Since your message we have changed the app substantially. Version 1.0
(build 4) is now **Yearling**, a New Year's resolution app, rather than a general habit tracker. Answers below refer to that build.

**1. What the app does and the problem it solves.**
Most New Year's resolutions are abandoned within weeks. Common reasons are that the resolution is vague ("get healthier"),
framed as something to stop, and depends on daily manual logging that people give up on. Yearling turns one resolution into
at most three concrete daily habits, each with an if-then plan ("After lunch: walk 6,000 steps"). Habits that can be measured
by Apple Health (steps, exercise minutes, sleep, mindful minutes, water, daylight, workouts, stand hours) are completed
automatically from on-device Health data, so there is little to log. When the user's habit has been met on 80% of the last
30 days (from day 30), it "graduates" and leaves the daily list. When all habits of the resolution have graduated, the
resolution is marked as kept. If the user lapses, the app offers a fresh start on the next Monday or 1st of the month instead
of showing a broken streak. A letter the user writes to themselves at the start opens on December 1.

**2. Intended user.**
Adults who make a New Year's resolution about their health or routines (moving more, sleeping better, feeling calmer,
drinking more water, reading, spending evenings off the phone) and who have tried and dropped habit or goal apps before because
they became a chore. Many of them already carry an iPhone or wear an Apple Watch, so Apple Health has the data that completes
their habits. The app also suits people who restart a resolution later in the year (any Monday or 1st of the month).

**3. The gap it fills.**
Resolution apps on the App Store today are lists of goals with manual check-ins. Habit trackers are open-ended lists that
never finish. We found no app that (a) turns a resolution into a small, fixed set of habits with if-then plans, (b) completes
them from Apple Health, (c) graduates each habit out of the list once it has stuck, and (d) ends with the resolution being kept.
The design follows published research: if-then plans (Gollwitzer & Sheeran 2006), approach-framed resolutions succeeding more
often than avoidance-framed ones (Oscarsson et al. 2020, PLOS ONE), the "fresh start" effect (Dai, Milkman & Riis 2014), and
habit formation taking about 66 days on average (Lally et al. 2010). The app reframes "stop X" resolutions into "start Y" plans.

**4. Beta testing.**
**[FILL IN with real facts only: TestFlight dates and builds (0.1 (1) on 2026-10-11, 1.0 (2) and (3) on 2026-10-14, build 4),
number of testers, and two or three concrete pieces of feedback that changed the build.]** If there were few external
testers, say so and add what was tested: for example, daily use by the developer since October, the automated test suite
(about 130 unit tests, plus UI tests with Xcode's accessibility audit on iPhone and iPad), and real-device checks of Apple
Health and widgets. Example changes already made from testing that you can cite if true: the profile questions (name, age,
height, weight) were removed from onboarding; a 30-day Apple Health "head start" was added so the first goal matches the
user's real level; the app was rebuilt as one screen instead of four tabs.

**5. Standalone or suite?**
Standalone. The other apps on this developer account are unrelated products: **Listwell: Allergy List** (allergy lists),
**Tumbleland** (a game), **Duel at Dusk** (a game), **Shapewright** **[FILL IN: one line]**, and **Torn: Buy or Wait**
**[FILL IN: one line]**. None of them tracks habits, goals or Health data.

**6. Could it be an in-app purchase inside another app on the account?**
No. None of the other apps on this account deals with habits, resolutions or Apple Health, so there is no app it could be
added to. **[If WellFit (com.smartapps.HealthyLiving) is on this same account, say so here and explain: WellFit is a calorie
counter and gym plan app; Yearling has no food logging or training plans, and WellFit has no resolutions, habits, graduation
or Health auto-completion.]**

**7. Shared code, frameworks or assets with other apps on the account?**
No. Yearling's code was written for this app (repository started November 2025). It does not share source files, frameworks or
assets with the other apps on the account. It uses only Apple frameworks: SwiftUI, SwiftData, HealthKit, WidgetKit, App
Intents and StoreKit. The habit and resolution logic is in a local Swift package written for this app (HabitCore).

**8. Shared codebase, SDK or content library with any third-party app?**
No. There are no third-party SDKs or packages, no analytics, and no template. Everything beyond Apple's frameworks is
original to this app, including the resolution templates and their suggested habits.

**9. Built for a client or third party?**
No. I am the developer and the provider of the app's concept, content and branding, and I submit it under my own account. It
was not built from a commercial template or app generation service. **[Optional, if you want to be fully open: I write the
code myself in Xcode and use AI coding assistants as a development tool.]**

Thank you for your time. Health data never leaves the device, and every feature can be tested without Health data by
completing habits by hand.

---

## Fix before sending
- **Copyright** on the version currently reads "© 2026 HealthyLiving" (the folder name of another project, WellFit). Change
  it to the seller's legal name, e.g. "© 2026 Bogdan Iliescu", in `Configuration/review-contact.json`, then run
  `swift scripts/asc.swift review-contact`. A copyright that names a different product invites the 4.2.6 question.
- Submit only this app until it is through; keep Listwell and Tumbleland on hold.
