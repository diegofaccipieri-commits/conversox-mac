import Foundation

struct SendMessageRequest: Encodable, Sendable {
    let jid: String
    let connectionID: String
    let instance: String?
    let text: String

    enum CodingKeys: String, CodingKey {
        case jid
        case connectionID = "connection_id"
        case instance
        case text
    }
}

struct SendMessageResponse: Decodable, Sendable {
    let ok: Bool
    let messageID: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case messageID = "message_id"
        case error
    }
}

struct PollResponse: Decodable, Sendable {
    let ok: Bool
    let serverTS: Double?
    let changedChats: [ChatChange]
    let inlineMessages: [Message]

    enum CodingKeys: String, CodingKey {
        case ok
        case serverTS = "server_ts"
        case changedChats = "changed_chats"
        case inlineMessages = "inline_messages"
    }
}

struct ChatChange: Decodable, Sendable {
    let jid: String
    let connectionID: String
    let unread: Int?
    let lastMessageAt: String?

    var chatID: String {
        "\(connectionID)|\(jid)"
    }

    enum CodingKeys: String, CodingKey {
        case jid
        case connectionID = "connection_id"
        case unread
        case lastMessageAt = "last_message_at"
    }
}

struct MarkReadRequest: Encodable, Sendable {
    let action = "mark_read"
    let jid: String
    let connectionID: String

    enum CodingKeys: String, CodingKey {
        case action
        case jid
        case connectionID = "connection_id"
    }
}

struct ChatsService {
    private let api = ConversoxAPI()

    func fetchChats(session: PersistedSession) async throws -> ChatListResponse {
        let response: ConversoxHTTPResponse<ChatListResponse> = try await api.getJSON(.chats, queryItems: [
            URLQueryItem(name: "_t", value: String(Int(Date().timeIntervalSince1970)))
        ], session: session, timeout: 8)
        return response.value
    }

    func fetchMessages(session: PersistedSession, chat: Chat, limit: Int = 50) async throws -> MessageListResponse {
        let response: ConversoxHTTPResponse<MessageListResponse> = try await api.getJSON(.messages, queryItems: [
            URLQueryItem(name: "jid", value: chat.jid),
            URLQueryItem(name: "connection_id", value: chat.connectionID),
            URLQueryItem(name: "limit", value: String(limit))
        ], session: session, timeout: 15)
        return MessageListResponse(
            ok: response.value.ok,
            messages: response.value.messages.map { $0.withChatID(chat.id) },
            nextCursor: response.value.nextCursor
        )
    }

    func sendMessage(session: PersistedSession, chat: Chat, text: String) async throws {
        let response: ConversoxHTTPResponse<SendMessageResponse> = try await api.postJSON(
            .send,
            body: SendMessageRequest(jid: chat.jid, connectionID: chat.connectionID, instance: chat.instance, text: text),
            session: session,
            timeout: 30
        )
        if !response.value.ok {
            throw ConversoxError.backend(httpStatus: 502, backendError: response.value.error ?? "send_failed", rawBody: nil)
        }
    }

    func markRead(session: PersistedSession, chat: Chat) async throws {
        _ = try await api.postJSONNoContent(
            .actions,
            body: MarkReadRequest(jid: chat.jid, connectionID: chat.connectionID),
            session: session,
            timeout: 15
        )
    }

    func poll(session: PersistedSession, sinceTS: Double, activeChat: Chat?) async throws -> PollResponse {
        var queryItems = [
            URLQueryItem(name: "since_ts", value: String(sinceTS))
        ]
        if let activeChat {
            queryItems.append(URLQueryItem(name: "active_jid", value: activeChat.jid))
            queryItems.append(URLQueryItem(name: "active_connection_id", value: activeChat.connectionID))
        }
        let response: ConversoxHTTPResponse<PollResponse> = try await api.getJSON(.poll, queryItems: queryItems, session: session, timeout: 12)
        return response.value
    }
}
