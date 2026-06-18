import Foundation
import AVFoundation

/// Gives Pickle a voice. By default he speaks through OpenAI TTS (`tts-1`, a
/// deep "onyx" investor voice); with no OpenAI key he falls back to the built-in
/// on-device `AVSpeechSynthesizer`. Used to read the roast/verdict aloud.
@MainActor
final class VoiceCoach: NSObject, ObservableObject {
    @Published private(set) var isSpeaking = false

    private let apple = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    private var task: Task<Void, Never>?
    private var session: URLSession = .shared

    override init() {
        super.init()
        apple.delegate = self
    }

    /// Speak `text`. Prefers OpenAI TTS when `openAIKey` is set; otherwise Apple.
    func speak(_ text: String, openAIKey: String?) {
        stop()
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return }

        if let key = openAIKey, !key.isEmpty {
            isSpeaking = true
            task = Task { await self.speakOpenAI(line, key: key) }
        } else {
            speakApple(line)
        }
    }

    func stop() {
        task?.cancel(); task = nil
        player?.stop(); player = nil
        if apple.isSpeaking { apple.stopSpeaking(at: .immediate) }
        isSpeaking = false
    }

    // MARK: OpenAI TTS

    private func speakOpenAI(_ text: String, key: String) async {
        do {
            let body: [String: Any] = [
                "model": "tts-1",
                "voice": "onyx",
                "input": text,
                "response_format": "mp3"
            ]
            var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/speech")!)
            request.httpMethod = "POST"
            request.timeoutInterval = 60
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await session.data(for: request)
            guard !Task.isCancelled else { return }
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                // Fall back to the on-device voice if the API errors out.
                speakApple(text); return
            }
            let p = try AVAudioPlayer(data: data)
            p.delegate = self
            player = p
            p.play()
        } catch {
            guard !Task.isCancelled else { return }
            speakApple(text)
        }
    }

    // MARK: Apple fallback

    private func speakApple(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        utterance.pitchMultiplier = 0.92
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        isSpeaking = true
        apple.speak(utterance)
    }
}

extension VoiceCoach: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.isSpeaking = false }
    }
}

extension VoiceCoach: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}
