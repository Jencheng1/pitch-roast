import Foundation

/// Talks to the Anthropic Messages API over raw `URLSession` (Swift has no
/// official SDK). Uses `claude-opus-4-8` with adaptive thinking and structured
/// outputs. The optional analysis provider — users opt in via Settings. Powers
/// both the pitch analysis and the brain-dump synthesis.
struct ClaudeClient: AnalysisProvider {

    enum ClientError: LocalizedError {
        case missingKey
        case http(Int, String)
        case refusal(String)
        case noTextBlock
        case decode(String)

        var errorDescription: String? {
            switch self {
            case .missingKey:       return "Add your Anthropic API key in Settings so Pickle can think."
            case .http(let c, let m): return "Pickle hit an API error (\(c)). \(m)"
            case .refusal(let why): return "Pickle declined to analyze that: \(why)"
            case .noTextBlock:      return "Pickle got an unexpected response shape."
            case .decode(let m):    return "Pickle couldn't read the analysis: \(m)"
            }
        }
    }

    var apiKey: String?
    var model = "claude-opus-4-8"
    var session: URLSession = .shared

    func analyze(transcript: String,
                 length: PitchLength,
                 spokenSeconds: Double) async throws -> PitchAnalysis {
        let text = try await completeText(
            system: PicklePrompts.system,
            userText: PicklePrompts.userMessage(transcript: transcript, length: length, spokenSeconds: spokenSeconds),
            schema: AnalysisSchema.object)
        return try decode(PitchAnalysis.self, from: text)
    }

    func synthesize(transcript: String,
                    spokenSeconds: Double) async throws -> BrainDumpSynthesis {
        let text = try await completeText(
            system: BrainDumpPrompts.system,
            userText: BrainDumpPrompts.userMessage(transcript: transcript, spokenSeconds: spokenSeconds),
            schema: BrainDumpSchema.object)
        return try decode(BrainDumpSynthesis.self, from: text)
    }

    func reply(context: String, newThought: String) async throws -> String {
        // Plain conversational reply — no schema, lower effort for snappiness.
        try await completeText(
            system: BrainDumpPrompts.replySystem,
            userText: BrainDumpPrompts.replyMessage(context: context, newThought: newThought),
            schema: nil, maxTokens: 1_024, effort: "low")
    }

    // MARK: Request

    private func completeText(system: String, userText: String,
                              schema: Any?, maxTokens: Int = 16_000,
                              effort: String = "medium") async throws -> String {
        guard let apiKey, !apiKey.isEmpty else { throw ClientError.missingKey }

        var outputConfig: [String: Any] = ["effort": effort]
        if let schema { outputConfig["format"] = ["type": "json_schema", "schema": schema] }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            // Frozen persona first → caches across runs. cache_control on the block.
            "system": [[
                "type": "text",
                "text": system,
                "cache_control": ["type": "ephemeral"]
            ]],
            "thinking": ["type": "adaptive"],
            "output_config": outputConfig,
            "messages": [["role": "user", "content": userText]]
        ]

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.http(-1, "No response.") }
        guard (200..<300).contains(http.statusCode) else {
            throw ClientError.http(http.statusCode, apiMessage(from: data))
        }
        return try textBlock(from: data)
    }

    // MARK: Parsing

    private func textBlock(from data: Data) throws -> String {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClientError.decode("Top-level JSON was not an object.")
        }
        if (root["stop_reason"] as? String) == "refusal" {
            let why = ((root["stop_details"] as? [String: Any])?["explanation"] as? String) ?? "safety"
            throw ClientError.refusal(why)
        }
        // Structured outputs guarantee the first text block is valid schema JSON.
        guard let content = root["content"] as? [[String: Any]],
              let text = content.first(where: { ($0["type"] as? String) == "text" })?["text"] as? String
        else { throw ClientError.noTextBlock }
        return text
    }

    private func decode<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        guard let payload = text.data(using: .utf8) else { throw ClientError.noTextBlock }
        do { return try JSONDecoder().decode(T.self, from: payload) }
        catch { throw ClientError.decode(error.localizedDescription) }
    }

    private func apiMessage(from data: Data) -> String {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let err = root["error"] as? [String: Any],
              let msg = err["message"] as? String
        else { return "Try again in a moment." }
        return msg
    }
}
