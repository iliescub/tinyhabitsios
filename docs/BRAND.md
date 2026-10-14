# Fledge brand: "First flight"

Status: v2, 2026-10-14 (replaces the v1 icon in DESIGN.md §3.1) · Visual brand book: `Design/review/brand.html` (published as an artifact)
Files: `Design/Icon/` (render with `swift Design/Icon/render-icon.swift Design/Icon`) · UI rules: `docs/DESIGN.md` · redesign: `docs/UI-REDESIGN.md`

## Essence
Habits are fledglings. Fledge looks after three at a time, does the tracking for you, and lets each one go once it can fly on its own.
Most habit apps celebrate the grind. Fledge celebrates **letting go**.

- **Brand idea:** *done becomes flight.* The checkmark is the bird's wing.
- **Positioning:** Fledge is the habit tracker that lets go (the one claim no competitor makes; `docs/POSITIONING.md`).
- **Promise:** Three habits. Done for you. Then they fly.
- **Campaign line (New Year 2027):** This year, fewer habits.

## Pillars
| Pillar | Means | Shows up as |
| --- | --- | --- |
| Few | Three, never thirty | Three slots, the three-arc nest motif, "Only three" in every listing |
| Effortless | Apple Health does the logging | "Done for you", rings that fill by themselves |
| Kind | Rest is fine; nothing is ever "failed" | No red, rest days are calm, no streak-broken screens |
| Private | No account, Health data stays on the iPhone | Said plainly in onboarding, App Store and press |
| Native | Feels like Apple made it | SF Pro Rounded, SF Symbols, Liquid Glass on navigation only |

## Personality
A calm, warm friend who is quietly proud when you need them less.

| Fledge is | Fledge is not |
| --- | --- |
| Calm | Sleepy or vague |
| Warm | Cute or babyish (it is not a pet; see Finch) |
| Confident | Pushy or hype ("crush it", "beast mode") |
| Light | Childish |
| Proud of you | Proud of itself |

Voice rules, words we use and avoid: `docs/DESIGN.md` §2 (unchanged). Short sentences, second person, bird words only where they add meaning
(nest, ready to fly, flown).

## The mark: the Fledgling
A round white bird whose wing is a checkmark. The long stroke of the check breaks out of the body outline, so the wing is lifting: the
habit is done and about to fly.

- **Facing left, on purpose.** The checkmark must stay a true checkmark (long stroke rising to the right). With the bird facing left, that
  stroke becomes a wing raised behind it as it takes off. Never mirror the mark.
- **Construction** (body radius r = 214 in `render-icon.swift` mark space): wing stroke 0.30 r with round caps; the wing tip extends 0.35 r
  beyond the body; eye 0.11 r, placed at 0.55 r left and 0.31 r up from centre; gold beak 0.47 r long, flat back edge. Mark centred
  optically on its bounding box (beak tip to wing tip).
- **Clear space:** half a body radius on every side. **Minimum size:** 16 px for the mark; 29 pt for the icon (checked).
- **Colours:** body white (night: `#F4F5FB`), wing dawn `#FF5F45` (night `#FF8169`), beak `#FFB13D`, eye ink `#1B2240`.
- **Don't:** mirror or rotate it, outline it, put gradients on the bird, give it limbs, expressions or accessories, recolour the wing outside
  the variants, place it on busy photos, or use SF `bird`/`bird.fill` in its place.

## App icon
| Appearance | Background | Notes |
| --- | --- | --- |
| Default ("Dawn") | Sky gradient `#4A86FF → #8DB6FF → #FFC7A1` (top to bottom) | The free icon |
| Dark ("Night") | `#121731 → #1F2550 → #4A3B6B` | Also the alternate icon "Night" (Pro) |
| Tinted | Black, white body, grey wing and beak | The system tints by luminance |

Icon Composer: import `layer-background.png`, `layer-bird.png` and `layer-wing.png` as three layers. Turn on Liquid Glass with specular
for bird and wing, and give the wing the top layer so it lifts off the body in clear and tinted modes. Still to do (DES-2): build
`Fledge.icon` and check all six appearances on a device.

## Wordmark and lockup
- Wordmark: "Fledge" in **SF Pro Rounded Bold**, ink, tracking −1 %. Sentence case only.
- Lockup (`fledge-lockup.png`): the mark on a sky disc, then the wordmark. Gap = 0.25 × disc diameter; wordmark cap height ≈ 0.5 × disc.
- On the web, where SF Pro Rounded is unavailable: Nunito 800 as the fallback.

## Secondary motifs (UI and marketing, never in the icon)
| Motif | Meaning | Use |
| --- | --- | --- |
| **Nest**: three stacked arcs | The three habits | Empty slots, onboarding pick step, Flown shelf footer, widget empty state, marketing backgrounds |
| **Dawn sky**: time-of-day gradient | A new day, calm | Today header, onboarding, graduation, App Store screenshot backgrounds |
| **Flight path**: dotted gold curve | Graduation | Graduation screen, share card, "ready to fly" moments. Gold is reserved for flying |
| **Feathers**: 6 small shapes drifting up | A habit done | Completion burst (0.8 s), never decoration |

Poses for the in-app `FledgeBird` (UX-2): **sitting** (the mark), **peeking** (body half-hidden behind the nest, for empty slots),
**flying** (wing raised further, nose up 12°; it always flies toward the upper left, the way it faces), **sleeping** (eye as a short arc, for all-done and empty states).

## Colour
Core brand colours are the icon colours. UI tokens, contrast values and habit colours stay in `docs/DESIGN.md` §3.2.

| Name | Hex (light / dark) | Role |
| --- | --- | --- |
| Sky | `#4A86FF` icon, `#4F8DFF` UI / `#6FA3FF` | Background of the brand, Health |
| Dawn | `#FF5F45` / `#FF8169` | The wing: "done" |
| Gold | `#FFB13D` beak; UI `#D0830E` / `#FFC15E` | Flight and graduation only |
| Ink | `#1B2240` / `#E9ECF8` | Text, wordmark, primary button |
| Cloud | `#F7F5F2` / `#0E1120` | Screens, paper |

## Typography
SF Pro Rounded (Bold, Heavy) for the wordmark, titles and numbers; SF Pro Text for body. Marketing web: Nunito 800 + Inter.

## Applications checklist
- App Store: icon, screenshots on the dawn sky with SF Pro Rounded captions in ink (DESIGN.md §9), preview video opening with the ring
  filling and the bird lifting off.
- Press kit (MKT-5): `fledge-icon-1024.png`, `fledge-mark.png`, `fledge-lockup.png`, this file's essence paragraph.
- Landing page (MKT-1): lockup top-left, dawn sky hero, the nest motif behind the waitlist form.
- Notifications use the app icon. Copy follows the voice rules; graduation pushes may use ✦.
