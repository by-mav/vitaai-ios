import Foundation
import Observation

// MARK: - ChatViewModel
// Uses ChatMessage from Models/Domain/ChatMessage.swift:
//   struct ChatMessage: Identifiable, Codable {
//     let id: String
//     let role: String      // "user" or "assistant"
//     var content: String
//     var timestamp: Date
//     var feedback: Int
//   }
//
// Uses ConversationEntry, ConversationMessagesResponse, ConversationMessage
//   from Models/API/ConversationModels.swift

@MainActor
@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isStreaming: Bool = false
    var currentConversationId: String?
    var conversations: [ConversationEntry] = []
    var showHistory: Bool = false

    private let chatClient: VitaChatClient
    private let api: VitaAPI

    init(chatClient: VitaChatClient, api: VitaAPI) {
        self.chatClient = chatClient
        self.api = api
    }

    // MARK: - Send

    func send() async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !isStreaming else { return }

        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""

        let userMsg = ChatMessage(
            id: UUID().uuidString,
            role: "user",
            content: text,
            timestamp: Date()
        )
        messages.append(userMsg)

        var assistantMsg = ChatMessage(
            id: UUID().uuidString,
            role: "assistant",
            content: "",
            timestamp: Date()
        )
        messages.append(assistantMsg)
        let idx = messages.count - 1

        isStreaming = true

        do {
            for try await event in await chatClient.streamChat(
                message: text,
                conversationId: currentConversationId
            ) {
                switch event {
                case .textDelta(let chunk):
                    // If a progress indicator was showing, replace it; otherwise append
                    if messages[idx].content.hasPrefix("⏳") {
                        messages[idx].content = chunk
                    } else {
                        messages[idx].content += chunk
                    }

                case .toolProgress(let text):
                    messages[idx].content = "⏳ \(text)"

                case .messageStop(let convId):
                    if let convId {
                        currentConversationId = convId
                    }

                case .error:
                    messages[idx].content = "Erro ao gerar resposta."
                    messages[idx].isError = true
                }
            }
        } catch {
            messages[idx].content = "Erro de conexao."
            messages[idx].isError = true
        }

        isStreaming = false
    }

    // MARK: - Retry

    func retryLastMessage() async {
        // Find the last user message
        guard let lastUserIndex = messages.lastIndex(where: { $0.role == "user" }) else { return }
        let userText = messages[lastUserIndex].content

        // Remove the error assistant message (should be right after the user message)
        let assistantIndex = lastUserIndex + 1
        if assistantIndex < messages.count,
           messages[assistantIndex].role == "assistant",
           messages[assistantIndex].isError {
            messages.remove(at: assistantIndex)
        }

        // Also remove the user message — send() will re-append both
        messages.remove(at: lastUserIndex)

        // Re-send
        inputText = userText
        await send()
    }

    // MARK: - Send from suggestion chip

    func sendSuggestion(_ text: String) async {
        inputText = text
        await send()
    }

    // MARK: - History

    func loadHistory() async {
        do {
            conversations = try await api.getConversations()
        } catch {
            // Silent fallback — history is non-critical
            print("[ChatViewModel] loadHistory error: \(error)")
        }
    }

    func loadConversation(_ conv: ConversationEntry) async {
        currentConversationId = conv.id
        showHistory = false

        do {
            let resp = try await api.getConversationMessages(conversationId: conv.id)
            let formatter = ISO8601DateFormatter()
            messages = resp.messages.map { m in
                ChatMessage(
                    id: m.id.isEmpty ? UUID().uuidString : m.id,
                    role: m.role,
                    content: m.content,
                    timestamp: formatter.date(from: m.createdAt ?? "") ?? Date()
                )
            }
        } catch {
            print("[ChatViewModel] loadConversation error: \(error)")
        }
    }

    func newConversation() {
        currentConversationId = nil
        messages = []
        showHistory = false
    }
}
