import Foundation

struct Question: Identifiable {
    let id: String
    let prompt: String
}

let questions: [Question] = [
    Question(id: "calendar", prompt: "Calendar/today — meetings, appointments, travel?"),
    Question(id: "work", prompt: "Work — anything pressing, deadlines, leadership topics?"),
    Question(id: "alpinetech", prompt: "AlpineTech — active work, blockers, decisions?"),
    Question(id: "omnia", prompt: "Omnia OS / Aurora — anything for this project today?"),
    Question(id: "personal", prompt: "Personal — family, health, sleep, anything worth flagging?"),
    Question(id: "concerns", prompt: "Concerns — anything uncertain or weighing on you?"),
]

struct BriefingResponse: Decodable, Identifiable {
    let date: String
    let briefing: String
    var id: String { date }
}

struct BriefingSummary: Decodable, Identifiable {
    let date: String
    let url: String
    var id: String { date }
}

struct BriefingsListResponse: Decodable {
    let briefings: [BriefingSummary]
}

struct ChatMessage: Codable, Identifiable, Equatable {
    enum Role: String, Codable { case user, assistant }
    let id: UUID
    let role: Role
    let content: String

    init(role: Role, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
    }

    enum CodingKeys: String, CodingKey { case role, content }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.role = try container.decode(Role.self, forKey: .role)
        self.content = try container.decode(String.self, forKey: .content)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
    }
}

struct PendingAction: Decodable {
    let type: String
    let params: TaskActionParams

    struct TaskActionParams: Decodable {
        let text: String
        let domain: String
    }
}

struct ChatReply: Decodable {
    let reply: String
    let pendingAction: PendingAction?
}

struct ProfileResponse: Decodable {
    let profile: String
}

enum Domain: String, CaseIterable, Identifiable, Codable {
    case alpinetech, aurorasynapz, omnia, personal, general
    var id: String { rawValue }
    var label: String {
        switch self {
        case .alpinetech: return "AlpineTech"
        case .aurorasynapz: return "Aurora Synapz"
        case .omnia: return "Omnia OS"
        case .personal: return "Personal"
        case .general: return "General"
        }
    }
}

struct TaskItem: Codable, Identifiable, Equatable {
    let id: String
    let text: String
    let domain: String?
    var status: String
    let createdAt: String
}

struct TasksResponse: Decodable {
    let tasks: [TaskItem]
}

struct NoteItem: Codable, Identifiable, Equatable {
    let id: String
    let text: String
    let domain: String?
    let createdAt: String
}

struct NotesResponse: Decodable {
    let notes: [NoteItem]
}

struct KnowledgeFact: Codable, Identifiable, Equatable {
    let id: String
    let text: String
    let createdAt: String
}

struct KnowledgeResponse: Decodable {
    let facts: [KnowledgeFact]
}

struct ChatHistoryResponse: Decodable {
    let messages: [ChatMessage]
}

struct GoogleStatus: Decodable {
    let connected: Bool
    let email: String?
}
