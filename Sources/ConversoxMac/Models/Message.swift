import Foundation

struct Message: Codable, Identifiable, Sendable {
    struct Reaction: Codable, Hashable, Sendable {
        let emoji: String
        let jid: String?
        let name: String?
    }

    let id: String
    let keyID: String?
    let chatID: String
    let connectionID: String?
    let senderName: String
    let text: String
    let sentAt: Date
    let fromMe: Bool
    let type: String
    let status: String?
    let mediaURL: String?
    let mimeType: String?
    let fileName: String?
    let duration: Int?
    let quotedMessageID: String?
    let quotedText: String?
    let isDeleted: Bool
    let isForwarded: Bool
    let editedAt: String?
    let reactions: [Reaction]

    enum CodingKeys: String, CodingKey {
        case id
        case keyID = "key_id"
        case chatID = "chat_id"
        case connectionID = "connection_id"
        case senderName = "sender_name"
        case text
        case body
        case sentAt = "sent_at"
        case timestamp
        case fromMe = "from_me"
        case type
        case status
        case mediaURL = "media_url"
        case mediaURLFallback = "file_url"
        case mimeType = "mime_type"
        case fileName = "file_name"
        case duration
        case quotedMessageID = "quoted_msg_id"
        case quotedText = "quoted_text"
        case quoted
        case isDeleted = "is_deleted"
        case deletedAt = "deleted_at"
        case isForwarded = "forwarded"
        case editedAt = "edited_at"
        case reactions
    }

    enum QuotedCodingKeys: String, CodingKey {
        case id
        case keyID = "key_id"
        case text
        case body
    }

    init(
        id: String,
        keyID: String?,
        chatID: String,
        connectionID: String?,
        senderName: String,
        text: String,
        sentAt: Date,
        fromMe: Bool,
        type: String,
        status: String?,
        mediaURL: String?,
        mimeType: String?,
        fileName: String?,
        duration: Int?,
        quotedMessageID: String?,
        quotedText: String?,
        isDeleted: Bool,
        isForwarded: Bool,
        editedAt: String?,
        reactions: [Reaction]
    ) {
        self.id = id
        self.keyID = keyID
        self.chatID = chatID
        self.connectionID = connectionID
        self.senderName = senderName
        self.text = text
        self.sentAt = sentAt
        self.fromMe = fromMe
        self.type = type
        self.status = status
        self.mediaURL = mediaURL
        self.mimeType = mimeType
        self.fileName = fileName
        self.duration = duration
        self.quotedMessageID = quotedMessageID
        self.quotedText = quotedText
        self.isDeleted = isDeleted
        self.isForwarded = isForwarded
        self.editedAt = editedAt
        self.reactions = reactions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedID = try container.decodeIfPresent(String.self, forKey: .id)
        let decodedKeyID = try container.decodeIfPresent(String.self, forKey: .keyID)
        id = decodedID ?? decodedKeyID ?? UUID().uuidString
        keyID = decodedKeyID
        chatID = try container.decodeIfPresent(String.self, forKey: .chatID) ?? ""
        connectionID = try container.decodeIfPresent(String.self, forKey: .connectionID)
        fromMe = try container.decodeIfPresent(Bool.self, forKey: .fromMe) ?? false
        senderName = try container.decodeIfPresent(String.self, forKey: .senderName)
            ?? (fromMe ? "Voce" : "Cliente")
        text = try container.decodeIfPresent(String.self, forKey: .body)
            ?? container.decodeIfPresent(String.self, forKey: .text)
            ?? ""
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "text"
        status = try container.decodeIfPresent(String.self, forKey: .status)
        mediaURL = try container.decodeIfPresent(String.self, forKey: .mediaURL)
            ?? container.decodeIfPresent(String.self, forKey: .mediaURLFallback)
        mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
        duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        isForwarded = try container.decodeIfPresent(Bool.self, forKey: .isForwarded) ?? false

        let directQuotedID = try container.decodeIfPresent(String.self, forKey: .quotedMessageID)
        let directQuotedText = try container.decodeIfPresent(String.self, forKey: .quotedText)
        if let quotedContainer = try? container.nestedContainer(keyedBy: QuotedCodingKeys.self, forKey: .quoted) {
            let nestedID = try quotedContainer.decodeIfPresent(String.self, forKey: .id)
            let nestedKeyID = try quotedContainer.decodeIfPresent(String.self, forKey: .keyID)
            let nestedBody = try quotedContainer.decodeIfPresent(String.self, forKey: .body)
            let nestedText = try quotedContainer.decodeIfPresent(String.self, forKey: .text)
            quotedMessageID = directQuotedID ?? nestedID ?? nestedKeyID
            quotedText = directQuotedText ?? nestedBody ?? nestedText
        } else {
            quotedMessageID = directQuotedID
            quotedText = directQuotedText
        }

        if let timestamp = try container.decodeIfPresent(Double.self, forKey: .timestamp) {
            sentAt = Date(timeIntervalSince1970: timestamp)
        } else if let timestamp = try container.decodeIfPresent(Int.self, forKey: .timestamp) {
            sentAt = Date(timeIntervalSince1970: TimeInterval(timestamp))
        } else if let isoDate = try container.decodeIfPresent(String.self, forKey: .sentAt),
                  let date = DateParser.parse(isoDate) {
            sentAt = date
        } else {
            sentAt = .distantPast
        }

        let explicitDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        let deletedAt = try container.decodeIfPresent(String.self, forKey: .deletedAt)
        isDeleted = explicitDeleted || deletedAt != nil
        editedAt = try container.decodeIfPresent(String.self, forKey: .editedAt)
        reactions = try container.decodeIfPresent([Reaction].self, forKey: .reactions) ?? []
    }

    func withChatID(_ chatID: String) -> Message {
        Message(
            id: id,
            keyID: keyID,
            chatID: chatID,
            connectionID: connectionID,
            senderName: senderName,
            text: text,
            sentAt: sentAt,
            fromMe: fromMe,
            type: type,
            status: status,
            mediaURL: mediaURL,
            mimeType: mimeType,
            fileName: fileName,
            duration: duration,
            quotedMessageID: quotedMessageID,
            quotedText: quotedText,
            isDeleted: isDeleted,
            isForwarded: isForwarded,
            editedAt: editedAt,
            reactions: reactions
        )
    }

    func withMediaURL(_ mediaURL: String) -> Message {
        Message(
            id: id,
            keyID: keyID,
            chatID: chatID,
            connectionID: connectionID,
            senderName: senderName,
            text: text,
            sentAt: sentAt,
            fromMe: fromMe,
            type: type,
            status: status,
            mediaURL: mediaURL,
            mimeType: mimeType,
            fileName: fileName,
            duration: duration,
            quotedMessageID: quotedMessageID,
            quotedText: quotedText,
            isDeleted: isDeleted,
            isForwarded: isForwarded,
            editedAt: editedAt,
            reactions: reactions
        )
    }

    func withUpdatedText(_ text: String) -> Message {
        Message(
            id: id,
            keyID: keyID,
            chatID: chatID,
            connectionID: connectionID,
            senderName: senderName,
            text: text,
            sentAt: sentAt,
            fromMe: fromMe,
            type: type,
            status: status,
            mediaURL: mediaURL,
            mimeType: mimeType,
            fileName: fileName,
            duration: duration,
            quotedMessageID: quotedMessageID,
            quotedText: quotedText,
            isDeleted: isDeleted,
            isForwarded: isForwarded,
            editedAt: Date().ISO8601Format(),
            reactions: reactions
        )
    }

    func withDeletedState() -> Message {
        Message(
            id: id,
            keyID: keyID,
            chatID: chatID,
            connectionID: connectionID,
            senderName: senderName,
            text: text,
            sentAt: sentAt,
            fromMe: fromMe,
            type: type,
            status: status,
            mediaURL: mediaURL,
            mimeType: mimeType,
            fileName: fileName,
            duration: duration,
            quotedMessageID: quotedMessageID,
            quotedText: quotedText,
            isDeleted: true,
            isForwarded: isForwarded,
            editedAt: editedAt,
            reactions: reactions
        )
    }

    func withReaction(_ reaction: Reaction) -> Message {
        var next = reactions
        if let index = next.firstIndex(where: { $0.jid == reaction.jid && $0.emoji == reaction.emoji }) {
            next.remove(at: index)
        } else {
            next.append(reaction)
        }

        return Message(
            id: id,
            keyID: keyID,
            chatID: chatID,
            connectionID: connectionID,
            senderName: senderName,
            text: text,
            sentAt: sentAt,
            fromMe: fromMe,
            type: type,
            status: status,
            mediaURL: mediaURL,
            mimeType: mimeType,
            fileName: fileName,
            duration: duration,
            quotedMessageID: quotedMessageID,
            quotedText: quotedText,
            isDeleted: isDeleted,
            isForwarded: isForwarded,
            editedAt: editedAt,
            reactions: next
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(keyID, forKey: .keyID)
        try container.encode(chatID, forKey: .chatID)
        try container.encodeIfPresent(connectionID, forKey: .connectionID)
        try container.encode(senderName, forKey: .senderName)
        try container.encode(text, forKey: .text)
        try container.encode(sentAt, forKey: .sentAt)
        try container.encode(fromMe, forKey: .fromMe)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(mediaURL, forKey: .mediaURL)
        try container.encodeIfPresent(mimeType, forKey: .mimeType)
        try container.encodeIfPresent(fileName, forKey: .fileName)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encodeIfPresent(quotedMessageID, forKey: .quotedMessageID)
        try container.encodeIfPresent(quotedText, forKey: .quotedText)
        try container.encode(isDeleted, forKey: .isDeleted)
        try container.encode(isForwarded, forKey: .isForwarded)
        try container.encodeIfPresent(editedAt, forKey: .editedAt)
        try container.encode(reactions, forKey: .reactions)
    }
}

struct MessageListResponse: Codable, Sendable {
    let ok: Bool?
    let messages: [Message]
    let nextCursor: String?
    let hasOlder: Bool?
    let oldestTS: Int?

    enum CodingKeys: String, CodingKey {
        case ok
        case messages
        case nextCursor = "next_cursor"
        case hasOlder = "has_older"
        case oldestTS = "oldest_ts"
    }
}
