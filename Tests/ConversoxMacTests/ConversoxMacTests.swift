import Foundation
import Testing
@testable import ConversoxMac

struct ConversoxMacTests {
    @Test func chatDecodingShouldMapConversoxServerFields() throws {
        let json = """
        {
          "jid": "5511999999999@s.whatsapp.net",
          "connection_id": "evolution:main",
          "instance": "main",
          "name": "Cliente X",
          "unread": 3,
          "last_message": "Oi",
          "last_message_at": "2026-05-07T20:00:00Z",
          "chat_code": "abc123def456"
        }
        """.data(using: .utf8)!

        let chat = try JSONDecoder().decode(Chat.self, from: json)

        #expect(chat.id == "evolution:main|5511999999999@s.whatsapp.net")
        #expect(chat.title == "Cliente X")
        #expect(chat.unreadCount == 3)
        #expect(chat.chatCode == "abc123def456")
    }

    @Test func messageDecodingShouldMapConversoxServerFields() throws {
        let json = """
        {
          "id": "msg-1",
          "type": "text",
          "body": "Ola",
          "from_me": false,
          "timestamp": 1746600100,
          "status": "read",
          "sender_name": "Cliente X",
          "connection_id": "evolution:main"
        }
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(Message.self, from: json)

        #expect(message.id == "msg-1")
        #expect(message.text == "Ola")
        #expect(message.senderName == "Cliente X")
        #expect(message.fromMe == false)
    }
}
