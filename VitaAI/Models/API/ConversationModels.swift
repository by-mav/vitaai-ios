import Foundation

// MIGRATION: Partial migration to OpenAPI generated types.
// PushTokenRequest → RegisterPushTokenRequest (generated, compatible)
// ConversationEntry — generated Conversation lacks messagePreview, kept manual
// ConversationMessage — generated uses timestamp:Date instead of createdAt:String, kept manual
// FeedbackRequest — generated SubmitCoachFeedbackRequest has different shape, kept manual
// ChatRequest — generated VitaChatRequest lacks conversationId/voiceMode, kept manual
// PushPreferencesRequest — no generated equivalent, kept manual

typealias PushTokenRequest = RegisterPushTokenRequest

struct ConversationEntry: Codable, Identifiable {
    var id: String = ""
    var title: String?
    var updatedAt: String?
    var messagePreview: String?
}

struct ConversationMessagesResponse: Codable {
    var messages: [ConversationMessage] = []
}

struct ConversationMessage: Codable, Identifiable {
    var id: String = ""
    var role: String = ""
    var content: String = ""
    var createdAt: String?
}

struct FeedbackRequest: Codable {
    var feedback: Int = 0
}

struct PushPreferencesRequest: Codable {
    var flashcardReminders: Bool
    var streakAlerts: Bool
    var studyReminders: Bool
    var reminderTime: String
}

struct ChatRequest: Codable {
    var message: String
    var conversationId: String?
    var voiceMode: Bool?
}
