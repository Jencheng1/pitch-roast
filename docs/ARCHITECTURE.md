# Architecture

Pickle is a native macOS **menu-bar-class companion** (no Dock icon) built on
SwiftUI for views and AppKit for the floating-window behavior that SwiftUI can't
express. It is a small, layered, local-first app with one network dependency
(Claude) reached over raw `URLSession`.

```
┌──────────────────────────────────────────────────────────────────┐
│  AppKit shell                                                      │
│  PickleApp (@main, Settings scene)                                 │
│  AppDelegate (.accessory policy) ── FloatingPanel × 2 (NSPanel)    │
│        │                                  │                        │
│        │ owns                             │ hosts (NSHostingView)  │
│        ▼                                  ▼                        │
│  AppState  ◄───────────────── observes ─ CompanionView  PanelView  │
│  (@MainActor state machine)                                        │
└───────┬─────────────────────┬────────────────────┬────────────────┘
        │ owns                │ owns               │ orchestrates
        ▼                     ▼                    ▼
   AudioRecorder        SessionStore          PitchAnalyzer
   (AVAudioRecorder)    (JSON, local)         ├─ Transcriber  (Apple Speech, on-device)
                        ProgressTracker       └─ ClaudeClient (URLSession → Claude)
                                                       │
                                                       ▼
                                                PitchAnalysis  (decoded from
                                                structured-output JSON)
```

## Layers

| Layer | Type | Responsibility |
|---|---|---|
| **App shell** | `PickleApp`, `AppDelegate`, `FloatingPanel` | Process lifecycle, accessory mode, the two floating panels, placement above the Dock, panel show/hide animation. |
| **State** | `AppState` (`@MainActor`, `ObservableObject`) | The single source of truth and flow state machine. Owns the recorder, store, and the analyze task; derives the mascot's `mood`. |
| **Companion** | `CompanionView`, `PickleMascotView`, `MascotMood` | The always-on mascot + speech bubble. Reacts to mic level, stage, and score. |
| **Panel** | `PanelView` + six stage views | The compact glass UI; a router that renders one `PitchStage` at a time. |
| **Recording** | `AudioRecorder`, `Transcriber`/`SpeechTranscriber` | Capture audio + live level; on-device speech-to-text behind a protocol. |
| **AI** | `ClaudeClient`, `PitchAnalyzer`, `AnalysisSchema`, `PicklePrompts`, `AnalysisModels` | Build/parse the Claude request; the transcript→analysis pipeline; the typed result. |
| **Data** | `SessionStore`, `SessionRecord`, `ProgressTracker`, `Keychain` | Local persistence, progress aggregation, secret storage. |
| **Design system** | `Theme`, `Typography`, `GlassBackground`, `PickleComponents` | Palette, type ramp, vibrancy glass, reusable controls. |

## Why these choices

**SwiftUI + AppKit, not Electron.** The product is defined by being a *native,
lightweight presence above the Dock*. That requires an `NSPanel` with
`.nonactivatingPanel` (clicking Pickle never steals focus from the app you're
pitching against), `.canJoinAllSpaces`, a floating window level, and real
`NSVisualEffectView` vibrancy. Electron can fake the look but not the feel or the
weight. SwiftUI draws everything; AppKit owns the windowing.

**Accessory activation policy.** `NSApp.setActivationPolicy(.accessory)` +
`LSUIElement` means no Dock tile and no menu-bar item — Pickle himself is the
affordance. The panel is summoned by clicking him.

**Two windows, one state.** A small companion panel (the mascot) and a larger
pitch panel (the UI). Both are `NSHostingView`s over the *same* `AppState`
instance injected as an `environmentObject`, so they stay in lockstep. The
`AppDelegate` drives panel visibility/position by observing `AppState.$panelVisible`
with Combine and animating `alphaValue`.

**`@MainActor` everywhere that touches UI/AVFoundation.** `AppState`,
`AppDelegate`, and `AudioRecorder` are main-actor isolated; the analysis pipeline
is `async` and hops back to the main actor to publish results. Nested
`ObservableObject`s (`recorder`, `store`) re-publish through `AppState` via
`objectWillChange` forwarding so SwiftUI sees their changes.

**Raw `URLSession` for Claude.** Swift has no official Anthropic SDK, so
`ClaudeClient` builds the Messages API request with `JSONSerialization` and parses
the response by hand. See [`AI_WORKFLOW.md`](AI_WORKFLOW.md).

## The flow state machine

`AppState.stage: PitchStage` is the spine:

```
welcome → recording → analyzing → results
   ▲          │            │          │
   └──────────┴── cancel ──┘          ├──► history ──┐
   └────────────────── practiceAgain ─┘              │
   └────────────────────────────────── back ─────────┘
welcome ⇄ settings ⇄ history   (navigable any time from the header)
```

`PanelView` switches on `stage` with a spring transition. The mascot's `mood` is
*derived* from `stage` (+ the latest score), so the companion and the panel header
animate in perfect sync without extra state.

## Concurrency model

- UI + audio: `@MainActor`.
- The pipeline (`PitchAnalyzer.run`) is a detached structured-concurrency `Task`
  stored on `AppState` so it can be cancelled (e.g. if the user navigates away).
- Transcription wraps Apple's callback API in `withCheckedThrowingContinuation`.
- All result mutation (`store.add`, `result =`, `stage = .results`) happens back on
  the main actor.

## Failure handling

Every external boundary returns a typed, user-facing error:
`ClaudeClient.ClientError` (missing key, HTTP, refusal, decode),
`SpeechTranscriber.TranscribeError` (unauthorized, unavailable),
`PitchAnalyzer.AnalyzerError` (empty transcript). `AppState` funnels them into
`errorMessage`, shown as a banner on the welcome stage, and returns Pickle to a
safe state.

## Security / privacy boundaries

- **Audio** never leaves the device; transcription is on-device (Apple Speech with
  `requiresOnDeviceRecognition`). The temp `.m4a` is deleted after analysis.
- **Only the transcript** crosses the network, to Claude.
- **API key** is in the Keychain (`Keychain.swift`), never in UserDefaults, the
  prompt, or logs.
- **History** is a local JSON file in Application Support.
