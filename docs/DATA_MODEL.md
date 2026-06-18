# Data Model

Pickle is **local-first**. One JSON file holds the practice history; the Keychain
holds the API key; nothing else is persisted. The model is deliberately small and
repository-shaped so the backend can be swapped without touching the UI.

## Entities

### `PitchAnalysis` (the verdict)
Decoded directly from Claude's structured output (`AnalysisSchema`). Field names
match the schema 1:1.

| Field | Type | Notes |
|---|---|---|
| `overallScore` | `Int` 0–100 | Overall quality. |
| `investorInterest` | `Int` 0–100 | "Would I take a follow-up meeting?" |
| `interestLabel` | `String` | Short interest verdict. |
| `verdict` | `String` | One-line summary. |
| `strengths` / `weaknesses` | `[Highlight]` | `{ title, detail }`. |
| `investorConcerns` | `[String]` | Objections an investor would raise. |
| `likelyQuestions` | `[String]` | Questions you'd get in the room. |
| `recommendations` | `[Recommendation]` | `{ action, why }`, prioritized. |
| `roast` | `String` | Brutally honest, witty, constructive. |
| `dimensions` | `Dimensions` | The eleven judged scores. |

`Dimensions` — each a `Dim { score: Int, note: String }`:
`problemClarity, solutionClarity, storytelling, confidence, delivery,
marketOpportunity, differentiation, businessModel, founderCredibility,
investorAppeal, timing`.

**Derived (computed, no storage):**
- `presentationQuality` = mean(delivery, storytelling, confidence)
- `readiness` = round(0.6·overall + 0.4·investorInterest)
- `confidenceScore` = dimensions.confidence

`Highlight` and `Recommendation` carry a transient `UUID id` (excluded from
`Codable` via `CodingKeys`) purely for SwiftUI `ForEach` identity.

### `SessionRecord` (one practice run — the persisted unit)

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | Stable identity. |
| `date` | `Date` | When recorded (ISO-8601 on disk). |
| `length` | `PitchLength` | `elevator / demoDay / standard / deepDive`. |
| `durationSeconds` | `Double` | How long you actually spoke. |
| `transcript` | `String` | On-device transcription. |
| `analysis` | `PitchAnalysis` | The full verdict. |

### `PitchLength` (the format)
Enum with `title`, `subtitle`, `emoji`, `targetSeconds`, `maxSeconds` (1.5× target,
the recorder's hard cap), and `coachingContext` (fed into the prompt so scoring is
format-aware).

## Persistence (`SessionStore`)

- A single pretty-printed JSON array at
  `~/Library/Application Support/Pickle/sessions.json`.
- `@MainActor ObservableObject`; newest-first in memory.
- Atomic writes (`Data.write(options: .atomic)`), ISO-8601 dates.
- API: `add`, `delete`, `latest`, `bestOverall` — intentionally repository-shaped.

> **SwiftData drop-in.** To move to SwiftData/SQLite, make `SessionRecord` an
> `@Model` class and back `SessionStore` with a `ModelContext`; the method surface
> (`add`/`delete`/`latest`/`bestOverall`) and every call site stay identical. JSON
> is the MVP choice for a zero-dependency, fully reproducible build.

## Progress aggregation (`ProgressTracker`)

A value type over `[SessionRecord]` that produces the trend view:

- `Metric`: `overall · readiness · confidence · presentation`.
- `series(_:)` — chronological plot points (oldest→newest) for the sparkline.
- `current(_:)`, `delta(_:)` — latest value and change vs. the previous run.
- `momentumLine` — a warm one-liner keyed to readiness momentum.

It stores nothing; it's a pure projection of the session list, recomputed on demand.

## Secrets (`Keychain`)

The Anthropic API key is stored as a `kSecClassGenericPassword`
(`service = com.pickle.companion`, `account = anthropic-api-key`,
`kSecAttrAccessibleAfterFirstUnlock`). `save` / `load` / `clear`. It never appears
in UserDefaults, the prompt, the transcript, or logs.

## Data lifetimes

| Data | Where | Lifetime |
|---|---|---|
| Recorded audio | Temp `.m4a` | Deleted right after transcription/analysis. |
| Transcript | In `SessionRecord` | Until you delete the run. |
| Analysis + scores | `sessions.json` | Local, until deleted. |
| API key | Keychain | Until removed in Settings. |
| Anything sent to Claude | The transcript only | Subject to Anthropic's API data policy. |
