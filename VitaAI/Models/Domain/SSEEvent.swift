import Foundation

enum SSEEvent {
    case textDelta(String)
    case messageStop(conversationId: String?)
    case error(String)
}
