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

extension Notification.Name {
    static let auroraUnauthorized = Notification.Name("auroraUnauthorized")
}

struct SuccessResponse: Decodable { let success: Bool }

class APIService {
    static let shared = APIService()
    private let base = "https://aurorasyanapz.com"

    private func handleResponse<T: Decodable>(_ data: Data, _ response: URLResponse) throws -> T {
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 401 {
            NotificationCenter.default.post(name: .auroraUnauthorized, object: nil)
            throw APIError.unauthorized
        }
        let decoder = JSONDecoder()
        if http.statusCode >= 400 {
            if let err = try? decoder.decode([String: String].self, from: data),
               let msg = err["error"] { throw APIError.serverError(msg) }
            throw APIError.serverError("Request failed (\(http.statusCode))")
        }
        return try decoder.decode(T.self, from: data)
    }

    private func request<T: Decodable>(_ path: String, method: String = "GET", body: [String: Any]? = nil, token: String? = nil) async throws -> T {
        guard let url = URL(string: "\(base)\(path)") else { throw APIError.invalidResponse }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body  { req.httpBody = try? JSONSerialization.data(withJSONObject: body) }

        let (data, response) = try await URLSession.shared.data(for: req)
        return try handleResponse(data, response)
    }

    // Multipart/form-data POST — used for proof-of-payment and document uploads.
    private func requestMultipart<T: Decodable>(
        _ path: String,
        fields: [String: String] = [:],
        fileData: Data?,
        fileFieldName: String = "file",
        fileName: String = "upload.jpg",
        mimeType: String = "image/jpeg",
        token: String? = nil
    ) async throws -> T {
        guard let url = URL(string: "\(base)\(path)") else { throw APIError.invalidResponse }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        var body = Data()
        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        if let fileData {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)
        return try handleResponse(data, response)
    }

    // Raw binary download (document/proof files) — not JSON.
    private func downloadFile(_ path: String, token: String) async throws -> Data {
        guard let url = URL(string: "\(base)\(path)") else { throw APIError.invalidResponse }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 401 {
            NotificationCenter.default.post(name: .auroraUnauthorized, object: nil)
            throw APIError.unauthorized
        }
        if http.statusCode >= 400 { throw APIError.serverError("Download failed (\(http.statusCode))") }
        return data
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

    func downloadDocument(id: Int, token: String) async throws -> Data {
        try await downloadFile("/api/portal/documents/\(id)/download", token: token)
    }

    func withdraw(amount: Double, token: String) async throws -> SuccessResponse {
        try await request("/api/portal/withdraw", method: "POST", body: ["amount": amount], token: token)
    }

    func fetchWithdrawals(token: String) async throws -> [WithdrawalRequest] {
        try await request("/api/portal/withdrawals", token: token)
    }

    func submitDepositRequest(amount: Double, fileData: Data?, fileName: String, mimeType: String, token: String) async throws -> DepositRequest {
        try await requestMultipart(
            "/api/portal/deposit-request",
            fields: ["amount": String(amount)],
            fileData: fileData, fileName: fileName, mimeType: mimeType,
            token: token
        )
    }

    func fetchDepositRequests(token: String) async throws -> [DepositRequest] {
        try await request("/api/portal/deposit-requests", token: token)
    }

    func downloadDepositProof(id: Int, token: String) async throws -> Data {
        try await downloadFile("/api/portal/deposit-requests/\(id)/proof", token: token)
    }

    func fetchFund(token: String) async throws -> Fund {
        struct StatusResponse: Decodable { let fund: Fund }
        let res: StatusResponse = try await request("/api/alpaca/status", token: token)
        return res.fund
    }

    // ── Admin: users/stats/contacts ──
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

    // ── Admin: deposit requests + invest ──
    func fetchAdminDepositRequests(token: String) async throws -> [DepositRequest] {
        try await request("/api/admin/deposit-requests", token: token)
    }

    func downloadAdminDepositProof(id: Int, token: String) async throws -> Data {
        try await downloadFile("/api/admin/deposit-requests/\(id)/proof", token: token)
    }

    func updateDepositRequestStatus(id: Int, status: String, notes: String? = nil, token: String) async throws -> SuccessResponse {
        var body: [String: Any] = ["status": status]
        if let notes { body["notes"] = notes }
        return try await request("/api/admin/deposit-requests/\(id)/status", method: "PATCH", body: body, token: token)
    }

    func fetchInvestCash(token: String) async throws -> InvestCashStatus {
        try await request("/api/admin/invest/cash", token: token)
    }

    func investCash(amount: Double, token: String) async throws -> InvestResult {
        try await request("/api/admin/invest", method: "POST", body: ["amount": amount], token: token)
    }

    // ── Admin: withdrawals ──
    func fetchAdminWithdrawals(token: String) async throws -> [WithdrawalRequest] {
        try await request("/api/admin/withdrawals", token: token)
    }

    func updateWithdrawalStatus(id: Int, status: String, notes: String? = nil, token: String) async throws -> SuccessResponse {
        var body: [String: Any] = ["status": status]
        if let notes { body["notes"] = notes }
        return try await request("/api/admin/withdrawals/\(id)/status", method: "PATCH", body: body, token: token)
    }

    // ── Admin: fee management ──
    func fetchFeePreview(token: String) async throws -> FeePreviewResult {
        try await request("/api/admin/fee/preview", token: token)
    }

    func collectFees(token: String) async throws -> FeePreviewResult {
        try await request("/api/admin/fee/collect", method: "POST", token: token)
    }

    func setFeeRate(userId: Int, rate: Double, token: String) async throws -> SuccessResponse {
        try await request("/api/admin/users/\(userId)/fee-rate", method: "PATCH", body: ["fee_rate": rate], token: token)
    }

    // ── Admin: documents ──
    func fetchAdminDocuments(token: String) async throws -> [Document] {
        try await request("/api/admin/documents", token: token)
    }

    func uploadDocument(userId: Int, title: String, type: String, period: String, fileData: Data, fileName: String, mimeType: String, token: String) async throws -> Document {
        try await requestMultipart(
            "/api/admin/documents",
            fields: ["user_id": String(userId), "title": title, "type": type, "period": period],
            fileData: fileData, fileName: fileName, mimeType: mimeType,
            token: token
        )
    }

    func deleteDocument(id: Int, token: String) async throws {
        struct Res: Decodable { let deleted: Int }
        let _: Res = try await request("/api/admin/documents/\(id)", method: "DELETE", token: token)
    }

    // ── Admin: Stripe deposit history ──
    func fetchAdminDeposits(token: String) async throws -> [StripeDeposit] {
        try await request("/api/admin/deposits", token: token)
    }
}
