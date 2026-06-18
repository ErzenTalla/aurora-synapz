import Foundation

enum APIError: LocalizedError {
    case invalidResponse
    case serverError(String)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidResponse:    return "Invalid server response"
        case .serverError(let m): return m
        case .unauthorized:       return "Aurora's shared secret was rejected by the server."
        }
    }
}

class APIService {
    static let shared = APIService()
    private let base = "https://omnia-aurora.vercel.app"
    private let sharedSecret = "3c7f9ea4fd5b9377dac5148f419bb3d09752ec473643fc2bf15e5f3399d557fe"

    private func request<T: Decodable>(_ path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> T {
        guard let url = URL(string: "\(base)\(path)") else { throw APIError.invalidResponse }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(sharedSecret, forHTTPHeaderField: "X-Aurora-Secret")
        if let body { req.httpBody = try? JSONSerialization.data(withJSONObject: body) }

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 401 { throw APIError.unauthorized }

        let decoder = JSONDecoder()
        if http.statusCode >= 400 {
            if let err = try? decoder.decode([String: String].self, from: data),
               let msg = err["error"] { throw APIError.serverError(msg) }
            throw APIError.serverError("Request failed (\(http.statusCode))")
        }
        return try decoder.decode(T.self, from: data)
    }

    func generateBriefing(answers: [String: String]) async throws -> BriefingResponse {
        try await request("/api/briefing", method: "POST", body: answers)
    }

    func listBriefings() async throws -> [BriefingSummary] {
        let response: BriefingsListResponse = try await request("/api/briefings", method: "GET")
        return response.briefings
    }

    func fetchBriefing(date: String) async throws -> BriefingResponse {
        try await request("/api/briefings?date=\(date)", method: "GET")
    }

    func fetchProfile() async throws -> ProfileResponse {
        try await request("/api/profile", method: "GET")
    }

    func saveProfile(_ profile: String) async throws {
        let _: ProfileResponse = try await request("/api/profile", method: "POST", body: ["profile": profile])
    }

    func sendChat(briefingDate: String, briefingText: String, messages: [ChatMessage]) async throws -> String {
        let body: [String: Any] = [
            "briefingDate": briefingDate,
            "briefingText": briefingText,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] },
        ]
        let reply: ChatReply = try await request("/api/chat", method: "POST", body: body)
        return reply.reply
    }
}
