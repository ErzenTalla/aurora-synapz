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

struct BriefingResponse: Decodable {
    let date: String
    let briefing: String
}
