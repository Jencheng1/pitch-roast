import Foundation

/// Runs live competitive research for a startup concept: search the web, then
/// structure the findings into a `Landscape`. Best-effort — callers fall back to
/// the knowledge-based landscape if this throws.
protocol LandscapeResearcher {
    func research(ideaName: String, problem: String, category: String,
                  customer: String, valueProp: String) async throws -> BrainDumpSynthesis.Landscape
}

// MARK: - Claude (server-side web_search tool)

/// Uses Claude's server-side `web_search` tool to find current competitors, then
/// a second structured-output call to shape them. Two calls avoid the
/// citations-vs-structured-output conflict.
struct ClaudeLandscapeResearcher: LandscapeResearcher {
    var apiKey: String
    var model = "claude-opus-4-8"
    var session: URLSession = .shared

    func research(ideaName: String, problem: String, category: String,
                  customer: String, valueProp: String) async throws -> BrainDumpSynthesis.Landscape {
        let findings = try await search(ideaName: ideaName, problem: problem, category: category,
                                        customer: customer, valueProp: valueProp)
        return try await structure(findings: findings)
    }

    private func search(ideaName: String, problem: String, category: String,
                        customer: String, valueProp: String) async throws -> String {
        var messages: [[String: Any]] = [[
            "role": "user",
            "content": LandscapePrompts.searchUser(ideaName: ideaName, problem: problem, category: category,
                                                   customer: customer, valueProp: valueProp)
        ]]
        var collected = ""

        // Server tool loop: re-send on pause_turn until the model finishes.
        for _ in 0..<5 {
            let body: [String: Any] = [
                "model": model,
                "max_tokens": 4_000,
                "system": LandscapePrompts.searchSystem,
                "tools": [["type": "web_search_20260209", "name": "web_search", "max_uses": 5]],
                "messages": messages
            ]
            let root = try await post("https://api.anthropic.com/v1/messages",
                                      body: body, headers: anthropicHeaders)
            let content = root["content"] as? [[String: Any]] ?? []
            let text = content
                .filter { ($0["type"] as? String) == "text" }
                .compactMap { $0["text"] as? String }
                .joined(separator: "\n")
            if !text.isEmpty { collected += (collected.isEmpty ? "" : "\n") + text }

            if (root["stop_reason"] as? String) == "pause_turn" {
                messages.append(["role": "assistant", "content": content])
                continue
            }
            break
        }
        guard collected.count > 20 else { throw ProviderError.noContent }
        return collected
    }

    private func structure(findings: String) async throws -> BrainDumpSynthesis.Landscape {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4_000,
            "system": LandscapePrompts.structureSystem,
            "thinking": ["type": "adaptive"],
            "output_config": ["effort": "low",
                              "format": ["type": "json_schema", "schema": LandscapeSchema.object]],
            "messages": [["role": "user", "content": LandscapePrompts.structureMessage(findings: findings)]]
        ]
        let root = try await post("https://api.anthropic.com/v1/messages",
                                  body: body, headers: anthropicHeaders)
        guard let content = root["content"] as? [[String: Any]],
              let text = content.first(where: { ($0["type"] as? String) == "text" })?["text"] as? String,
              let data = text.data(using: .utf8)
        else { throw ProviderError.noContent }
        return try JSONDecoder().decode(BrainDumpSynthesis.Landscape.self, from: data)
    }

    private var anthropicHeaders: [String: String] {
        ["Content-Type": "application/json", "x-api-key": apiKey, "anthropic-version": "2023-06-01"]
    }

    private func post(_ urlString: String, body: [String: Any],
                      headers: [String: String]) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ProviderError.http((response as? HTTPURLResponse)?.statusCode ?? -1, "Search failed.")
        }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderError.noContent
        }
        return root
    }
}

// MARK: - OpenAI (Responses API web_search tool)

/// Uses the OpenAI Responses API `web_search` tool to find competitors, then a
/// chat-completions structured call to shape them.
struct OpenAILandscapeResearcher: LandscapeResearcher {
    var apiKey: String
    var model = "gpt-4o"
    var session: URLSession = .shared

    func research(ideaName: String, problem: String, category: String,
                  customer: String, valueProp: String) async throws -> BrainDumpSynthesis.Landscape {
        let findings = try await search(ideaName: ideaName, problem: problem, category: category,
                                        customer: customer, valueProp: valueProp)
        return try await structure(findings: findings)
    }

    private func search(ideaName: String, problem: String, category: String,
                        customer: String, valueProp: String) async throws -> String {
        let body: [String: Any] = [
            "model": model,
            "tools": [["type": "web_search"]],
            "max_output_tokens": 2_000,
            "instructions": LandscapePrompts.searchSystem,
            "input": LandscapePrompts.searchUser(ideaName: ideaName, problem: problem, category: category,
                                                 customer: customer, valueProp: valueProp)
        ]
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ProviderError.http((response as? HTTPURLResponse)?.statusCode ?? -1, "Search failed.")
        }
        let text = Self.outputText(from: data)
        guard text.count > 20 else { throw ProviderError.noContent }
        return text
    }

    /// Pull the assistant text out of a Responses API payload.
    private static func outputText(from data: Data) -> String {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return "" }
        if let agg = root["output_text"] as? String, !agg.isEmpty { return agg }
        var text = ""
        for item in (root["output"] as? [[String: Any]] ?? []) where (item["type"] as? String) == "message" {
            for c in (item["content"] as? [[String: Any]] ?? []) {
                if (c["type"] as? String) == "output_text", let t = c["text"] as? String { text += t }
            }
        }
        return text
    }

    private func structure(findings: String) async throws -> BrainDumpSynthesis.Landscape {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4_000,
            "messages": [
                ["role": "system", "content": LandscapePrompts.structureSystem],
                ["role": "user", "content": LandscapePrompts.structureMessage(findings: findings)]
            ],
            "response_format": ["type": "json_schema",
                                "json_schema": ["name": "landscape", "strict": true, "schema": LandscapeSchema.object]]
        ]
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ProviderError.http((response as? HTTPURLResponse)?.statusCode ?? -1, "Structuring failed.")
        }
        let text = try OpenAIClient.contentText(from: data)
        guard let payload = text.data(using: .utf8) else { throw ProviderError.noContent }
        return try JSONDecoder().decode(BrainDumpSynthesis.Landscape.self, from: payload)
    }
}
