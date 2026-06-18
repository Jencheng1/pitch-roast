# UX Flows

Pickle is voice-first and companion-first. Everything starts by clicking the
mascot; the panel is short, single-purpose per stage, and always one click from
"one more run".

## The core loop

```
   ┌──────────────────────────────────────────────────────────┐
   │                                                          ▲ │
Pickle floats   click    Welcome    Start    Recording   Done │ │
above the Dock ───────►  (pick a ──────────► (talk, live ─────┘ │
   🥒                     length)             waveform)          │
                                                  │ analyze       │
                                                  ▼               │
                                              Analyzing            │
                                              (Pickle thinks,      │
                                               words appear)       │
                                                  │               │
                                                  ▼               │
                                               Results ───────────┘
                                            (score, roast,     Pitch Again
                                             scorecard, fixes)
                                                  │
                                                  ▼
                                               History
                                            (trends over time)
```

## Stage by stage

### 0 · Companion (always present)
Pickle hovers above the Dock with a speech bubble ("Pitch me.", "One more run?").
He blinks and bobs. **Click → opens the panel.** While recording he shows a live
timer pip and reacts to your voice; while analyzing he shows a spinner and thinks.

### 1 · Welcome
- Headline + a 2×2 grid of **pitch lengths** (Elevator 30s · Demo Day 60s ·
  Standard 2m · Deep Dive 5m), each with emoji, title, and what it's for.
- If you've pitched before, a **last-run strip** (tap to re-open that verdict).
- **Start Pitching** (primary). If no API key, a nudge routes to Settings; an error
  banner appears here if the previous run failed.

### 2 · Recording
- Big running **clock** vs. the format target, plus seconds remaining.
- A center-weighted **reactive waveform** driven by your live mic level.
- A rotating **pacing hint** ("Open strong — what's the problem?" → "Land the
  traction and the ask." → "Over time — investors are checking their phones.").
- **Discard** (ghost) or **Done · Analyze** (primary, haptic). Auto-stops at the
  format's max duration.

### 3 · Analyzing
- A thinking Pickle, rotating "what I'm weighing" lines.
- Your **transcript appears as soon as it's ready** (before the slower analysis
  returns) so the wait feels productive.

### 4 · Results (the payoff, scrollable)
1. **Score header** — overall `ScoreRing` + investor-interest bar + interest label;
   a **NEW PERSONAL BEST** chip when earned.
2. **Verdict** — one punchy line.
3. **The Roast** — Pickle at full volume, in a hot-tinted card with a roasting
   mascot.
4. **Scorecard** — all eleven dimensions as labeled bars.
5. **Strengths** / **Weaknesses** — titled, specific.
6. **Investor concerns** / **Likely questions** — the objections and the questions
   you'd actually get in the room.
7. **Fix this next** — prioritized, numbered recommendations (action + why).
8. **What you said** — collapsible transcript.
- Sticky action bar: **History** / **Pitch Again**.

### 5 · History (retention)
- Metric selector: **Overall · Readiness · Confidence · Presentation**.
- Big current value + **delta vs. last run** + an animated **sparkline**.
- A **momentum line** from Pickle ("You're climbing fast — keep this energy.").
- A list of recent runs (tap any to revisit its verdict).
- Empty state invites the first pitch.

### 6 · Settings
- **Anthropic API key** (SecureField → Keychain), with connect/remove + status.
- A short, honest "how Pickle works" privacy explainer.

## Navigation model

- The panel **header** always offers History, Settings, and Close.
- Close hides the panel; Pickle stays above the Dock.
- `Pitch Again` resets to Welcome with the same length pre-selected.
- Any stage is reachable in one tap; there are no modal dead-ends.

## Permissions

On first record, macOS prompts for **Microphone** and **Speech Recognition**. If
denied, a friendly banner explains exactly where to re-enable them. Without an API
key, the record button routes to Settings instead of failing silently.

## Emotional design

The whole flow is tuned for **confidence through reps**: low-friction to start, a
mascot who is on your side, brutal-but-kind feedback, and a visible upward trend
that makes practice feel like progress. The recurring call to action is the same
warm invitation — *one more run*.
