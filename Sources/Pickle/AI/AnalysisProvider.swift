import Foundation

/// An engine that turns a pitch transcript into a `PitchAnalysis`. Both
/// `OpenAIClient` (default) and `ClaudeClient` (optional) conform, so the rest
/// of the app is provider-agnostic.
protocol AnalysisProvider {
    func analyze(transcript: String,
                 length: PitchLength,
                 spokenSeconds: Double) async throws -> PitchAnalysis

    /// Brain-dump mode: synthesize freeform thinking into structured ideas.
    func synthesize(transcript: String,
                    spokenSeconds: Double) async throws -> BrainDumpSynthesis

    /// Continuing a brain dump: reply conversationally to a single new thought,
    /// given the prior context — no full re-synthesis. Returns plain text.
    func reply(context: String, newThought: String) async throws -> String
}

/// Shared error type for provider clients.
enum ProviderError: LocalizedError {
    case missingKey(String)
    case http(Int, String)
    case refusal(String)
    case noContent
    case decode(String)

    var errorDescription: String? {
        switch self {
        case .missingKey(let who): return "Add your \(who) API key in Settings so Pickle can think."
        case .http(let c, let m):  return "Pickle hit an API error (\(c)). \(m)"
        case .refusal(let why):    return "Pickle declined to analyze that: \(why)"
        case .noContent:           return "Pickle got an unexpected response shape."
        case .decode(let m):       return "Pickle couldn't read the analysis: \(m)"
        }
    }
}

/// Which engine analyzes the pitch. OpenAI is the default for new users; Claude
/// is opt-in. (Transcription + voice always prefer OpenAI when its key is set,
/// independent of this choice, falling back to on-device Apple frameworks.)
enum AnalysisProviderKind: String, CaseIterable, Identifiable, Codable {
    case openai
    case claude

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openai: return "OpenAI"
        case .claude: return "Claude"
        }
    }

    var subtitle: String {
        switch self {
        case .openai: return "GPT-4o · default"
        case .claude: return "Opus 4.8 · optional"
        }
    }

    /// The provider's display name for "add your … key" prompts.
    var keyName: String {
        switch self {
        case .openai: return "OpenAI"
        case .claude: return "Anthropic"
        }
    }
}
