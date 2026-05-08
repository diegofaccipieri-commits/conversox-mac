import Foundation

struct Message: Codable, Identifiable, Sendable {
    let id: String
    let chatID: String
    let senderName: String
    let text: String
    let sentAt: Date
    let fromMe: Bool
    let type: String
    let status: String?

    enum CodingKeys: String, CodingKey {
        case id
        case keyID = "key_id"
        case chatID = "chat_id"
        case senderName = "sender_name"
        case text
        case body
        case sentAt = "sent_at"
        case timestamp
        case fromMe = "from_me"
        case type
        case status
    }

    init(id: String, chatID: String, senderName: String, text: String, sentAt: Date, fromMe: Bool, type: String, status: String?) {
        self.id = id
        self.chatID = chatID
        self.senderName = senderName
        self.text = text
        self.sentAt = sentAt
        self.fromMe = fromMe
        self.type = type
        self.status = status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .keyID)
            ?? UUID().uuidString
        chatID = try container.decodeIfPresent(String.self, forKey: .chatID) ?? ""
        fromMe = try container.decodeIfPresent(Bool.self, forKey: .fromMe) ?? false
        senderName = try container.decodeIfPresent(String.self, forKey: .senderName)
            ?? (fromMe ? "Voce" : "Cliente")
        text = try container.decodeIfPresent(String.self, forKey: .body)
            ?? container.decodeIfPresent(String.self, forKey: .text)
            ?? ""
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "text"
        status = try container.decodeIfPresent(String.self, forKey: .status)

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
    }

    func withChatID(_ chatID: String) -> Message {
        Message(id: id, chatID: chatID, senderName: senderName, text: text, sentAt: sentAt, fromMe: fromMe, type: type, status: status)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(chatID, forKey: .chatID)
        try container.encode(senderName, forKey: .senderName)
        try container.encode(text, forKey: .text)
        try container.encode(sentAt, forKey: .sentAt)
        try container.encode(fromMe, forKey: .fromMe)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(status, forKey: .status)
    }
}

struct MessageListResponse: Codable, Sendable {
    let ok: Bool?
    let messages: [Message]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case messages
        case nextCursor = "next_cursor"
    }
}
