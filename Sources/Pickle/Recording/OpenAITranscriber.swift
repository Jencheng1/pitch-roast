import Foundation

/// The default transcriber: OpenAI Whisper (`whisper-1`) over the audio
/// transcriptions endpoint. Used whenever an OpenAI key is present; otherwise
/// the app falls back to on-device `SpeechTranscriber`.
///
/// Note: unlike the Apple path, this uploads the recorded audio to OpenAI.
struct OpenAITranscriber: Transcriber {
    var apiKey: String
    var model = "whisper-1"
    var session: URLSession = .shared

    func transcribe(url: URL) async throws -> String {
        let audio = try Data(contentsOf: url)
        let boundary = "PickleBoundary-\(UUID().uuidString)"

        var body = Data()
        body.appendField("model", model, boundary: boundary)
        body.appendField("response_format", "text", boundary: boundary)
        body.appendFile(audio, name: "file", filename: "pitch.m4a",
                        contentType: "audio/m4a", boundary: boundary)
        body.appendString("--\(boundary)--\r\n")

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ProviderError.http(-1, "No response.") }
        guard (200..<300).contains(http.statusCode) else {
            throw ProviderError.http(http.statusCode, OpenAIClient.apiMessage(from: data))
        }
        // response_format=text → the body is the raw transcript.
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

// MARK: - Multipart form helpers

extension Data {
    mutating func appendString(_ string: String) {
        if let d = string.data(using: .utf8) { append(d) }
    }

    mutating func appendField(_ name: String, _ value: String, boundary: String) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        appendString("\(value)\r\n")
    }

    mutating func appendFile(_ data: Data, name: String, filename: String,
                             contentType: String, boundary: String) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        appendString("Content-Type: \(contentType)\r\n\r\n")
        append(data)
        appendString("\r\n")
    }
}
