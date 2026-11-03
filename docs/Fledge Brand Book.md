> **Superseded in part, 2026-11-02:** the app is now **Yearling** (resolution relaunch). The mark, icon, colours and type below stay; the name, promise ("One resolution. Kept by December."), pillars (Year-long replaces Native), voice and campaign are in `docs/BRAND.md` › "Yearling brand (v3)".

![The Fledge app icon: a round white bird with a coral checkmark wing on a sky-to-dawn gradient](brand-assets/fledge-icon-1024.png)

Brand concept · v2 · October 2026

# Fledge

First flight: done becomes flight.

Habits are fledglings. Fledge looks after three at a time, does the tracking for you, and lets each one go once it can fly on its own. Most habit apps celebrate the grind. Fledge celebrates letting go.

The idea

## The checkmark is the wing

One shape carries the whole product story. A completed habit gets a check. In Fledge, that check is the bird's wing, and its long stroke breaks out of the body because the wing is already lifting.

**Done**The universal mark of a finished task

**Becomes a wing**Placed on the fledgling, the check reads as a wing

**Then flight**When the habit sticks, it flies and frees a slot

Pillars

## Five things Fledge always is

**Few**Three habits, never thirty. The nest motif has exactly three arcs.

**Effortless**Apple Health does the logging. Rings fill by themselves.

**Kind**Rest is fine. No red, no "streak broken", no guilt.

**Private**No account. Health data stays on the iPhone.

**Native**Feels like Apple made it: SF Pro Rounded, glass only on navigation.

Personality

## A calm friend who is proud when you need them less

| Fledge is | Fledge is not | Sounds like |
| --- | --- | --- |
| **Calm** | Sleepy or vague | "All three done. Nest is quiet." |
| **Warm** | Cute or babyish. It is not a pet | "Read is still in the nest today. 10 minutes is enough." |
| **Confident** | Pushy or hype | "Walk is ready to fly." |
| **Light** | Childish | "Rest day for Meditate." |
| **Proud of you** | Proud of itself | "It stuck. You don't need to watch it anymore." |

The mark

## The Fledgling

- **Facing left, on purpose.** The checkmark must stay a true checkmark, with the long stroke rising to the right. With the bird facing left, that stroke is a wing raised behind it as it takes off.
- **Four elements only:** white body, coral wing, gold beak, ink eye. No outline, no gradient, no limbs, no expressions.
- **Clear space:** half a body radius on every side (outer dashed circle).
- **Minimum size:** 16 px for the mark, 29 pt for the icon. Both are checked.
- **Never** use SF Symbols' `bird` or `bird.fill` in its place. That one is a hummingbird.

✕ Mirror it. The check stops being a check.

✕ Rotate it. Only the flying pose tilts, by 12°.

✕ Recolour the wing. Coral means done.

✕ Make it a mascot. No legs, glasses or faces.

App icon

## Three appearances, one silhouette

![Default Dawn icon](brand-assets/fledge-icon-1024.png)

**Dawn**Default. Sky to horizon gradient

![Dark Night icon](brand-assets/fledge-icon-dark-1024.png)

**Night**Dark mode, and the Pro alternate icon

![Tinted icon](brand-assets/fledge-icon-tinted-1024.png)

**Tinted**The system tints it by luminance

### Legible down to Spotlight size

![](brand-assets/fledge-icon-1024.png)120

![](brand-assets/fledge-icon-1024.png)76

![](brand-assets/fledge-icon-1024.png)60

![](brand-assets/fledge-icon-1024.png)40

![](brand-assets/fledge-icon-1024.png)29

![](brand-assets/fledge-icon-dark-1024.png)60

![](brand-assets/fledge-icon-dark-1024.png)29

![Simulator Home Screen with the Fledge icon among other apps](brand-assets/home.jpg)

### On a real Home Screen

iPhone 17 simulator, iOS 27. Among busy, glossy icons, the white disc on open sky is the calmest shape on the screen and still the easiest to find. That suits a brand built on "fewer".

**Icon Composer:** three layers (sky, bird, wing). Liquid Glass with specular on the bird and wing, with the wing on top so it lifts off the body in clear and tinted modes.

Wordmark and lockup

## Fledge, set in SF Pro Rounded Bold

Fledge

Fledge

Sentence case only, tracking −1%, in ink or night white. The gap between disc and word is a quarter of the disc. On the web the fallback face is Nunito 900. A rendered PNG lockup for the press kit is `Design/Icon/fledge-lockup.png`.

Secondary motifs

## Used in the app and marketing, never in the icon

**Nest: three arcs**The three habits. Used for empty slots, onboarding, the Flown shelf footer and widget empty states. Tried in the icon, but it became noise at 40 px.

**Dawn sky**A time-of-day gradient behind Today, onboarding, graduation and every App Store screenshot.

**Flight path**A dotted gold curve, used only for graduation, the share card and "ready to fly". Gold is reserved for flying.

**Feathers**Six small feathers drift up 40 pt over 0.8 s when a habit is done. It is a reward, never decoration.

### Poses for the in-app FledgeBird

**Sitting**The mark itself

**Peeking**Empty slots

**Flying**Graduation: nose up 12°, flies up-left

**Sleeping**All done, empty Flown

Colour and type

## The icon's colours are the brand's colours

**Sky**#4A86FF\
Brand ground, Health

**Dawn**#FF5F45\
The wing: done

**Gold**#FFB13D\
Flight only

**Ink**#1B2240\
Text, wordmark, CTA

**Cloud**#F7F5F2\
Screens, paper

UI tokens, dark values, contrast ratios and the eight habit colours stay in `docs/DESIGN.md` §3.2.

SF Pro Rounded Heavy · titles

Walk is ready to fly.

SF Pro Rounded · numbers

4,210 / 6,000 steps

SF Pro Text · body

Flown habits keep tracking quietly. We'll nudge you only if one slips.

Voice in use

## How it sounds outside the app

![](brand-assets/fledge-icon-1024.png)

**Fledge**\
Read is still in the nest today. 10 minutes is enough.

![](brand-assets/fledge-icon-1024.png)

**Fledge**\
2 of 3 done. Walk needs 1,800 steps.

![](brand-assets/fledge-icon-1024.png)

**Fledge**\
Walk is ready to fly ✦

App Store subtitle: **3 habits that track themselves**. Campaign: **This year, fewer habits.**

Files

## Where everything lives

- `docs/BRAND.md`: this concept as text, the source of truth
- `Design/Icon/render-icon.swift`: renders every file below from one geometry; `fledge-icon.svg` matches it
- `fledge-icon-1024.png`, `-dark-`, `-tinted-`: installed in `AppIcon` and `AppIcon-Night`
- `layer-background.png`, `layer-bird.png`, `layer-wing.png`: for Icon Composer (DES-2)
- `fledge-mark.png`, `fledge-lockup.png`: for the press kit and landing page
- `icon-preview-dawn.png`, `icon-preview-night.png`: Settings › App icon previews

Fledge brand concept v2 · 14 October 2026