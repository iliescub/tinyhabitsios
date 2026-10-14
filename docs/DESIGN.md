# Fledge — Brand, UI and UX concept

Status: v1 concept, 2026-10-11 · Spec: https://claude.ai/code/artifact/3570cc79-5f90-4826-9950-d1f0ee305d54 (offline: `docs/SPEC.md`)
Icon sources: `Design/Icon/` · Tickets: `docs/BACKLOG.md` (DES-*)

The whole UI is built on one idea: **your three habits live in a nest, they fill up by themselves, and when they stick they fly.**
Every screen should be calm, native and readable at a glance. The interesting moments are completion (a soft fill + haptic)
and graduation (the habit becomes a bird and flies to the "Flown" shelf).

---

## 1. Research summary (what shaped this concept)

| Finding | Design consequence |
| --- | --- |
| iOS 26 introduced Liquid Glass; Apple reserves glass for the navigation layer floating above content, never for content itself, and never glass on glass ([guide](https://www.atelier-socle.com/en/articles/swiftui-liquid-glass-guide), [Firefox iOS 26 patterns](https://acorn.firefox.com/latest/mobile/patterns/i-os-26-and-liquid-glass-w2oH48nk)) | Content (habit cards) is solid and opaque; glass only on toolbar buttons, the floating "Add" button and sheets. Standard controls get glass automatically when built with Xcode 26 |
| iOS 26 icons are layered and render in 6 appearances: default, dark, clear light/dark, tinted light/dark; built in Icon Composer from one source ([Create with Swift](https://www.createwithswift.com/crafting-liquid-glass-app-icons-with-icon-composer/), [WWDC25-361](https://developer.apple.com/videos/play/wwdc2025/361)) | Icon is two layers (sky background + bird glyph), a bold silhouette with no text and no fine detail; dark and tinted variants pre-checked |
| Habit-app users get discouraged by rigid or over-gamified interfaces; "show progress, not perfection"; missed days shouldn't erase progress ([paper](https://publikasi.mercubuana.ac.id/index.php/collabits/article/view/35091), [case study](https://contra.com/p/NXqYrFRo-most-habit-apps-fail-not)) | No points, coins, levels or red failure states. Progress to graduation never resets because of a missed day; streaks are secondary |
| Onboarding is often cumbersome and notifications generic ([case study](https://contra.com/p/NXqYrFRo-most-habit-apps-fail-not)) | 4-screen onboarding, under 60 s; notifications only when a habit is still undone, written specifically |
| Recent award winners in this space (Tiimo — iPhone App of the Year 2025; Structured — ADA 2026 finalist) win on calm visual clarity and inclusion, not features ([Tiimo](https://www.tiimoapp.com/resource-hub/tiimo-winner-2025-app-store-awards), [ADA 2026](https://macdailynews.com/2026/06/02/apple-reveals-winners-of-the-2026-apple-design-awards/)) | Accessibility is a launch feature (Dynamic Type to AX5, VoiceOver, Reduce Motion), and a featuring argument |
| Finch already owns "cute bird pet you care for" | Our bird is **not a pet**: no feeding, no currency, no guilt. The bird appears only as the brand mark and as the reward when a habit graduates |

---

## 2. Marketing theme: "Leave the nest"

**Positioning line:** Three habits. Done for you. Then they fly.
**Campaign (New Year 2027):** *"This year, fewer habits."* Sub-line: *"Fledge tracks three habits from Apple Health — and lets them go once they stick."*

| Element | Choice |
| --- | --- |
| Story | Habits are fledglings: they need care for a while, then they don't. The app's job is to make itself unnecessary for each habit |
| Key visual | A small white bird on a dawn sky (blue → warm horizon). Lots of empty sky = calm, "less" |
| Tone of voice | Calm, warm, brief. Second person. Light bird metaphors only where they add meaning (nest, ready to fly, flown). Never guilt, never hype |
| Words we use | nest, ready to fly, flown, done for you, rest day, quietly |
| Words we avoid | crush, beast mode, fail, missed (as a label), streak broken, level up, coins |
| Differentiator to repeat everywhere | "Completes itself from Apple Health" + "Only three" + "No account. Your Health data stays on your iPhone." |

---

## 3. Brand identity

### 3.1 App icon
- **v2 (2026-10-14), concept "First flight": see `docs/BRAND.md`.** A round white fledgling, facing left, whose wing is a checkmark;
  the long stroke breaks out of the body, so the wing is lifting. Sky-to-dawn background; Night and tinted variants.
- Files: `Design/Icon/fledge-icon.svg` (layers `#background`, `#bird`, `#wing`), rendered PNGs, Icon Composer layers, mark and lockup.
  Regenerate: `swift Design/Icon/render-icon.swift Design/Icon`, then copy the icon PNGs into `AppIcon`, `AppIcon-Night` and `IconPreview-*`.
- Checked at 29–180 px and on the simulator Home Screen. Still to do (DES-2): build `Fledge.icon` in Icon Composer and test clear mode on a device.

### 3.2 Colour

Brand colours (sRGB hex), light and dark values. Contrast was computed (WCAG 2.x): text tokens meet AA (≥ 4.5:1);
graphic colours (rings, badges, chart cells) meet ≥ 3:1 against `card`. Brand colours are never used for body text — use `skyText` for links/tinted text.

| Token | Light | Dark | Contrast (light, vs white) | Use |
| --- | --- | --- | --- | --- |
| `sky` | `#4F8DFF` | `#6FA3FF` | 3.2 : 1 | Brand primary fill, rings, Health badge, icon background |
| `skyText` | `#2563D6` | `#8DB6FF` | 5.5 : 1 | Links, tinted text, prominent button fill (white label 5.5 : 1) |
| `dawn` | `#FF5F45` | `#FF8169` | 3.0 : 1 | Completion, checkmark wing, "done" accents |
| `gold` | `#D0830E` | `#FFC15E` | 3.0 : 1 | Graduation only ("ready to fly", Flown shelf). Icon beak uses the brighter `#FFB13D` |
| `meadow` | `#2CA874` | `#4CCB94` | 3.0 : 1 | Optional habit colour |
| `ink` | `#1B2240` | `#E9ECF8` | 14.3 : 1 | Primary text |
| `ink2` | `#5B6280` | `#A3A9C2` | 6.0 : 1 | Secondary text (7.1 : 1 in dark) |
| `cloud` | `#F7F5F2` | `#0E1120` | — | Screen background (warm off-white / deep night) |
| `card` | `#FFFFFF` | `#191D33` | — | Habit cards and sheet content |
| `hairline` | `#E6E2DC` | `#2A2F4A` | — | Separators, empty-slot dashes |

**Habit colours** (user picks one per habit; default per slot 1/2/3 = dawn, sky, meadow), all ≥ 3:1 on `card` in light mode:
dawn, sky, meadow, gold, lilac `#8E7CF0`, teal `#1EA4A9`, rose `#EF6396`, slate `#6B7A99`. Dark mode uses the lighter variants
(+12 % lightness). Rings use the habit colour; text never does.

**Sky header:** the top of the Today screen has a soft vertical gradient that follows the time of day
(dawn 05–10 h: `#FFE2CF→cloud`; day 10–17 h: `#DCE9FF→cloud`; dusk 17–21 h: `#E7DBFF→cloud`; night: `#1B2240→cloud(dark)`). It's the only decorative element.

### 3.3 Typography
- SF Pro (system) everywhere; **SF Pro Rounded** for numbers and large titles (`.fontDesign(.rounded)`), so progress feels soft.
- Scale (Dynamic Type styles, never fixed sizes): Large Title (screen title), Title 2 (habit name on detail), Headline (card title),
  Body, Subheadline (values), Footnote (meta), Caption 2 (widget labels). Numbers use `.monospacedDigit()`.

### 3.4 Shape, spacing, iconography
- Corner radius: cards 24, buttons capsule, chips capsule, sheets system. Spacing scale 4/8/12/16/24/32. Screen margins 20.
- Icons: SF Symbols only, hierarchical rendering. Health-sourced habits carry `heart.fill` mini-badge in `sky`; manual ones `hand.tap.fill`.
- Illustration: only the bird, in 4 poses (sitting, ready, flying, sleeping) as vector assets (DES-3). No stock photos (remove the Unsplash heroes).

### 3.5 Motion and haptics
| Moment | Motion | Haptic |
| --- | --- | --- |
| Progress updates | Ring fill, spring (response 0.5, damping 0.85) | none |
| Habit done | Ring closes, check draws in, 6 small feathers drift up 40 pt and fade (0.8 s) | `.success` |
| Partial log (+) | Ring steps forward | `.light` impact |
| Ready to fly | Gold glow pulses once on the card when it first appears | `.soft` |
| Graduation | Ring morphs into the bird (matched geometry), bird flies up-right off screen, lands on the Flown shelf | `.success` + `.rigid` on landing |
| Reduce Motion on | Cross-fades only, no flight; same haptics | — |

---

## 4. Platform and Liquid Glass rules

- **Recommendation: raise the minimum to iOS 26** (spec said iOS 18). Reasons: native Liquid Glass with no fallback design, one icon pipeline,
  `@Observable` + SwiftData fixes, and by December 2026 iOS 27 is current, so iOS 26+ should cover most active iPhones
  (check Apple's published adoption figures before deciding — decision DEC-1 in the backlog).
- Glass where: top toolbar buttons (Flown, Settings), the floating **Add habit** button when a slot is free, sheets, menus, the paywall close button.
- Never glass on: habit cards, rings, heatmap, onboarding body. One `GlassEffectContainer` for the toolbar group.
- Primary action = `.buttonStyle(.glassProminent)` tinted `skyText`; secondary = `.glass`.
- Respect Reduce Transparency (system handles glass; our gradient header falls back to flat `cloud`).

---

## 5. Information architecture

```
Today (the Nest) ─┬─ Habit card ─▶ Habit detail (sheet, large detent)
                  │                   ├─ Edit habit (push)
                  │                   └─ Pause / Delete (menu)
                  ├─ Empty slot / + ─▶ Add habit (sheet) ─▶ Configure (push) ─▶ Health permission (system)
                  ├─ "Ready to fly" ─▶ Graduation (full-screen cover) ─▶ Flown shelf
                  ├─ Toolbar: Flown ─▶ Flown shelf (sheet) ─▶ Graduate detail
                  └─ Toolbar: Settings ─▶ Settings (sheet) ─▶ Fledge Pro (paywall), Health access, Reminders, …
Onboarding (first run only): Promise → Pick up to 3 → Connect Health → Reminders + widget → Paywall (dismissible) → Today
```
One screen, no tab bar. Everything else is a sheet or a cover, so "back to Today" is always a swipe down.

---

## 6. Screens

### 6.1 Today — "The Nest"
Layout top to bottom:
1. **Sky header** (time-of-day gradient), large title = weekday + date ("Saturday, Dec 26"), subtitle = summary line.
   Summary copy: 0 done "Three in the nest." · 1–2 done "2 of 3 done. Walk is 1,800 steps away." · all done "All three done. Nest is quiet." · rest day "Rest day for Read."
2. **Three slot cards**, full width, stacked, 16 pt apart. No scrolling needed on any iPhone at default text size.
3. Floating glass **+ Add habit** (bottom centre) only when a slot is empty.
4. Toolbar (top right, glass): `bird` (Flown shelf, gold dot when something graduated recently), `gearshape` (Settings).

**Habit card anatomy** (height ~112 pt at default size):
```
┌──────────────────────────────────────────────────────┐
│  ◯ ring 64pt          Walk                ❤ Health   │
│  (symbol inside)      4,210 / 6,000 steps            │
│                       ▁▁▁▁▁▁▁▁▁▁▁▁▁▁  23 days to fly │
└──────────────────────────────────────────────────────┘
```
- Ring: habit colour, 8 pt stroke, track = colour at 15 %. Symbol in the centre (habit colour).
- Line 1: name (Headline). Badge right: `❤ Health` or `Tap` (Caption, ink2).
- Line 2: value / target with unit (Subheadline, rounded, monospaced digits). For manual 1-time habits: "Not yet" / "Done".
- Line 3: thin graduation progress bar (days active / 66, gold marker at day 30) + "23 days to fly" (Footnote).
- Interactions: tap card → detail. Tap the **ring** on a manual habit → done/undo (with haptic). Long-press ring → log amount / Skip today.
  Swipe actions: none (keep it calm). Auto habits: tapping the ring shows a small popover "Filled from Apple Health · updated 4 min ago · Mark done anyway".

**Card states**

| State | Visual |
| --- | --- |
| Pending, no progress | Empty ring track, value "0 / 6,000 steps" |
| In progress | Partial ring |
| Done | Full ring in habit colour, check replaces symbol for 1.5 s then symbol returns with filled background; value line "Done · 6,412 steps" |
| Skipped / rest day | Ring dashed, value "Rest day" (ink2). No red |
| Ready to fly | Gold outline on card (2 pt), chip "Ready to fly ✦" replaces line 3; tap chip → graduation |
| No Health data (3 days of zero by 6 pm) | Inline banner inside card: "Not seeing data? Check Health access" + button |
| Paused | Not on Today (lives in Settings › Paused habits) |
| Empty slot | Dashed outline (hairline), bird-sitting illustration small, "Add a habit" |

### 6.2 Habit detail (sheet)
- Hero: big ring 160 pt + today's value; under it the source line ("Completes from Apple Health · Steps").
- **Fledge progress**: horizontal track day 0 → 66 with gold tick at 30 ("can fly from day 30"), current position as small bird. Text: "Day 37 · 86 % of the last 30 days".
- **12-week heatmap** (7 rows × 12 columns), cells in habit colour by completion; rest days hatched; today outlined.
- Stats row (3 tiles): Current streak · Best streak · 30-day rate. Weekly-cadence habits show weeks.
- Settings rows: Target, Cadence, Reminder, Colour & symbol, Source. Footer menu: Pause, Delete (confirmation).

### 6.3 Add habit (sheet)
1. **Pick**: two sections. "Done for you" (Health templates: Walk, Move, Work out, Stand, Meditate, Sleep, Drink water, Daylight) and
   "Tap to log" (Read, Stretch, Custom). 2-column grid of tiles (symbol + name + "6,000 steps").
   Pro lock badge on Health tiles when the free auto slot is used.
2. **Configure** (push): name, symbol & colour, target stepper with unit, cadence (Every day / N days a week segmented), reminder toggle + time.
   CTA "Add to nest" (glass prominent). If a Health template: next step is the system Health prompt preceded by a one-line explanation.
- When 3 slots are full, "+" is hidden; Add is reachable only via pausing/graduating (copy: "Your nest holds three. Let one fly or pause one to add another.").

### 6.4 Graduation (full-screen cover)
- Background: sky gradient. The card's ring morphs into the bird (matched geometry), bird hops, then flies off on "Let it fly".
- Copy: "Walk is ready to fly." · "37 days · 86 % in the last 30 days." · Primary "Let it fly" · Secondary "Keep it in the nest for now".
- After flying: confetti-free; a quiet line "Flown habits keep tracking in the background. We'll nudge you only if it slips."

### 6.5 Flown shelf (sheet)
- Grid of graduates: small bird in habit colour, name, "Flew Jan 31 · 37 days", holding rate last 14 days (gold if ≥ 80 %).
- Empty state: sleeping bird, "Nothing has flown yet. Your first habit can fly from day 30."
- Tap → mini detail with "Bring back to the nest" (needs a free slot).

### 6.6 Onboarding (4 screens, paged, progress dots)
1. **Promise** — animated ring filling by itself → turns into the bird. "Three habits. Done for you. Then they fly." CTA "Start".
2. **Pick up to 3** — same tiles as Add habit, multi-select with a "2 of 3" counter; targets editable inline.
3. **Connect Apple Health** — shown only if a Health template is picked. Three bullets: reads only · stays on your iPhone · you choose what. CTA "Connect" → system sheet. "Not now" turns those habits manual.
4. **Reminders & widget** — notification toggle (optional) + 5 s looping video of adding the widget. CTA "Finish" → paywall (dismissible) → Today.

### 6.7 Fledge Pro (paywall)
- `SubscriptionStoreView` with a custom marketing header: bird in flight, title "Fledge Pro", three benefits with SF Symbols:
  "All three habits done for you" · "Lock Screen, StandBy & Control Center" · "Every icon and colour".
- Plans: yearly (default, "7 days free"), monthly, lifetime. Close button glass, top-left, always visible. Footer: Restore · Terms · Privacy.

### 6.8 Settings (sheet, inset grouped list)
Fledge Pro (status) · Appearance (accent, app icon: Dawn / Night / Mono) · Day ends at (3 AM) · Reminders & evening summary ·
Apple Health access (status + "Open Health") · Paused habits · Export CSV · Privacy · Help & feedback · About.

---

## 7. Outside the app

| Surface | Design |
| --- | --- |
| Small widget | Three rings in a triangle ("nest"), centre label "2/3". Tap manual ring → done (interactive). Background: `card` with a hint of sky gradient |
| Medium widget | Three rows like mini cards: ring 28 pt, name, value, check button for manual habits |
| Large / StandBy | Rings + "days to fly" per habit, big rounded numbers |
| Lock Screen circular | One habit's ring with its symbol (user picks the habit) |
| Lock Screen rectangular | Three mini rings + "2 of 3 · Walk 1.8k left" |
| Lock Screen inline | "2/3 · Walk 1.8k steps left" |
| Control Center | "Mark Read done" — symbol + habit name; state shows done |
| Siri / Shortcuts | "Mark meditate done in Fledge", "How are my habits in Fledge?" → spoken summary line |
| Notifications | One per habit at its time, only if still undone: "Read — still in the nest today. 10 minutes is enough." Evening summary (optional): "2 of 3 done. Walk needs 1,800 steps." Graduation: "Walk is ready to fly ✦" |
| Widget freshness | Caption "updated 14 min ago" when Health data is older than 30 min |

All widgets support tinted and clear Home Screen modes (`widgetAccentable` on rings, symbols as accented).

---

## 8. Accessibility and localization
- Dynamic Type up to AX5: cards switch to a vertical layout (ring above text) from `.accessibility1`.
- VoiceOver: each card is one element: "Walk, 4,210 of 6,000 steps, from Apple Health, 23 days to fly. Double-tap for details. Actions: Mark done, Log amount, Skip today."
- Colour is never the only signal: done = check + text; ready = gold + chip text; rest = dashed + text.
- Contrast AA for all text; rings ≥ 3:1 against card.
- Reduce Motion: no flight, cross-fades. Reduce Transparency: flat header.
- All strings in a String Catalog from day one (English at launch); numbers and units via `FormatStyle` / `Measurement`.

---

## 9. App Store screenshots (6, in this order)
1. Lock Screen with rectangular widget — "Your habits, done for you."
2. Today with a ring filling from Health — "Walk 6,000 steps. Logged by Apple Health."
3. Graduation — "When a habit sticks, it flies."
4. Privacy — "No account. Health data stays on your iPhone."
5. Widgets (Home + StandBy) — "Check in without opening the app."
6. Siri / Control Center — "Or just ask Siri."
Style: sky gradient background, device frame, caption in SF Pro Rounded Bold, ink text.

---

## 10. Implementation map (SwiftUI)

| Component | Notes | Ticket |
| --- | --- | --- |
| `FledgeTheme` (tokens: colours, radii, spacing, fonts) | ✅ In `Packages/HabitCore/Sources/FledgeUI` — colours defined in code with light/dark values so widgets share them | DES-1 |
| `HabitRing` | ✅ First version in FledgeUI (progress, rest-day dashes, done check); still to add: done animation, `widgetAccentable` | DES-4 |
| `HabitCard` | All states in 6.1; one accessibility element with custom actions | LOOP-1 |
| `SkyBackground` | ✅ In FledgeUI: time-of-day gradient, Reduce Transparency fallback | DES-5 |
| `FledgeProgressTrack` | Day 0–66 track with day-30 tick and bird marker | LOOP-5 |
| `HeatmapView` | 12×7 grid, rest-day hatching | LOOP-7 |
| `BirdView` | Vector bird in 4 poses + flight animation (matched geometry with ring) | DES-3 |
| `TemplateGrid` | Shared by onboarding and Add habit | ONB-1, LOOP-2 |
| Widgets | Reuse `HabitRing` | WID-2/3 |

Draft tokens (to put in `FledgeTheme.swift`; colours live in the asset catalog as `Brand/Sky` etc.):

```swift
enum FledgeTheme {
    enum Radius { static let card: CGFloat = 24; static let tile: CGFloat = 18 }
    enum Space { static let xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 12, l: CGFloat = 16, xl: CGFloat = 24, xxl: CGFloat = 32 }
    enum Ring { static let card: CGFloat = 64, detail: CGFloat = 160, widget: CGFloat = 28, stroke: CGFloat = 8 }
    static let screenMargin: CGFloat = 20
    static let habitColors = ["dawn", "sky", "meadow", "gold", "lilac", "teal", "rose", "slate"]
}
```

## 11. Mockups
HTML mockups of every screen and widget are produced in a cloud session from this file into `Design/mockups/`
(open `Design/mockups/index.html` in a browser). They are the visual reference for implementation; this document wins if they disagree.

## 12. iPad (native, added 2026-10-14)

**Concept: "the same nest, with room to look closer."** iPad keeps the one-screen idea: no tab bar, no sidebar of
categories (there are only three habits). What the extra width buys is that the *detail opens beside the nest instead of
over it*, so a check-in and a look at the history are one glance.

| Finding | Consequence |
| --- | --- |
| Apple doesn't require iPad support; iPhone-only apps run on iPad in a compatibility window. A native iPad app must ship a 13" screenshot set (2064 × 2752) ([guide](https://studio.adalo.com/blog/ipad-screenshot-sizes)) | Go native (better layout, iPad widgets); `scripts/appstore-screenshots.sh --ipad` makes the 13" set |
| iPadOS 26 deprecates `UIRequiresFullScreen`; apps must work in any window size ([TN3192](https://developer.apple.com/tutorials/data/documentation/technotes/tn3192-migrating-your-app-from-the-deprecated-uirequiresfullscreen-key.md)) | Layout follows available width, not device: split from 700 pt, iPhone layout below (Slide Over, narrow windows) |
| HealthKit exists on iPadOS 17+, but `isHealthDataAvailable()` can be false (some devices, managed iPads) ([forum](https://developer.apple.com/forums/thread/732944)) | When Health isn't available, Health templates become tap-to-log with a one-line note; copy says "this iPad", not "your iPhone" |
| iPad has an extra-large Home Screen widget, Lock Screen widgets and Control Center controls; StandBy is iPhone-only ([WidgetKit strategy](https://developer.apple.com/documentation/widgetkit/developing-a-widgetkit-strategy.md)) | Add `systemExtraLarge`: the three habits side by side; existing Lock Screen and control work unchanged |

**Layout (regular width ≥ 700 pt)**

```
┌──────────── nest column (360–420 pt) ───────────┬────────── detail pane (rest, content ≤ 680 pt) ──────────┐
│ WEDNESDAY · 14 OCT                    ◎◎        │  Walk                                         ⋯          │
│ 1 of 3 done                           ◎         │  ◯ 4,210 / 6,000 steps   ♥ Apple Health · 4 min ago       │
│ M T W T F S S  (week strip)                     │  [12 days] [21 days] [87%]                                │
│ ┃ Walk  ← selected (habit-colour edge)          │  Journey to fly ───●────○──────○                          │
│   Read                                          │  Last 12 weeks ▦▦▦▦▦▦▦▦▦▦▦▦                              │
│   Meditate                                      │                               [ Let it fly ]             │
│ Stretch flew on 30 Sep ›                        │                                                          │
└─────────────────────────────────────────────────┴──────────────────────────────────────────────────────────┘
```
- Tapping a card selects it (habit-colour edge); tapping its ring still checks in. The pane shows the same content as the
  iPhone detail sheet, with Edit / Pause / Delete in its header menu.
- Add, Flown, Settings and the paywall stay sheets (form sheets on iPad). Onboarding and graduation stay full screen with
  content capped at 600 pt wide, centred on the sky.
- Keyboard: ⌘N add a habit (when a slot is free), ⌘, Settings, ⌘1–3 select a habit. Cards get the pointer hover effect.
- Both orientations; Dynamic Type to AX5 falls back to the single column.
