import Foundation

struct ChatMessage: Identifiable, Codable {
    let id: String
    let role: String // "user" or "assistant"
    var content: String
    var timestamp: Date = Date()
    var feedback: Int = 0 // 0=none, 1=up, -1=down
}
