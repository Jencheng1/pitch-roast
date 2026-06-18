import Foundation

/// The default analysis provider. Talks to the OpenAI Chat Completions API over
/// raw `URLSession` (no official Swift SDK), using `gpt-4o` with **strict
/// JSON-schema structured outputs** so the response decodes straight into
/// `PitchAnalysis`. Reuses the same Pickle persona + schema as the Claude path.
struct OpenAIClient: AnalysisProvider {
    var apiKey: String?
    var model = "gpt-4o"
    var session: URLSession = .shared

    func analyze(transcript: String,
                 length: PitchLength,
                 spokenSeconds: Double) async throws -> PitchAnalysis {
        guard let apiKey, !apiKey.isEmpty else { throw ProviderError.missingKey("OpenAI") }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 8_000,
            "messages": [
                ["role": "system", "content": PicklePrompts.system],
                ["role": "user", "content": PicklePrompts.userMessage(
                    transcript: transcript, length: length, spokenSeconds: spokenSeconds)]
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": [
                    "name": "pitch_analysis",
                    "strict": true,
                    "schema": AnalysisSchema.object
                ]
            ]
        ]

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ProviderError.http(-1, "No response.") }
        guard (200..<300).contains(http.statusCode) else {
            throw ProviderError.http(http.statusCode, Self.apiMessage(from: data))
        }
        return try Self.decodeAnalysis(from: data)
    }

    // MARK: Parsing

    static func decodeAnalysis(from data: Data) throws -> PitchAnalysis {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any]
        else { throw ProviderError.noContent }

        if let refusal = message["refusal"] as? String, !refusal.isEmpty {
            throw ProviderError.refusal(refusal)
        }
        guard let content = message["content"] as? String, let payload = content.data(using: .utf8) else {
            throw ProviderError.noContent
        }
        do {
            return try JSONDecoder().decode(PitchAnalysis.self, from: payload)
        } catch {
            throw ProviderError.decode(error.localizedDescription)
        }
    }

    static func apiMessage(from data: Data) -> String {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let err = root["error"] as? [String: Any],
              let msg = err["message"] as? String
        else { return "Try again in a moment." }
        return msg
    }
}
