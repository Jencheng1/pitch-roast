import Foundation

/// The default analysis provider. Talks to the OpenAI Chat Completions API over
/// raw `URLSession` (no official Swift SDK), using `gpt-4o` with **strict
/// JSON-schema structured outputs**. Powers both the pitch analysis and the
/// brain-dump synthesis — same engine, different schema + persona.
struct OpenAIClient: AnalysisProvider {
    var apiKey: String?
    var model = "gpt-4o"
    var session: URLSession = .shared

    func analyze(transcript: String,
                 length: PitchLength,
                 spokenSeconds: Double) async throws -> PitchAnalysis {
        let text = try await complete(
            system: PicklePrompts.system,
            user: PicklePrompts.userMessage(transcript: transcript, length: length, spokenSeconds: spokenSeconds),
            schemaName: "pitch_analysis",
            schema: AnalysisSchema.object)
        return try Self.decode(PitchAnalysis.self, from: text)
    }

    func synthesize(transcript: String,
                    spokenSeconds: Double) async throws -> BrainDumpSynthesis {
        let text = try await complete(
            system: BrainDumpPrompts.system,
            user: BrainDumpPrompts.userMessage(transcript: transcript, spokenSeconds: spokenSeconds),
            schemaName: "brain_dump",
            schema: BrainDumpSchema.object)
        return try Self.decode(BrainDumpSynthesis.self, from: text)
    }

    func reply(context: String, newThought: String) async throws -> String {
        try await complete(
            system: BrainDumpPrompts.replySystem,
            user: BrainDumpPrompts.replyMessage(context: context, newThought: newThought),
            maxTokens: 600,
            format: nil)   // plain conversational text — no schema
    }

    // MARK: Request

    private func complete(system: String, user: String,
                          schemaName: String, schema: Any) async throws -> String {
        try await complete(system: system, user: user, maxTokens: 8_000,
                           format: ["type": "json_schema",
                                    "json_schema": ["name": schemaName, "strict": true, "schema": schema]])
    }

    private func complete(system: String, user: String,
                          maxTokens: Int, format: [String: Any]?) async throws -> String {
        guard let apiKey, !apiKey.isEmpty else { throw ProviderError.missingKey("OpenAI") }

        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ]
        if let format { body["response_format"] = format }

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
        return try Self.contentText(from: data)
    }

    // MARK: Parsing

    /// Extracts the model's JSON text from a chat-completions response.
    static func contentText(from data: Data) throws -> String {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any]
        else { throw ProviderError.noContent }

        if let refusal = message["refusal"] as? String, !refusal.isEmpty {
            throw ProviderError.refusal(refusal)
        }
        guard let content = message["content"] as? String, !content.isEmpty else {
            throw ProviderError.noContent
        }
        return content
    }

    static func decode<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        guard let payload = text.data(using: .utf8) else { throw ProviderError.noContent }
        do { return try JSONDecoder().decode(T.self, from: payload) }
        catch { throw ProviderError.decode(error.localizedDescription) }
    }

    static func apiMessage(from data: Data) -> String {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let err = root["error"] as? [String: Any],
              let msg = err["message"] as? String
        else { return "Try again in a moment." }
        return msg
    }
}
