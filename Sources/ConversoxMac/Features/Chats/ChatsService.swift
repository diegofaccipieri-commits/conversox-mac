import Foundation

struct SendMessageRequest: Encodable {
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

struct SendMessageResponse: Decodable {
    let ok: Bool
    let messageID: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case messageID = "message_id"
        case error
    }
}

struct PollResponse: Decodable {
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

struct ChatChange: Decodable {
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

struct MarkReadRequest: Encodable {
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
    private let httpClient = HTTPClient()

    func fetchChats(session: PersistedSession) async throws -> ChatListResponse {
        let path = pathWithQuery("/Conversox/api/chats.php", [
            URLQueryItem(name: "_t", value: String(Int(Date().timeIntervalSince1970)))
        ])
        return try await httpClient.request(path, session: session)
    }

    func fetchMessages(session: PersistedSession, chat: Chat, limit: Int = 50) async throws -> MessageListResponse {
        let path = pathWithQuery("/Conversox/api/messages.php", [
            URLQueryItem(name: "jid", value: chat.jid),
            URLQueryItem(name: "connection_id", value: chat.connectionID),
            URLQueryItem(name: "limit", value: String(limit))
        ])
        let response: MessageListResponse = try await httpClient.request(path, session: session)
        return MessageListResponse(
            ok: response.ok,
            messages: response.messages.map { $0.withChatID(chat.id) },
            nextCursor: response.nextCursor
        )
    }

    func sendMessage(session: PersistedSession, chat: Chat, text: String) async throws {
        let response: SendMessageResponse = try await httpClient.request(
            "/Conversox/api/send.php",
            method: "POST",
            session: session,
            body: SendMessageRequest(jid: chat.jid, connectionID: chat.connectionID, instance: chat.instance, text: text)
        )
        if !response.ok {
            throw APIError.httpStatus(200, body: response.error)
        }
    }

    func markRead(session: PersistedSession, chat: Chat) async throws {
        try await httpClient.requestNoContent(
            "/Conversox/api/actions.php",
            method: "POST",
            session: session,
            body: MarkReadRequest(jid: chat.jid, connectionID: chat.connectionID)
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
        return try await httpClient.request(pathWithQuery("/Conversox/api/poll.php", queryItems), session: session)
    }

    private func pathWithQuery(_ path: String, _ queryItems: [URLQueryItem]) -> String {
        var components = URLComponents()
        components.path = path
        components.queryItems = queryItems
        return components.string ?? path
    }
}
