import Foundation

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

    func generateLearnings(for title: String, author: String) async throws -> [(chapter: String, text: String)] {
        #if DEBUG
        let receipt = "debug_bypass"
        #else
        let receipt = try await ReceiptProvider.receiptBase64()
        #endif

        guard let url = URL(string: BackendConfig.baseURL.absoluteString + BackendConfig.extractPath) else {
            throw AIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(receipt, forHTTPHeaderField: "X-Receipt-Data")

        let body: [String: Any] = ["title": title, "author": author]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await withRetry(maxAttempts: 3) {
            let (data, response) = try await URLSession.shared.data(for: request)
            try self.checkHTTP(response, data: data)
            let decoded = try JSONDecoder().decode(BackendExtractResponse.self, from: data)
            return decoded.learnings.map { ($0.chapter, $0.text) }
        }
    }

    private func withRetry<T>(maxAttempts: Int, operation: () async throws -> T) async throws -> T {
        var lastError: Error?
        for attempt in 0..<maxAttempts {
            do {
                return try await operation()
            } catch AIError.serverError {
                lastError = AIError.serverError(code: 500)
                if attempt < maxAttempts - 1 {
                    let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                    try? await Task.sleep(nanoseconds: delay)
                }
            } catch {
                throw error
            }
        }
        throw lastError ?? AIError.serverError(code: 500)
    }

    private func checkHTTP(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw AIError.invalidResponse }
        guard http.statusCode == 200 else {
            let message = extractErrorMessage(from: data) ?? "Unknown error"
            switch http.statusCode {
            case 401, 403:
                throw AIError.subscriptionRequired
            case 429:
                throw AIError.rateLimited
            case 400:
                throw AIError.badRequest(message)
            case 500...599:
                throw AIError.serverError(code: http.statusCode)
            default:
                throw AIError.httpError(http.statusCode, message)
            }
        }
    }

    private func extractErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["error"] as? String ?? json["message"] as? String
    }
}

private struct BackendLearningItem: Decodable {
    let chapter: String
    let text: String
}

private struct BackendExtractResponse: Decodable {
    let learnings: [BackendLearningItem]
}

enum AIError: LocalizedError {
    case invalidResponse
    case subscriptionRequired
    case rateLimited
    case badRequest(String)
    case serverError(code: Int)
    case httpError(Int, String?)
    case noContent
    case parseError

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response."
        case .subscriptionRequired:
            return "An active subscription is required to generate learnings."
        case .rateLimited:
            return "Rate limit reached. Please wait a moment and try again."
        case .badRequest(let msg):
            return "Bad request: \(msg)"
        case .serverError:
            return "Something went wrong on our end. Please try again."
        case .httpError(let code, let msg):
            if let msg { return "Error \(code): \(msg)" }
            return "Unexpected error (HTTP \(code))."
        case .noContent:
            return "No content returned."
        case .parseError:
            return "Failed to parse response."
        }
    }
}
