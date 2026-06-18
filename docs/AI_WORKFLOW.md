# AI Workflow

Pickle's intelligence is one well-shaped Claude call per pitch. The design goal:
a **single, reliable, structured** analysis that decodes directly into Swift
types — no brittle text parsing, no multi-turn agent loop needed for the MVP.

## Pipeline

```
recorded .m4a
   │  AudioRecorder
   ▼
Transcriber.transcribe(url)            ← Apple Speech, on-device, en-US, punctuation on
   │  String (transcript)
   ▼
PitchAnalyzer.run(...)                 ← guards empty transcript, surfaces words early
   │  transcript + PitchLength + spokenSeconds
   ▼
ClaudeClient.analyze(...)              ← POST /v1/messages
   │  structured-output JSON (text block)
   ▼
JSONDecoder → PitchAnalysis            ← typed result
   │
   ▼
SessionRecord persisted + shown
```

## The Claude request

`ClaudeClient` builds the request body with `JSONSerialization` (Swift has no
official Anthropic SDK; raw HTTP is the correct path) and sends it to
`https://api.anthropic.com/v1/messages`.

| Field | Value | Why |
|---|---|---|
| `model` | `claude-opus-4-8` | The current, most capable Opus-tier model — calibrated, witty judgment is exactly its strength. |
| `max_tokens` | `16000` | Comfortably fits the structured analysis; non-streaming stays under the SDK/HTTP timeout window. |
| `system` | Pickle persona + rubric, as a single cached text block (`cache_control: ephemeral`) | The persona is **frozen** and identical across runs, so it caches — only the transcript varies. |
| `thinking` | `{ type: "adaptive" }` | Adaptive thinking lets Claude reason about a nuanced judgment without a fixed budget. |
| `output_config.effort` | `medium` | Good cost/quality balance for a single scored analysis. |
| `output_config.format` | `{ type: "json_schema", schema: … }` | **Structured outputs** — the response is guaranteed to match `AnalysisSchema`, so it decodes straight into `PitchAnalysis`. |
| `messages` | one user turn: format guidance + time spoken + transcript | The only volatile part of the prompt. |

Headers: `x-api-key`, `anthropic-version: 2023-06-01`, `Content-Type`.

### Prompt-caching shape

Render order is `system → messages`. The persona/rubric sits first with a
`cache_control` breakpoint, the per-run transcript comes after. Across a practice
session the cached prefix is reused, so each subsequent analysis is cheaper and
faster. (Verify via `usage.cache_read_input_tokens` when instrumenting.)

## The schema → types contract

`AnalysisSchema.json` is a strict JSON Schema: every object sets
`additionalProperties: false` and lists all keys in `required` (a structured-output
requirement). The eleven dimensions share a `$defs/dim` (`{ score, note }`). Keys
match `PitchAnalysis` **exactly**, so decoding is a one-liner.

Structured outputs ignore numeric range constraints, so scores are plain
`integer`s and the **prompt** is what holds them to 0–100 and keeps them
calibrated ("50 is a real, unremarkable pitch; 80+ means lean in; 90+ is rare").

## Response parsing

`decodeAnalysis(from:)`:

1. Checks `stop_reason == "refusal"` first and raises a friendly error (so we never
   index into empty `content`).
2. Finds the **text** content block (thinking blocks precede it — we don't read
   `content[0]` blindly).
3. Decodes that text — guaranteed-valid schema JSON — into `PitchAnalysis`.

HTTP errors surface the API's `error.message`.

## Persona (`PicklePrompts.system`)

Pickle is a sharp, slightly sarcastic seed investor who is fundamentally on the
founder's side. The system prompt encodes:

- **Voice**: witty, a little brutal, never cruel; every cut comes with a fix.
- **Rubric**: the eleven dimensions, judged 0–100, with explicit notes that
  confidence/delivery are read from verbal signals (hedging, filler, pacing).
- **Calibration discipline**: don't inflate — founders improve faster on truth.
- **Format awareness**: a 30s elevator pitch isn't penalized for lacking a
  business-model breakdown; a 5-minute deep dive is.
- **Outputs**: scores, verdict, strengths/weaknesses, investor concerns, likely
  questions, prioritized recommendations, and the roast — all referencing what the
  founder actually said.

## Derived metrics (no extra tokens)

`PitchAnalysis` computes `readiness`, `presentationQuality`, and `confidenceScore`
locally from the returned scores, so the progress tracker has clean trend lines
without asking the model for redundant numbers.

## Why one call, not an agent

For the MVP the task is bounded and single-shot: judge one transcript, return one
structured verdict. A single structured-output call is the right tier — cheaper,
faster, and deterministic to parse. The **roadmap** features (judge panels, mock
Q&A, deck analysis) are where multi-turn / multi-agent shapes earn their cost; the
`PitchAnalyzer` seam is where they'll plug in. See [`ROADMAP.md`](ROADMAP.md).

## Swapping the transcriber

`Transcriber` is a protocol. `SpeechTranscriber` (Apple, on-device) is the default;
a `WhisperTranscriber` or cloud STT can replace it without touching the analyzer or
the client — useful for non-English support or higher accuracy.
