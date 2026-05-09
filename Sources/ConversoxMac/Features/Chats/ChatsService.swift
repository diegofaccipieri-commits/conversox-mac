import Foundation
import UniformTypeIdentifiers

struct ComposerAttachment: Identifiable, Sendable {
    let id: UUID
    let fileName: String
    let mimeType: String
    let data: Data

    init(id: UUID = UUID(), fileName: String, mimeType: String, data: Data) {
        self.id = id
        self.fileName = fileName
        self.mimeType = mimeType
        self.data = data
    }

    static func fromFileURL(_ fileURL: URL) throws -> ComposerAttachment {
        let data = try Data(contentsOf: fileURL)
        let fileName = fileURL.lastPathComponent
        let mimeType = Self.guessMimeType(from: fileURL)
        return ComposerAttachment(fileName: fileName, mimeType: mimeType, data: data)
    }

    private static func guessMimeType(from fileURL: URL) -> String {
        if let type = UTType(filenameExtension: fileURL.pathExtension),
           let mime = type.preferredMIMEType {
            return mime
        }
        return "application/octet-stream"
    }
}

struct SendMessageRequest: Encodable, Sendable {
    let jid: String
    let connectionID: String
    let instance: String?
    let text: String
    let quotedMessageID: String?
    let note: Bool

    enum CodingKeys: String, CodingKey {
        case jid
        case connectionID = "connection_id"
        case instance
        case text
        case quotedMessageID = "quoted_msg_id"
        case replyTo = "reply_to"
        case note
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jid, forKey: .jid)
        try container.encode(connectionID, forKey: .connectionID)
        try container.encodeIfPresent(instance, forKey: .instance)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(quotedMessageID, forKey: .quotedMessageID)
        try container.encodeIfPresent(quotedMessageID, forKey: .replyTo)
        if note {
            try container.encode(true, forKey: .note)
        }
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
    let serverSeq: Int?
    let changedChats: [ChatChange]
    let inlineMessages: [Message]
    let inlineReactions: [InlineReaction]

    enum CodingKeys: String, CodingKey {
        case ok
        case serverTS = "server_ts"
        case serverSeq = "server_seq"
        case changedChats = "changed_chats"
        case inlineMessages = "inline_messages"
        case inlineReactions = "inline_reactions"
    }
}

struct InlineReaction: Decodable, Sendable {
    let targetID: String
    let emoji: String
    let fromMe: Bool?

    enum CodingKeys: String, CodingKey {
        case targetID = "target_id"
        case emoji
        case fromMe = "from_me"
    }
}

struct ChatChange: Decodable, Sendable {
    let jid: String
    let connectionID: String
    let unread: Int?
    let lastMessageAt: String?
    let lastMessage: String?
    let lastFromMe: Bool?
    let lastMessageType: String?
    let sortTimestamp: Int?
    let isLowPriority: Bool?

    var chatID: String {
        "\(connectionID)|\(jid)"
    }

    enum CodingKeys: String, CodingKey {
        case jid
        case connectionID = "connection_id"
        case unread
        case lastMessageAt = "last_message_at"
        case lastMessage = "last_message"
        case lastFromMe = "last_from_me"
        case lastMessageType = "last_message_type"
        case sortTimestamp = "_sort_ts"
        case isLowPriority = "is_low_priority"
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

struct GenericActionRequest: Encodable, Sendable {
    let action: String
    let jid: String
    let connectionID: String
    let payload: [String: String]

    enum CodingKeys: String, CodingKey {
        case action
        case jid
        case connectionID = "connection_id"
        case payload
    }
}

struct GenericActionResponse: Decodable, Sendable {
    let ok: Bool
    let error: String?
}

struct FetchMediaRequest: Encodable, Sendable {
    let action: String = "fetch_media"
    let messageID: String
    let jid: String
    let connectionID: String
    let mimeType: String?

    enum CodingKeys: String, CodingKey {
        case action
        case messageID = "message_id"
        case jid
        case connectionID = "connection_id"
        case mimeType = "mime_type"
    }
}

struct FetchMediaResponse: Decodable, Sendable {
    let ok: Bool
    let mediaURL: String?
    let cachedURL: String?
    let mimeType: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case mediaURL = "media_url"
        case cachedURL = "cached_url"
        case mimeType = "mime_type"
        case error
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

    func fetchMessages(
        session: PersistedSession,
        chat: Chat,
        limit: Int = 50,
        beforeTS: Int? = nil,
        afterTS: Int? = nil,
        cacheSortTS: Int? = nil
    ) async throws -> MessageListResponse {
        var queryItems = [
            URLQueryItem(name: "jid", value: chat.jid),
            URLQueryItem(name: "connection_id", value: chat.connectionID),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        if let beforeTS {
            queryItems.append(URLQueryItem(name: "before_ts", value: String(beforeTS)))
        }
        if let afterTS {
            queryItems.append(URLQueryItem(name: "after_ts", value: String(afterTS)))
        }
        if let cacheSortTS {
            queryItems.append(URLQueryItem(name: "cache_sort_ts", value: String(cacheSortTS)))
        }

        let response: ConversoxHTTPResponse<MessageListResponse> = try await api.getJSON(.messages, queryItems: queryItems, session: session, timeout: 15)
        return MessageListResponse(
            ok: response.value.ok,
            messages: response.value.messages.map { $0.withChatID(chat.id) },
            nextCursor: response.value.nextCursor,
            hasOlder: response.value.hasOlder,
            oldestTS: response.value.oldestTS
        )
    }

    func sendMessage(
        session: PersistedSession,
        chat: Chat,
        text: String,
        quotedMessageID: String? = nil,
        note: Bool = false,
        attachment: ComposerAttachment? = nil
    ) async throws {
        let response: SendMessageResponse
        if let attachment {
            response = try await sendMultipartMessage(
                session: session,
                chat: chat,
                text: text,
                quotedMessageID: quotedMessageID,
                note: note,
                attachment: attachment
            )
        } else {
            let jsonResponse: ConversoxHTTPResponse<SendMessageResponse> = try await api.postJSON(
                .send,
                body: SendMessageRequest(
                    jid: chat.jid,
                    connectionID: chat.connectionID,
                    instance: chat.instance,
                    text: text,
                    quotedMessageID: quotedMessageID,
                    note: note
                ),
                session: session,
                timeout: 30
            )
            response = jsonResponse.value
        }

        if !response.ok {
            throw ConversoxError.backend(httpStatus: 502, backendError: response.error ?? "send_failed", rawBody: nil)
        }
    }

    func fetchMedia(session: PersistedSession, chat: Chat, messageID: String, mimeType: String?) async throws -> String {
        let response: ConversoxHTTPResponse<FetchMediaResponse> = try await api.postJSON(
            .actions,
            body: FetchMediaRequest(messageID: messageID, jid: chat.jid, connectionID: chat.connectionID, mimeType: mimeType),
            session: session,
            timeout: 30
        )

        guard response.value.ok else {
            throw ConversoxError.backend(httpStatus: response.statusCode, backendError: response.value.error ?? "media_download_failed", rawBody: nil)
        }

        if let mediaURL = response.value.mediaURL, !mediaURL.isEmpty {
            return mediaURL
        }
        if let cachedURL = response.value.cachedURL, !cachedURL.isEmpty {
            return cachedURL
        }
        throw ConversoxError.backend(httpStatus: 502, backendError: "media_download_failed", rawBody: nil)
    }

    func markRead(session: PersistedSession, chat: Chat) async throws {
        _ = try await api.postJSONNoContent(
            .actions,
            body: MarkReadRequest(jid: chat.jid, connectionID: chat.connectionID),
            session: session,
            timeout: 15
        )
    }

    func markUnread(session: PersistedSession, chat: Chat) async throws {
        try await performAction(session: session, chat: chat, action: "mark_unread")
    }

    func setLowPriority(session: PersistedSession, chat: Chat, isLowPriority: Bool) async throws {
        try await performAction(
            session: session,
            chat: chat,
            action: "set_low_priority",
            payload: ["is_low_priority": isLowPriority ? "1" : "0"]
        )
    }

    func transfer(session: PersistedSession, chat: Chat, target: String) async throws {
        try await performAction(
            session: session,
            chat: chat,
            action: "transfer_chat",
            payload: ["target": target]
        )
    }

    func groupInvite(session: PersistedSession, chat: Chat, members: String) async throws {
        try await performAction(
            session: session,
            chat: chat,
            action: "group_invite",
            payload: ["members": members]
        )
    }

    private func performAction(
        session: PersistedSession,
        chat: Chat,
        action: String,
        payload: [String: String] = [:]
    ) async throws {
        let req = GenericActionRequest(
            action: action,
            jid: chat.jid,
            connectionID: chat.connectionID,
            payload: payload
        )
        let response: ConversoxHTTPResponse<GenericActionResponse> = try await api.postJSON(
            .actions,
            body: req,
            session: session,
            timeout: 20
        )
        if !response.value.ok {
            throw ConversoxError.backend(httpStatus: response.statusCode, backendError: response.value.error ?? action, rawBody: nil)
        }
    }

    func poll(
        session: PersistedSession,
        sinceTS: Double,
        sinceSeq: Int?,
        newestTS: Int?,
        activeChat: Chat?
    ) async throws -> PollResponse {
        var queryItems = [
            URLQueryItem(name: "since_ts", value: String(max(Int(sinceTS), 1)))
        ]
        if let sinceSeq {
            queryItems.append(URLQueryItem(name: "since_seq", value: String(sinceSeq)))
        }
        if let newestTS {
            queryItems.append(URLQueryItem(name: "newest_ts", value: String(newestTS)))
        }
        if let activeChat {
            queryItems.append(URLQueryItem(name: "active_jid", value: activeChat.jid))
            queryItems.append(URLQueryItem(name: "active_connection_id", value: activeChat.connectionID))
        }
        let response: ConversoxHTTPResponse<PollResponse> = try await api.getJSON(.poll, queryItems: queryItems, session: session, timeout: 12)
        return response.value
    }

    private func sendMultipartMessage(
        session: PersistedSession,
        chat: Chat,
        text: String,
        quotedMessageID: String?,
        note: Bool,
        attachment: ComposerAttachment
    ) async throws -> SendMessageResponse {
        var fields: [String: String] = [
            "jid": chat.jid,
            "connection_id": chat.connectionID,
            "text": text
        ]
        if let instance = chat.instance {
            fields["instance"] = instance
        }
        if let quotedMessageID, !quotedMessageID.isEmpty {
            fields["quoted_msg_id"] = quotedMessageID
            fields["reply_to"] = quotedMessageID
        }
        if note {
            fields["note"] = "1"
        }

        let response: ConversoxHTTPResponse<SendMessageResponse> = try await api.postMultipart(
            .send,
            fields: fields,
            files: [MultipartFilePart(fieldName: "file", fileName: attachment.fileName, mimeType: attachment.mimeType, data: attachment.data)],
            session: session,
            timeout: 60
        )
        return response.value
    }
}
