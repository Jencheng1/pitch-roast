# Roadmap

The MVP ships **one investor persona** and a single structured analysis. The
architecture was built so the ambitious features layer in without rewrites. Each
item below names the exact seam it plugs into.

## Where future features plug in

| Seam | What it enables |
|---|---|
| `PicklePrompts` + a `Persona` type | Multiple investor personas, operator/customer modes, YC-style feedback. |
| `PitchAnalyzer` (the pipeline) | Judge panels, mock Q&A, demo-day simulations (multi-call / multi-turn). |
| `Transcriber` protocol | Whisper / cloud STT, non-English support, live streaming transcription. |
| `output_config.format` schema | New result shapes (per-persona verdicts, Q&A turns, deck findings). |
| `SessionRecord` + `SessionStore` | New artifacts (decks, Q&A sessions) alongside pitches; SwiftData backend. |

## Phase 1 — Multiple investor personas
Introduce `InvestorPersona { id, name, archetype, systemPrompt, voice, mascotTint }`
(angel, growth VC, skeptical operator, friendly champion). Persona selection on the
Welcome stage; `PicklePrompts.system` becomes `persona.systemPrompt`. Pickle visually
reskins (tint/accessory) per persona. *No pipeline change — just prompt + selection.*

## Phase 2 — AI judge panel
Run N personas **in parallel** over the same transcript (structured concurrency:
`async let` / `TaskGroup` inside `PitchAnalyzer`), then a synthesis pass that
reconciles their scores into a panel verdict with dissent ("the growth VC loved it;
the operator didn't buy the GTM"). Results stage gains a panel view. This is the
first genuinely multi-agent shape — and exactly what the workflow tier is for.

## Phase 3 — Mock Q&A sessions
After a pitch, Pickle asks the **likely questions** out loud (AVSpeechSynthesizer),
you answer by voice, and each answer is scored in a short multi-turn loop. Reuses
the recorder + transcriber; adds a `QASession` record. Trains the live-room muscle,
not just the monologue.

## Phase 4 — Slide-deck analysis
Drag a PDF onto Pickle. Send it to Claude via the **Files API** + document blocks;
a deck-specific schema returns per-slide findings (clarity, narrative arc,
data credibility, "the slide an investor screenshots"). New `DeckRecord`; the panel
gains a deck stage. Pairs with the spoken pitch for a combined readiness score.

## Phase 5 — Demo-day simulation
A timed, staged run: pitch → judge-panel reactions → rapid-fire Q&A → a final
"would we advance you?" verdict, with a countdown and crowd energy. Composes Phases
2–3 into one high-stakes rehearsal. The flow state machine already models staged
progression; this adds a `simulation` track.

## Phase 6 — Operator & customer modes
Same engine, different lens: pitch to a prospective **customer** (does the value
prop land? would they buy?) or an **operator/hiring** audience. Just new personas +
rubrics on the Phase 1 seam.

## Cross-cutting

- **SwiftData migration** — swap `SessionStore`'s JSON for a `ModelContext`
  (drop-in; see `DATA_MODEL.md`).
- **iCloud sync** — practice history across devices once on SwiftData + CloudKit.
- **Streaming results** — stream the analysis so the verdict types in live.
- **Prompt-cache instrumentation** — surface cache hit rate; pre-warm on launch.
- **Distribution** — Developer ID signing + notarization, a real app icon, a
  Sparkle/auto-update channel, optional App Store sandbox build.
- **Accessibility** — VoiceOver labels on the mascot/scores, reduced-motion
  variants of the idle/celebration animations.
- **Analytics (local, opt-in)** — streaks, weekly "readiness report", reminders to
  practice before a known pitch date.

## Guiding principle

Every addition keeps the product **companion-first and voice-first**. New power
shows up as new things *Pickle* can do — not as tabs, dashboards, or settings
sprawl. The mascot stays the center of gravity.
