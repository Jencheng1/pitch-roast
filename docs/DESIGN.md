# Visual Direction & Design System

Pickle should feel **alive, warm, and a little cheeky** — a tiny investor with
taste who lives on your desktop. The opposite of enterprise software: no sidebars,
no dashboards, no chat transcript. One mascot, one glass panel, beautiful motion.

## Principles

1. **Companion-first.** The mascot is the product. Every surface points back to
   him; the UI is the panel *he* opens.
2. **Voice-first, glance-readable.** You talk; you read scores at a glance. Big
   numbers, rings, and bars — not paragraphs.
3. **Native glass.** Real `NSVisualEffectView` vibrancy, hairline highlights, and
   soft shadows — it belongs on macOS, floating over your desktop.
4. **Delight in the details.** Pickle blinks, bobs, reacts to your voice, squints
   while thinking, smirks while roasting. Microinteractions everywhere.
5. **Not AI-slop.** A deliberate pickle-green + cream + brass identity — no purple
   gradients, no Inter-on-white, no generic card grid.

## Palette (`Theme.swift`)

| Token | Hex | Use |
|---|---|---|
| `pickle` / `pickleLight` / `pickleDeep` | `#4E7C3A` / `#7BAE52` / `#37562A` | Pickle's body, panel tint, the brand. |
| `cream` | `#F4F1E8` | Speech bubble "paper", warm inset (never stark white). |
| `brass` / `brassBright` | `#C9A24B` / `#E6C66E` | The money color — accents, CTAs, recommendations. |
| `hot` / `warm` / `cool` | `#E3633B` / `#E6A23C` / `#4E9C8F` | The verdict ramp (brutal → promising → strong). |

**Score → color ramp.** `Theme.scoreColor(_:)` maps any 0–100 onto cool→warm→hot,
so a score's *color* reinforces its meaning everywhere (rings, bars, list rows).

## Type (`Typography.swift`)

SF **Rounded** for warmth (companion feel); **monospaced digits** for scores so
numbers don't jiggle as they animate.

`pickleTitle` · `pickleHeadline` · `pickleBody` · `pickleCaption` · `pickleScore`.

## Glass (`GlassBackground.swift`)

- `VisualEffectBlur` — `NSVisualEffectView` (`.hudWindow`, behind-window blending)
  wrapped for SwiftUI. The real glass.
- `.glassPanel()` — vibrancy + cream tint + gradient hairline border + soft drop
  shadow + continuous-corner clip. The panel shell.
- `.glassCard()` — a lighter inset for grouped content inside the panel.

The panel additionally tints the vibrancy briny (`pickleDeep @ 0.55`) and runs in
`.dark` color scheme so white text and the brass accent pop over any wallpaper.

## The mascot (`PickleMascotView.swift`)

Drawn entirely in SwiftUI vectors (no raster assets) so he scales crisply and every
feature animates independently:

- **Body** — a custom `PickleShape` (tapered, bumpy gherkin) filled with the pickle
  gradient, with warty dots and a soft-light highlight.
- **Eyes** — capsule whites + pupils. They blink on a randomized timer, go *wide*
  when listening, *squint* when thinking, and grow a **brow** when skeptical or
  roasting.
- **Mouth** — a `Smile` arc by default; **opens with your live mic level** while
  recording; pursed when thinking; a full grin when impressed; a tilted **smirk**
  when roasting.
- **Mood halo + sparkles** — a colored glow keyed to mood; sparkles when impressed
  or celebrating a personal best.
- **Idle life** — a gentle vertical bob loop and periodic blinks so he always feels
  alive.

### Moods (`MascotMood.swift`)

`idle · curious · listening · thinking · impressed · skeptical · roasting ·
celebrating`. Mood is **derived** from `AppState` (stage + latest score), so the
companion and the panel header express the same emotion at the same time, and each
mood carries a `quip` Pickle says in his bubble.

## Components (`PickleComponents.swift`)

- **`ScoreRing`** — animated circular gauge (spring fill) for overall score &
  interest, colored by the ramp.
- **`ProgressBar`** — slim rounded bar for the eleven dimensions and interest.
- **`Chip`** — small status pills ("NEW PERSONAL BEST").
- **`PickleButton`** — primary (pickle gradient) / ghost / danger, with a hover
  lift.
- **`SectionLabel`** — tracked, tinted, icon-led section headers.
- **`Sparkline`** — hand-drawn trend line (animated draw) for the progress view.

## Motion

| Moment | Motion |
|---|---|
| Panel open/close | `alphaValue` fade (AppKit) + spring content transition. |
| Stage change | Asymmetric slide+fade, spring. |
| Score reveal | Ring + bars spring-fill from zero. |
| Recording | Center-weighted reactive `Waveform` driven by smoothed mic level. |
| Mood change | Mascot springs between expressions; bubble pops in. |
| Personal best | Sparkles + a celebrating mascot + a brass chip. |
| Tap / submit | Trackpad **haptics** (`Haptics.tap()/.success()`). |

## Layout

- **Companion window:** 150×168, bottom-center, 12pt above the Dock
  (`screen.visibleFrame`).
- **Pitch panel:** 372×540, anchored just above the companion, clamped on-screen.
- Generous padding, continuous corners (22 panel / 14 card), one primary action per
  stage.
