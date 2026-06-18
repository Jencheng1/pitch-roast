import Foundation
import Speech

/// Abstraction over speech-to-text so the engine can be swapped (Apple Speech
/// today; whisper.cpp or a cloud STT later) without touching the analyzer.
protocol Transcriber {
    func transcribe(url: URL) async throws -> String
}

/// On-device transcription via Apple's Speech framework. Private by default
/// (`requiresOnDeviceRecognition`), so audio never leaves the Mac for the
/// transcription step — only the resulting text is sent to Claude.
struct SpeechTranscriber: Transcriber {

    enum TranscribeError: LocalizedError {
        case unauthorized
        case unavailable
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .unauthorized: return "Pickle needs permission to transcribe speech (System Settings → Privacy → Speech Recognition)."
            case .unavailable:  return "On-device speech recognition isn't available for your language right now."
            case .failed(let m): return "Transcription failed: \(m)"
            }
        }
    }

    func transcribe(url: URL) async throws -> String {
        try await requestAuthorization()

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else {
            throw TranscribeError.unavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        request.addsPunctuation = true

        return try await withCheckedThrowingContinuation { continuation in
            var finished = false
            recognizer.recognitionTask(with: request) { result, error in
                if let error, !finished {
                    finished = true
                    continuation.resume(throwing: TranscribeError.failed(error.localizedDescription))
                    return
                }
                if let result, result.isFinal, !finished {
                    finished = true
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }

    private func requestAuthorization() async throws {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return
        case .notDetermined:
            let status = await withCheckedContinuation { cont in
                SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
            }
            if status != .authorized { throw TranscribeError.unauthorized }
        default:
            throw TranscribeError.unauthorized
        }
    }
}
