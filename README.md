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
[OpenAI API key](https://platform.openai.com) (one key powers transcription,
voice, and analysis). Claude is an optional analysis engine.

```bash
make run          # build (debug), bundle Pickle.app, and launch it
```

Then:

1. Pickle appears above your Dock. **Click him.**
2. Open **⚙︎ Settings** → paste your **OpenAI API key** (stored in the macOS
   Keychain). That one key powers transcription, Pickle's voice, and the
   analysis — the least-config path. Prefer Claude for analysis? Switch the
   engine in the same screen and add an Anthropic key.
3. Pick a pitch length, hit **Start Pitching**, and talk.
4. macOS will ask for **Microphone** permission the first time (and **Speech
   Recognition** only if you run key-free on the on-device fallback).

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

## How it works

```
🎙  AVAudioRecorder  →  🗣  Whisper / Apple Speech  →  🧠  GPT-4o / Claude  →  🔊 TTS  →  📊  glass panel
        audio                  transcript                   analysis            voice        + history
```

- **Default (one OpenAI key):** audio → **OpenAI Whisper** (transcription) →
  **GPT-4o** (analysis, strict JSON schema) → **OpenAI TTS** reads the roast aloud.
- **Key-free fallback:** with no OpenAI key, transcription stays **on-device**
  via Apple Speech and the voice uses the on-device `AVSpeechSynthesizer` — but
  analysis needs a key (OpenAI or Claude).
- **Optional engine:** switch analysis to **Claude (`claude-opus-4-8`)** in
  Settings; it uses the same persona + schema.
- The recorded **audio file is deleted** after analysis. With an OpenAI key the
  audio is uploaded to OpenAI to transcribe; without one it never leaves the Mac.
- Scores and history are stored **locally** in
  `~/Library/Application Support/Pickle/sessions.json`; API keys live in the
  **Keychain**.

---

## Project layout

```
Sources/Pickle/
  App/           PickleApp, AppDelegate, AppState, FloatingPanel   ← app shell + state machine
  Companion/     PickleMascotView, CompanionView, MascotMood       ← the mascot that lives above the Dock
  Panel/         PanelView + Stages/ (Welcome, Recording,          ← the floating glass panel
                 Analyzing, Results, History, Settings)
  Recording/     AudioRecorder, Transcriber (Speech + OpenAI),      ← voice capture, STT, TTS
                 VoiceCoach (OpenAI TTS + Apple fallback)
  AI/            AnalysisProvider, OpenAIClient, ClaudeClient,      ← the analysis engines
                 PitchAnalyzer, AnalysisModels, AnalysisSchema, PicklePrompts
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
- **Voice-first** — `AVAudioRecorder` → **OpenAI Whisper** (default) behind a
  `Transcriber` protocol, with on-device Apple **Speech** as the key-free
  fallback. Pickle speaks via **OpenAI TTS** / `AVSpeechSynthesizer`.
- **Provider-agnostic analysis** — an `AnalysisProvider` protocol with two
  engines: **OpenAI `gpt-4o`** (default) and **Claude `claude-opus-4-8`**
  (optional), both using **strict JSON-schema structured outputs** so the
  response decodes straight into a typed `PitchAnalysis`.
- **Least configuration** — one OpenAI key powers transcription, voice, and
  analysis out of the box.
- **Local-first storage** (Codable JSON store; SwiftData is a documented drop-in)
  and **Keychain** for each provider key.

---

## Roadmap (post-MVP)

Multiple investor personas · AI judge panels · YC-style feedback · operator &
customer modes · slide-deck analysis · mock Q&A sessions · demo-day simulations.
The architecture is built for these — see [`docs/ROADMAP.md`](docs/ROADMAP.md).
