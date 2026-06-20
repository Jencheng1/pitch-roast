import Foundation

/// Orchestrates the full pipeline: audio → transcript → Claude analysis →
/// persisted `SessionRecord`. Pure async; the UI just awaits the result.
struct PitchAnalyzer {
    var transcriber: Transcriber
    var provider: AnalysisProvider

    enum AnalyzerError: LocalizedError {
        case emptyTranscript
        var errorDescription: String? {
            switch self {
            case .emptyTranscript:
                return "Pickle didn't catch any words. Speak a little louder and try again."
            }
        }
    }

    /// Run the pipeline. `onTranscript` lets the UI show the words as soon as
    /// they're ready, before the (slower) analysis returns.
    func run(audioURL: URL,
             length: PitchLength,
             spokenSeconds: Double,
             onTranscript: ((String) -> Void)? = nil) async throws -> SessionRecord {
        let transcript = try await transcriber.transcribe(url: audioURL)
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4 else { throw AnalyzerError.emptyTranscript }
        onTranscript?(trimmed)

        let analysis = try await provider.analyze(
            transcript: trimmed, length: length, spokenSeconds: spokenSeconds)

        return SessionRecord(
            length: length,
            durationSeconds: spokenSeconds,
            transcript: trimmed,
            analysis: analysis
        )
    }

    /// Brain-dump pipeline: audio → transcript → synthesized ideas. When
    /// `priorTranscript` is non-empty (adding on to an existing dump), the new
    /// transcript is appended and the synthesis runs over the full accumulated
    /// thinking. Returns the combined transcript.
    func brainDump(audioURL: URL,
                   spokenSeconds: Double,
                   priorTranscript: String = "",
                   onTranscript: ((String) -> Void)? = nil) async throws -> (String, BrainDumpSynthesis) {
        let fresh = try await transcriber.transcribe(url: audioURL)
        let trimmed = fresh.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4 else { throw AnalyzerError.emptyTranscript }

        let combined = priorTranscript.isEmpty ? trimmed : priorTranscript + "\n\n" + trimmed
        onTranscript?(combined)

        let synthesis = try await provider.synthesize(
            transcript: combined, spokenSeconds: spokenSeconds)
        return (combined, synthesis)
    }
}
