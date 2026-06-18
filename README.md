# 🥒 Pickle — your tiny desktop investor

Pickle is a macOS desktop companion that lives above your Dock and helps founders
**practice pitches out loud** before facing real investors, demo days, and pitch
competitions. Click Pickle, pick a pitch length, talk, and get an honest (and
slightly savage) investor read: a score, an interest rating, strengths,
weaknesses, the concerns and questions a real investor would raise, what to fix
next — and a roast.

The point isn't just a better deck. It's **reps**: the more you pitch Pickle, the
more your confidence, readiness, and delivery climb — and Pickle tracks all three
over time.

> Built native (SwiftUI + AppKit), voice-first, glassmorphic, companion-first.
> Pickle thinks with **Claude (`claude-opus-4-8`)**.

---

## Quick start

**Requirements:** macOS 14+, Xcode 16 (for the Swift 5.9 toolchain), an
[Anthropic API key](https://console.anthropic.com).

```bash
make run          # build (debug), bundle Pickle.app, and launch it
```

Then:

1. Pickle appears above your Dock. **Click him.**
2. Open **⚙︎ Settings** → paste your Anthropic API key (stored in the macOS
   Keychain — it never leaves your Mac except to call Claude).
3. Pick a pitch length, hit **Start Pitching**, and talk.
4. macOS will ask for **Microphone** and **Speech Recognition** permission the
   first time — both are required.

Other targets:

```bash
make release      # optimized build + ad-hoc signed bundle
make app          # just (re)assemble the bundle from the last build
make clean
```

> The `Makefile` assembles a real `.app` (with `Info.plist`, usage strings, and
> entitlements) and ad-hoc code-signs it so the TCC permission prompts behave.
> Distribution would swap the ad-hoc identity for a Developer ID + notarization.

---

## What Pickle evaluates

Every run is scored 0–100 overall and for **investor interest** ("would I take a
second meeting?"), plus eleven dimensions:

| | | |
|---|---|---|
| Problem clarity | Solution clarity | Storytelling |
| Confidence | Delivery | Market opportunity |
| Differentiation | Business model | Founder credibility |
| Investor appeal | Timing (why now) | |

You also get: a one-line verdict, concrete strengths & weaknesses, **investor
concerns**, **likely questions** you'd get in the room, prioritized
**recommendations**, and **the roast** — brutally honest, genuinely funny, always
constructive.

---

## How it works (privacy-first)

```
🎙  AVAudioRecorder  →  🗣  Apple Speech (on-device)  →  🧠  Claude  →  📊  glass panel
        audio                  transcript                  analysis        + history
```

- Your **audio** is recorded to a temp file and transcribed **on-device** with
  Apple's Speech framework. The audio file is deleted after analysis.
- Only the **transcript** (plus format + duration) is sent to Claude.
- Scores and history are stored **locally** in
  `~/Library/Application Support/Pickle/sessions.json`.
- Your API key lives in the **Keychain**.

---

## Project layout

```
Sources/Pickle/
  App/           PickleApp, AppDelegate, AppState, FloatingPanel   ← app shell + state machine
  Companion/     PickleMascotView, CompanionView, MascotMood       ← the mascot that lives above the Dock
  Panel/         PanelView + Stages/ (Welcome, Recording,          ← the floating glass panel
                 Analyzing, Results, History, Settings)
  Recording/     AudioRecorder, Transcriber (+ SpeechTranscriber)  ← voice capture + STT
  AI/            ClaudeClient, PitchAnalyzer, AnalysisModels,       ← the analysis engine
                 AnalysisSchema, PicklePrompts
  Data/          SessionStore, SessionRecord, ProgressTracker,     ← persistence + trends
                 Keychain
  DesignSystem/  Theme, Typography, GlassBackground, Components     ← the look
  Support/       PitchLength, Haptics
Bundle/          Info.plist, Pickle.entitlements
docs/            ARCHITECTURE, DESIGN, UX_FLOWS, DATA_MODEL, AI_WORKFLOW, ROADMAP
```

See [`docs/`](docs/) for the full architecture, design system, UX flows, data
model, AI workflow, and roadmap (investor personas, judge panels, deck analysis,
mock Q&A, demo-day simulations).

---

## Tech & decisions (chosen independently)

- **Native SwiftUI + AppKit**, not Electron — only native gives a true
  lives-above-the-Dock `NSPanel` companion, real glass (`NSVisualEffectView`),
  and crisp microinteractions at companion weight.
- **Accessory activation policy** (`LSUIElement`) — no Dock icon; Pickle *is* the
  presence. A non-activating floating panel never steals focus from the app
  you're rehearsing against.
- **Voice-first** — `AVAudioRecorder` → Apple **Speech** (on-device), behind a
  `Transcriber` protocol so whisper.cpp / cloud STT can swap in.
- **Claude `claude-opus-4-8`** with adaptive thinking + **structured outputs**
  (`output_config.format` JSON schema) → the response decodes straight into a
  typed `PitchAnalysis`.
- **Local-first storage** (Codable JSON store; SwiftData is a documented drop-in)
  and **Keychain** for the key.

---

## Roadmap (post-MVP)

Multiple investor personas · AI judge panels · YC-style feedback · operator &
customer modes · slide-deck analysis · mock Q&A sessions · demo-day simulations.
The architecture is built for these — see [`docs/ROADMAP.md`](docs/ROADMAP.md).
