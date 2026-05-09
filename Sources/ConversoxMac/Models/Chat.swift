import Foundation

struct Chat: Codable, Identifiable, Sendable {
    var jid: String
    var connectionID: String
    var instance: String?
    var title: String
    var unreadCount: Int
    var lastMessagePreview: String?
    var updatedAt: Date
    var chatCode: String?
    var isGroup: Bool
    var badge: String?
    var nameSource: String?
    var lastMessageType: String?
    var lastMessageFileName: String?
    var lastFromMe: Bool
    var isLowPriority: Bool

    var id: String {
        "\(connectionID)|\(jid)"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case jid
        case connectionID = "connection_id"
        case instance
        case title
        case name
        case unreadCount = "unread_count"
        case unread
        case lastMessagePreview = "last_message_preview"
        case lastMessage = "last_message"
        case updatedAt = "updated_at"
        case lastMessageAt = "last_message_at"
        case sortTimestamp = "_sort_ts"
        case chatCode = "chat_code"
        case isGroup = "is_group"
        case badge
        case nameSource = "name_source"
        case lastMessageType = "last_message_type"
        case lastMessageFileName = "last_message_file_name"
        case lastFromMe = "last_from_me"
        case isLowPriority = "is_low_priority"
    }

    init(
        jid: String,
        connectionID: String,
        instance: String?,
        title: String,
        unreadCount: Int,
        lastMessagePreview: String?,
        updatedAt: Date,
        chatCode: String?,
        isGroup: Bool,
        badge: String?,
        nameSource: String?,
        lastMessageType: String?,
        lastMessageFileName: String?,
        lastFromMe: Bool,
        isLowPriority: Bool
    ) {
        self.jid = jid
        self.connectionID = connectionID
        self.instance = instance
        self.title = title
        self.unreadCount = unreadCount
        self.lastMessagePreview = lastMessagePreview
        self.updatedAt = updatedAt
        self.chatCode = chatCode
        self.isGroup = isGroup
        self.badge = badge
        self.nameSource = nameSource
        self.lastMessageType = lastMessageType
        self.lastMessageFileName = lastMessageFileName
        self.lastFromMe = lastFromMe
        self.isLowPriority = isLowPriority
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallbackID = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        jid = try container.decodeIfPresent(String.self, forKey: .jid) ?? fallbackID
        connectionID = try container.decodeIfPresent(String.self, forKey: .connectionID) ?? "evolution:main"
        instance = try container.decodeIfPresent(String.self, forKey: .instance)
        title = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? jid
        unreadCount = try container.decodeIfPresent(Int.self, forKey: .unread)
            ?? container.decodeIfPresent(Int.self, forKey: .unreadCount)
            ?? 0
        lastMessagePreview = try container.decodeIfPresent(String.self, forKey: .lastMessage)
            ?? container.decodeIfPresent(String.self, forKey: .lastMessagePreview)
        chatCode = try container.decodeIfPresent(String.self, forKey: .chatCode)
        isGroup = try container.decodeIfPresent(Bool.self, forKey: .isGroup) ?? jid.contains("@g.us")
        badge = try container.decodeIfPresent(String.self, forKey: .badge)
        nameSource = try container.decodeIfPresent(String.self, forKey: .nameSource)
        lastMessageType = try container.decodeIfPresent(String.self, forKey: .lastMessageType)
        lastMessageFileName = try container.decodeIfPresent(String.self, forKey: .lastMessageFileName)
        lastFromMe = try container.decodeIfPresent(Bool.self, forKey: .lastFromMe) ?? false
        isLowPriority = try container.decodeIfPresent(Bool.self, forKey: .isLowPriority) ?? false

        if let isoDate = try container.decodeIfPresent(String.self, forKey: .lastMessageAt)
            ?? container.decodeIfPresent(String.self, forKey: .updatedAt),
           let date = DateParser.parse(isoDate) {
            updatedAt = date
        } else if let sortTimestamp = try container.decodeIfPresent(Int.self, forKey: .sortTimestamp) {
            updatedAt = Date(timeIntervalSince1970: TimeInterval(sortTimestamp))
        } else {
            updatedAt = .distantPast
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jid, forKey: .jid)
        try container.encode(connectionID, forKey: .connectionID)
        try container.encodeIfPresent(instance, forKey: .instance)
        try container.encode(title, forKey: .name)
        try container.encode(unreadCount, forKey: .unread)
        try container.encodeIfPresent(lastMessagePreview, forKey: .lastMessage)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(chatCode, forKey: .chatCode)
        try container.encode(isGroup, forKey: .isGroup)
        try container.encodeIfPresent(badge, forKey: .badge)
        try container.encodeIfPresent(nameSource, forKey: .nameSource)
        try container.encodeIfPresent(lastMessageType, forKey: .lastMessageType)
        try container.encodeIfPresent(lastMessageFileName, forKey: .lastMessageFileName)
        try container.encode(lastFromMe, forKey: .lastFromMe)
        try container.encode(isLowPriority, forKey: .isLowPriority)
    }
}

struct ChatListResponse: Codable, Sendable {
    let ok: Bool?
    let items: [Chat]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case items = "chats"
        case nextCursor = "next_cursor"
    }
}
