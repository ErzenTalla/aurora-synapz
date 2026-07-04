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

    func sendChat(briefingDate: String, briefingText: String, messages: [ChatMessage]) async throws -> ChatReply {
        let body: [String: Any] = [
            "briefingDate": briefingDate,
            "briefingText": briefingText,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] },
        ]
        return try await request("/api/chat", method: "POST", body: body)
    }

    func fetchChatHistory(date: String) async throws -> [ChatMessage] {
        let response: ChatHistoryResponse = try await request("/api/chat-history?date=\(date)", method: "GET")
        return response.messages
    }

    func saveChatHistory(date: String, messages: [ChatMessage]) async throws {
        let body: [String: Any] = ["messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] }]
        let _: ChatHistoryResponse = try await request("/api/chat-history?date=\(date)", method: "POST", body: body)
    }

    func listTasks() async throws -> [TaskItem] {
        let response: TasksResponse = try await request("/api/tasks", method: "GET")
        return response.tasks
    }

    func addTask(text: String, domain: String) async throws -> TaskItem {
        try await request("/api/tasks", method: "POST", body: ["text": text, "domain": domain, "status": "open"])
    }

    func setTaskStatus(id: String, status: String) async throws -> TaskItem {
        try await request("/api/tasks?id=\(id)", method: "PATCH", body: ["status": status])
    }

    func deleteTask(id: String) async throws {
        let _: EmptyResponse = try await request("/api/tasks?id=\(id)", method: "DELETE")
    }

    func listNotes() async throws -> [NoteItem] {
        let response: NotesResponse = try await request("/api/notes", method: "GET")
        return response.notes
    }

    func addNote(text: String, domain: String) async throws -> NoteItem {
        try await request("/api/notes", method: "POST", body: ["text": text, "domain": domain])
    }

    func deleteNote(id: String) async throws {
        let _: EmptyResponse = try await request("/api/notes?id=\(id)", method: "DELETE")
    }

    func listKnowledge() async throws -> [KnowledgeFact] {
        let response: KnowledgeResponse = try await request("/api/knowledge", method: "GET")
        return response.facts
    }

    func addKnowledge(text: String) async throws -> KnowledgeFact {
        try await request("/api/knowledge", method: "POST", body: ["text": text])
    }

    func deleteKnowledge(id: String) async throws {
        let _: EmptyResponse = try await request("/api/knowledge?id=\(id)", method: "DELETE")
    }

    var googleAuthURL: URL { URL(string: "\(base)/api/google-auth-start")! }

    func checkGoogleStatus() async throws -> GoogleStatus {
        try await request("/api/google-status", method: "GET")
    }

    func disconnectGoogle() async throws {
        let _: EmptyResponse = try await request("/api/google-disconnect", method: "POST")
    }
}

struct EmptyResponse: Decodable {}
