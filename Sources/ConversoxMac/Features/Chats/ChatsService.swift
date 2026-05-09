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

struct DynamicActionRequest: Encodable, Sendable {
    let action: String
    let jid: String
    let connectionID: String
    let dynamic: [String: String]

    enum CodingKeys: String, CodingKey {
        case action
        case jid
        case connectionID = "connection_id"
    }

    struct DynamicCodingKey: CodingKey {
        let stringValue: String
        let intValue: Int? = nil

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            return nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var fixed = encoder.container(keyedBy: CodingKeys.self)
        try fixed.encode(action, forKey: .action)
        try fixed.encode(jid, forKey: .jid)
        try fixed.encode(connectionID, forKey: .connectionID)

        var extra = encoder.container(keyedBy: DynamicCodingKey.self)
        for (key, value) in dynamic {
            guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
            try extra.encode(value, forKey: codingKey)
        }
    }
}

struct GenericActionResponse: Decodable, Sendable {
    let ok: Bool
    let error: String?
}

struct FetchGroupInviteResponse: Decodable, Sendable {
    let ok: Bool
    let inviteURL: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case inviteURL = "invite_url"
        case error
    }
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

struct ChatNote: Decodable, Identifiable, Sendable {
    let id: String
    let text: String
    let author: String?
    let authorEmail: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case author
        case authorEmail = "author_email"
        case createdAt = "created_at"
    }
}

private struct NotesListResponse: Decodable, Sendable {
    let ok: Bool?
    let notes: [ChatNote]
}

private struct NoteCreateResponse: Decodable, Sendable {
    let ok: Bool
    let note: ChatNote?
    let error: String?
}

private struct NoteCreateRequest: Encodable, Sendable {
    let jid: String
    let connectionID: String
    let text: String

    enum CodingKeys: String, CodingKey {
        case jid
        case connectionID = "connection_id"
        case text
    }
}

private struct NoteDeleteRequest: Encodable, Sendable {
    let id: String
    let methodOverride: String = "DELETE"

    enum CodingKeys: String, CodingKey {
        case id
        case methodOverride = "_method"
    }
}

private struct StickerPackSummary: Decodable, Sendable {
    let id: String
    let name: String?
}

private struct StickerPacksResponse: Decodable, Sendable {
    let ok: Bool?
    let packs: [StickerPackSummary]
}

private struct StickerAsset: Decodable, Sendable, Identifiable {
    let id: String
    let packID: String?
    let url: String?

    enum CodingKeys: String, CodingKey {
        case id
        case packID = "pack_id"
        case url
    }
}

private struct StickersResponse: Decodable, Sendable {
    let ok: Bool?
    let stickers: [StickerAsset]
}

private struct SimpleOKResponse: Decodable, Sendable {
    let ok: Bool
    let error: String?
}

private struct ContactsDirectoryResponse: Decodable, Sendable {
    let ok: Bool?
    let contacts: [ContactsDirectoryItem]
}

private struct ContactsDirectoryItem: Decodable, Sendable {
    let jid: String
    let connectionID: String?
    let name: String?
    let isGroup: Bool?
    let lastMessageAt: String?

    enum CodingKeys: String, CodingKey {
        case jid
        case connectionID = "connection_id"
        case name
        case isGroup = "is_group"
        case lastMessageAt = "last_message_at"
    }
}

private struct QuickRepliesResponse: Decodable, Sendable {
    let ok: Bool?
    let quickReplies: [QuickReplyItem]

    enum CodingKeys: String, CodingKey {
        case ok
        case quickReplies = "quick_replies"
    }
}

private struct QuickReplyItem: Decodable, Sendable {
    let id: String?
    let body: String?
    let title: String?
    let shortcut: String?
}

struct QuickReplyEntry: Sendable {
    let id: String?
    let body: String
    let shortcut: String?
}

private struct QuickReplyMutationResponse: Decodable, Sendable {
    let ok: Bool
    let quickReply: QuickReplyItem?
    let deleted: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case quickReply = "quick_reply"
        case deleted
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

    func fetchContactsDirectory(session: PersistedSession, search: String) async throws -> [ContactDirectoryEntry] {
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let query: [URLQueryItem] = [
            URLQueryItem(name: "q", value: trimmed.isEmpty ? nil : trimmed),
            URLQueryItem(name: "limit", value: "200")
        ]

        var response = try await getContactsDirectory(
            session: session,
            route: .customPrefixed("/contacts_directory.php"),
            query: query
        )
        if response == nil {
            response = try await getContactsDirectory(
                session: session,
                route: .absolutePath("/api/conversox3/contacts_directory.php"),
                query: query
            )
        }

        guard let response else { return [] }

        return response.contacts.map { item in
            let connectionID = item.connectionID ?? "evolution:main"
            let title = item.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedName = (title?.isEmpty == false) ? title! : item.jid
            let date = item.lastMessageAt.flatMap(DateParser.parse) ?? .distantPast

            return ContactDirectoryEntry(
                id: "\(connectionID)|\(item.jid)",
                title: resolvedName,
                jid: item.jid,
                connectionID: connectionID,
                isGroup: item.isGroup ?? item.jid.contains("@g.us"),
                updatedAt: date
            )
        }
    }

    func fetchQuickReplyEntries(session: PersistedSession) async throws -> [QuickReplyEntry] {
        var response = try await getQuickReplies(
            session: session,
            route: .customPrefixed("/quick_replies.php")
        )
        if response == nil {
            response = try await getQuickReplies(
                session: session,
                route: .absolutePath("/api/conversox3/quick_replies.php")
            )
        }

        guard let response else { return [] }

        let values = response.quickReplies.compactMap { item -> QuickReplyEntry? in
            let body = item.body?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let body, !body.isEmpty {
                return QuickReplyEntry(id: item.id, body: body, shortcut: item.shortcut)
            }
            let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let title, !title.isEmpty {
                return QuickReplyEntry(id: item.id, body: title, shortcut: item.shortcut)
            }
            if let shortcut = item.shortcut, !shortcut.isEmpty {
                return QuickReplyEntry(id: item.id, body: shortcut, shortcut: item.shortcut)
            }
            return nil
        }

        var seen: Set<String> = []
        var output: [QuickReplyEntry] = []
        for entry in values {
            if seen.insert(entry.body).inserted {
                output.append(entry)
            }
        }
        return output.sorted { $0.body.localizedCaseInsensitiveCompare($1.body) == .orderedAscending }
    }

    func fetchQuickReplies(session: PersistedSession) async throws -> [String] {
        try await fetchQuickReplyEntries(session: session).map(\.body)
    }

    func createQuickReply(session: PersistedSession, shortcut: String, body: String) async throws -> QuickReplyEntry? {
        let payload = [
            "action": "create",
            "shortcut": shortcut,
            "body": body,
            "title": body
        ]
        let response = try await mutateQuickReply(session: session, payload: payload)
        guard response.ok else {
            throw ConversoxError.backend(httpStatus: 400, backendError: response.error ?? "quick_reply_create_failed", rawBody: nil)
        }
        if let qr = response.quickReply {
            let resolvedBody = qr.body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? body
            return QuickReplyEntry(id: qr.id, body: resolvedBody, shortcut: qr.shortcut ?? shortcut)
        }
        return nil
    }

    func deleteQuickReply(session: PersistedSession, id: String) async throws {
        let payload = [
            "action": "delete",
            "id": id
        ]
        let response = try await mutateQuickReply(session: session, payload: payload)
        guard response.ok else {
            throw ConversoxError.backend(httpStatus: 400, backendError: response.error ?? "quick_reply_delete_failed", rawBody: nil)
        }
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

    func editMessage(session: PersistedSession, chat: Chat, messageID: String, text: String) async throws {
        try await performAction(
            session: session,
            chat: chat,
            action: "edit",
            payload: [
                "message_id": messageID,
                "text": text
            ]
        )
    }

    func deleteMessage(session: PersistedSession, chat: Chat, messageID: String, deleteScope: String) async throws {
        try await performAction(
            session: session,
            chat: chat,
            action: "delete",
            payload: [
                "message_id": messageID,
                "delete_scope": deleteScope
            ]
        )
    }

    func reactToMessage(session: PersistedSession, chat: Chat, messageID: String, emoji: String) async throws {
        try await performAction(
            session: session,
            chat: chat,
            action: "react",
            payload: [
                "message_id": messageID,
                "emoji": emoji
            ]
        )
    }

    func forwardMessage(
        session: PersistedSession,
        sourceMessage: Message,
        targetChat: Chat
    ) async throws {
        let text = sourceMessage.text.isEmpty ? "[\(sourceMessage.type)]" : sourceMessage.text
        let forwarded = "⤳ Encaminhado\n\(text)"
        try await sendMessage(session: session, chat: targetChat, text: forwarded, quotedMessageID: nil, note: false)
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

    func fetchNotes(session: PersistedSession, chat: Chat) async throws -> [ChatNote] {
        let query = [
            URLQueryItem(name: "jid", value: chat.jid),
            URLQueryItem(name: "connection_id", value: chat.connectionID)
        ]
        let response: ConversoxHTTPResponse<NotesListResponse> = try await api.getJSON(
            .customPrefixed("/notes.php"),
            queryItems: query,
            session: session,
            timeout: 20
        )
        return response.value.notes
    }

    func createNote(session: PersistedSession, chat: Chat, text: String) async throws -> ChatNote? {
        let response: ConversoxHTTPResponse<NoteCreateResponse> = try await api.postJSON(
            .customPrefixed("/notes.php"),
            body: NoteCreateRequest(jid: chat.jid, connectionID: chat.connectionID, text: text),
            session: session,
            timeout: 20
        )
        guard response.value.ok else {
            throw ConversoxError.backend(httpStatus: response.statusCode, backendError: response.value.error ?? "note_create_failed", rawBody: nil)
        }
        return response.value.note
    }

    func deleteNote(session: PersistedSession, noteID: String) async throws {
        let response: ConversoxHTTPResponse<SimpleOKResponse> = try await api.postJSON(
            .customPrefixed("/notes.php"),
            body: NoteDeleteRequest(id: noteID),
            session: session,
            timeout: 20
        )
        guard response.value.ok else {
            throw ConversoxError.backend(httpStatus: response.statusCode, backendError: response.value.error ?? "note_delete_failed", rawBody: nil)
        }
    }

    func fetchStickerPackIDs(session: PersistedSession) async throws -> [String] {
        let response: ConversoxHTTPResponse<StickerPacksResponse> = try await api.getJSON(
            .customPrefixed("/stickers.php"),
            queryItems: [URLQueryItem(name: "action", value: "packs")],
            session: session,
            timeout: 20
        )
        return response.value.packs.map(\.id)
    }

    func fetchStickers(session: PersistedSession, packID: String) async throws -> [String] {
        let response: ConversoxHTTPResponse<StickersResponse> = try await api.getJSON(
            .customPrefixed("/stickers.php"),
            queryItems: [
                URLQueryItem(name: "action", value: "stickers"),
                URLQueryItem(name: "pack_id", value: packID)
            ],
            session: session,
            timeout: 20
        )
        return response.value.stickers.map(\.id)
    }

    func sendSticker(session: PersistedSession, chat: Chat, stickerID: String) async throws {
        let response: ConversoxHTTPResponse<SimpleOKResponse> = try await api.postJSON(
            .customPrefixed("/stickers.php"),
            body: [
                "action": "send",
                "jid": chat.jid,
                "connection_id": chat.connectionID,
                "sticker_id": stickerID
            ],
            session: session,
            timeout: 20
        )
        guard response.value.ok else {
            throw ConversoxError.backend(httpStatus: response.statusCode, backendError: response.value.error ?? "send_sticker_failed", rawBody: nil)
        }
    }

    func saveStickerFromMedia(session: PersistedSession, mediaURL: String) async throws {
        let response: ConversoxHTTPResponse<SimpleOKResponse> = try await api.postJSON(
            .customPrefixed("/stickers.php"),
            body: [
                "action": "save",
                "media_url": mediaURL
            ],
            session: session,
            timeout: 30
        )
        guard response.value.ok else {
            throw ConversoxError.backend(httpStatus: response.statusCode, backendError: response.value.error ?? "save_sticker_failed", rawBody: nil)
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
            payload: ["set": isLowPriority ? "1" : "0"]
        )
    }

    func transfer(session: PersistedSession, chat: Chat, target: String) async throws {
        try await performAction(
            session: session,
            chat: chat,
            action: "transfer_conversation",
            payload: [
                "target_user_id": target,
                "target_email": target
            ]
        )
    }

    func fetchGroupInvite(session: PersistedSession, chat: Chat) async throws -> String? {
        let req = DynamicActionRequest(
            action: "fetch_group_invite",
            jid: chat.jid,
            connectionID: chat.connectionID,
            dynamic: ["group_jid": chat.jid]
        )

        let response: ConversoxHTTPResponse<FetchGroupInviteResponse> = try await api.postJSON(
            .actions,
            body: req,
            session: session,
            timeout: 20
        )

        guard response.value.ok else {
            throw ConversoxError.backend(httpStatus: response.statusCode, backendError: response.value.error ?? "group_invite_fetch_failed", rawBody: nil)
        }

        return response.value.inviteURL
    }

    private func performAction(
        session: PersistedSession,
        chat: Chat,
        action: String,
        payload: [String: String] = [:]
    ) async throws {
        let req = DynamicActionRequest(
            action: action,
            jid: chat.jid,
            connectionID: chat.connectionID,
            dynamic: payload
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

    private func getContactsDirectory(
        session: PersistedSession,
        route: ConversoxAPI.Route,
        query: [URLQueryItem]
    ) async throws -> ContactsDirectoryResponse? {
        do {
            let response: ConversoxHTTPResponse<ContactsDirectoryResponse> = try await api.getJSON(route, queryItems: query, session: session, timeout: 20)
            return response.value
        } catch let error as ConversoxError where error.httpStatus == 404 {
            return nil
        }
    }

    private func getQuickReplies(session: PersistedSession, route: ConversoxAPI.Route) async throws -> QuickRepliesResponse? {
        do {
            let response: ConversoxHTTPResponse<QuickRepliesResponse> = try await api.getJSON(route, session: session, timeout: 20)
            return response.value
        } catch let error as ConversoxError where error.httpStatus == 404 {
            return nil
        }
    }

    private func mutateQuickReply(session: PersistedSession, payload: [String: String]) async throws -> QuickReplyMutationResponse {
        do {
            let response: ConversoxHTTPResponse<QuickReplyMutationResponse> = try await api.postJSON(
                .customPrefixed("/quick_replies.php"),
                body: payload,
                session: session,
                timeout: 20
            )
            return response.value
        } catch let error as ConversoxError where error.httpStatus == 404 {
            let response: ConversoxHTTPResponse<QuickReplyMutationResponse> = try await api.postJSON(
                .absolutePath("/api/conversox3/quick_replies.php"),
                body: payload,
                session: session,
                timeout: 20
            )
            return response.value
        }
    }
}
