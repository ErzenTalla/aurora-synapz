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
}

struct ChatReply: Decodable {
    let reply: String
}

struct ProfileResponse: Decodable {
    let profile: String
}
