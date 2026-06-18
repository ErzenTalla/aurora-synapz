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

    func generateBriefing(answers: [String: String]) async throws -> BriefingResponse {
        guard let url = URL(string: "\(base)/api/briefing") else { throw APIError.invalidResponse }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(sharedSecret, forHTTPHeaderField: "X-Aurora-Secret")
        req.httpBody = try? JSONSerialization.data(withJSONObject: answers)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 401 { throw APIError.unauthorized }

        let decoder = JSONDecoder()
        if http.statusCode >= 400 {
            if let err = try? decoder.decode([String: String].self, from: data),
               let msg = err["error"] { throw APIError.serverError(msg) }
            throw APIError.serverError("Request failed (\(http.statusCode))")
        }
        return try decoder.decode(BriefingResponse.self, from: data)
    }
}
