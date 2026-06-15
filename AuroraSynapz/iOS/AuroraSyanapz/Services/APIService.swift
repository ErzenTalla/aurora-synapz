import Foundation

enum APIError: LocalizedError {
    case invalidResponse
    case serverError(String)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidResponse:    return "Invalid server response"
        case .serverError(let m): return m
        case .unauthorized:       return "Session expired. Please log in again."
        }
    }
}

class APIService {
    static let shared = APIService()
    private let base = "https://aurorasyanapz.com"

    private func request<T: Decodable>(_ path: String, method: String = "GET", body: [String: Any]? = nil, token: String? = nil) async throws -> T {
        guard let url = URL(string: "\(base)\(path)") else { throw APIError.invalidResponse }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body  { req.httpBody = try? JSONSerialization.data(withJSONObject: body) }

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

    // ── Auth ──
    func login(email: String, password: String) async throws -> LoginResponse {
        try await request("/api/auth/login", method: "POST", body: ["email": email, "password": password])
    }

    func changePassword(current: String, new: String, token: String) async throws {
        struct Res: Decodable { let message: String }
        let _: Res = try await request("/api/auth/change-password", method: "POST",
            body: ["currentPassword": current, "newPassword": new], token: token)
    }

    // ── Client portal ──
    func fetchOverview(token: String) async throws -> Portfolio {
        try await request("/api/portal/overview", token: token)
    }

    func fetchHoldings(token: String) async throws -> [Holding] {
        try await request("/api/portal/holdings", token: token)
    }

    func fetchTransactions(token: String, limit: Int = 50) async throws -> [Transaction] {
        try await request("/api/portal/transactions?limit=\(limit)", token: token)
    }

    func fetchPerformance(token: String, range: String = "1Y") async throws -> [PerformancePoint] {
        try await request("/api/portal/performance?range=\(range)", token: token)
    }

    func fetchAllocation(token: String) async throws -> [AllocationItem] {
        try await request("/api/portal/allocation", token: token)
    }

    func fetchDocuments(token: String) async throws -> [Document] {
        try await request("/api/portal/documents", token: token)
    }

    // ── Admin ──
    func fetchAdminStats(token: String) async throws -> AdminStats {
        try await request("/api/admin/stats", token: token)
    }

    func fetchAdminUsers(token: String) async throws -> [AdminUser] {
        try await request("/api/admin/users", token: token)
    }

    func fetchAdminContacts(token: String) async throws -> [Contact] {
        try await request("/api/admin/contacts", token: token)
    }

    func createUser(name: String, email: String, password: String, token: String) async throws -> AdminUser {
        try await request("/api/admin/users", method: "POST",
            body: ["name": name, "email": email, "password": password, "role": "client"], token: token)
    }

    func deleteUser(id: Int, token: String) async throws {
        struct Res: Decodable { let deleted: Int }
        let _: Res = try await request("/api/admin/users/\(id)", method: "DELETE", token: token)
    }
}
