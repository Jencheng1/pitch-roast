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
}
