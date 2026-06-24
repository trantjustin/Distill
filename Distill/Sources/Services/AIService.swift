import Foundation

enum AIProvider: String, CaseIterable, Identifiable {
    case openAI      = "OpenAI"
    case claude      = "Claude"
    case gemini      = "Gemini"
    case perplexity  = "Perplexity"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .openAI:     return "sparkles"
        case .claude:     return "wand.and.stars"
        case .gemini:     return "atom"
        case .perplexity: return "magnifyingglass.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .openAI:     return "green"
        case .claude:     return "orange"
        case .gemini:     return "blue"
        case .perplexity: return "purple"
        }
    }

    var apiKeyStorageKey: String {
        switch self {
        case .openAI:     return "openai_api_key"
        case .claude:     return "claude_api_key"
        case .gemini:     return "gemini_api_key"
        case .perplexity: return "perplexity_api_key"
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .openAI:     return "sk-..."
        case .claude:     return "sk-ant-..."
        case .gemini:     return "AIza..."
        case .perplexity: return "pplx-..."
        }
    }

    var docsURL: String {
        switch self {
        case .openAI:     return "platform.openai.com"
        case .claude:     return "console.anthropic.com"
        case .gemini:     return "aistudio.google.com"
        case .perplexity: return "docs.perplexity.ai"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI:     return "gpt-4o-mini"
        case .claude:     return "claude-sonnet-4-6"
        case .gemini:     return "gemini-2.5-flash"
        case .perplexity: return "sonar"
        }
    }
}

struct AIService {
    static let shared = AIService()

    private let prompt = { (title: String, author: String) -> String in
        """
        You are a book knowledge extraction expert. For the book "\(title)" by \(author), generate exactly 8 concise, actionable core learnings or key insights.

        Rules:
        - Each learning must be a single sentence (max 150 characters)
        - Focus on practical, memorable insights
        - No numbered lists or bullet points in the text
        - Return ONLY a JSON array of strings, nothing else

        Example format: ["Learning one.", "Learning two.", ...]
        """
    }

    func validateKey(for provider: AIProvider, apiKey: String) -> Bool {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count >= 20 else { return false }
        switch provider {
        case .openAI:     return key.hasPrefix("sk-")
        case .claude:     return key.hasPrefix("sk-ant-")
        case .gemini:     return key.hasPrefix("AIza")
        case .perplexity: return key.hasPrefix("pplx-")
        }
    }

    func generateLearnings(for title: String, author: String, provider: AIProvider, apiKey: String) async throws -> [String] {
        switch provider {
        case .openAI:     return try await callOpenAI(title: title, author: author, apiKey: apiKey)
        case .claude:     return try await callClaude(title: title, author: author, apiKey: apiKey)
        case .gemini:     return try await callGemini(title: title, author: author, apiKey: apiKey)
        case .perplexity: return try await callPerplexity(title: title, author: author, apiKey: apiKey)
        }
    }

    private func callOpenAI(title: String, author: String, apiKey: String) async throws -> [String] {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": AIProvider.openAI.defaultModel,
            "messages": [["role": "user", "content": prompt(title, author)]],
            "temperature": 0.7,
            "max_tokens": 1000
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTP(response, data: data, provider: .openAI)

        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else { throw AIError.noContent }
        return try parseJSON(content)
    }

    private func callClaude(title: String, author: String, apiKey: String) async throws -> [String] {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": AIProvider.claude.defaultModel,
            "max_tokens": 1000,
            "messages": [["role": "user", "content": prompt(title, author)]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTP(response, data: data, provider: .claude)

        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let content = decoded.content.first?.text else { throw AIError.noContent }
        return try parseJSON(content)
    }

    private func callGemini(title: String, author: String, apiKey: String) async throws -> [String] {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(AIProvider.gemini.defaultModel):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt(title, author)]]]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTP(response, data: data, provider: .gemini)

        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let content = decoded.candidates.first?.content.parts.first?.text else { throw AIError.noContent }
        return try parseJSON(content)
    }

    private func callPerplexity(title: String, author: String, apiKey: String) async throws -> [String] {
        let url = URL(string: "https://api.perplexity.ai/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": AIProvider.perplexity.defaultModel,
            "messages": [["role": "user", "content": prompt(title, author)]],
            "max_tokens": 1000
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTP(response, data: data, provider: .perplexity)

        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else { throw AIError.noContent }
        return try parseJSON(content)
    }

    private func checkHTTP(_ response: URLResponse, data: Data, provider: AIProvider) throws {
        guard let http = response as? HTTPURLResponse else { throw AIError.invalidResponse }
        guard http.statusCode == 200 else {
            let apiMessage = extractErrorMessage(from: data)
            switch http.statusCode {
            case 401, 403:
                throw AIError.invalidAPIKey(provider: provider)
            case 429:
                throw AIError.rateLimited(provider: provider)
            case 400:
                throw AIError.badRequest(apiMessage ?? "Bad request")
            case 500...599:
                throw AIError.serverError(provider: provider, code: http.statusCode)
            default:
                throw AIError.httpError(http.statusCode, apiMessage)
            }
        }
    }

    private func extractErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let error = json["error"] as? [String: Any], let msg = error["message"] as? String { return msg }
        if let error = json["error"] as? String { return error }
        if let detail = json["detail"] as? String { return detail }
        return nil
    }

    private func parseJSON(_ content: String) throws -> [String] {
        let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonString: String
        if let start = cleaned.firstIndex(of: "["), let end = cleaned.lastIndex(of: "]") {
            jsonString = String(cleaned[start...end])
        } else {
            jsonString = cleaned
        }
        guard let data = jsonString.data(using: .utf8),
              let learnings = try? JSONDecoder().decode([String].self, from: data) else {
            throw AIError.parseError
        }
        return learnings
    }
}

private struct OpenAIResponse: Decodable {
    let choices: [Choice]
    struct Choice: Decodable {
        let message: Message
    }
    struct Message: Decodable {
        let content: String
    }
}

private struct ClaudeResponse: Decodable {
    let content: [ContentBlock]
    struct ContentBlock: Decodable {
        let text: String
    }
}

private struct GeminiResponse: Decodable {
    let candidates: [Candidate]
    struct Candidate: Decodable {
        let content: Content
    }
    struct Content: Decodable {
        let parts: [Part]
    }
    struct Part: Decodable {
        let text: String
    }
}

enum AIError: LocalizedError {
    case invalidResponse
    case invalidAPIKey(provider: AIProvider)
    case rateLimited(provider: AIProvider)
    case badRequest(String)
    case serverError(provider: AIProvider, code: Int)
    case httpError(Int, String?)
    case noContent
    case parseError

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response."
        case .invalidAPIKey(let provider):
            return "Invalid \(provider.rawValue) API key. Please check Settings."
        case .rateLimited(let provider):
            return "\(provider.rawValue) rate limit reached. Please wait a moment and try again."
        case .badRequest(let msg):
            return "Bad request: \(msg)"
        case .serverError(let provider, let code):
            return "\(provider.rawValue) server error (\(code)). Please try again shortly."
        case .httpError(let code, let msg):
            if let msg { return "Error \(code): \(msg)" }
            return "Unexpected error (HTTP \(code))."
        case .noContent:
            return "No content returned from AI."
        case .parseError:
            return "Failed to parse AI response."
        }
    }
}
