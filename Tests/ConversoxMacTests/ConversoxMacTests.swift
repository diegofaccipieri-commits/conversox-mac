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

    @Test func tenantRoutingShouldUseWelcomePrefixForConversoxEndpoints() throws {
        let api = ConversoxAPI()
        let path = api.resolvedPath(for: .chats, tenant: "welcome")
        #expect(path == "/Welcome/Conversox/api/chats.php")
    }

    @Test func errorMappingShouldPreserveForbiddenNotAssignedMeaning() throws {
        let error = ConversoxError.backend(
            httpStatus: 403,
            backendError: "forbidden_not_assigned",
            rawBody: "{\"ok\":false,\"error\":\"forbidden_not_assigned\"}"
        )

        #expect(error.kind == .backend)
        #expect(error.httpStatus == 403)
        #expect(error.backendError == "forbidden_not_assigned")
        #expect(error.userMessage.contains("nao atribuida"))
    }

    @MainActor
    @Test func chatStoreShouldFilterLowPriorityAndChannel() {
        let store = ChatStore()
        store.replaceAll([
            Chat(
                jid: "5511@s.whatsapp.net",
                connectionID: "evolution:main",
                instance: "main",
                title: "Cliente WA",
                unreadCount: 1,
                lastMessagePreview: "Oi",
                avatarPath: nil,
                updatedAt: Date(),
                chatCode: nil,
                isGroup: false,
                badge: nil,
                nameSource: nil,
                lastMessageType: "text",
                lastMessageFileName: nil,
                lastFromMe: false,
                isLowPriority: false
            ),
            Chat(
                jid: "5512@s.whatsapp.net",
                connectionID: "email:inbox",
                instance: nil,
                title: "Cliente Email",
                unreadCount: 0,
                lastMessagePreview: "Doc",
                avatarPath: nil,
                updatedAt: Date(),
                chatCode: nil,
                isGroup: false,
                badge: nil,
                nameSource: nil,
                lastMessageType: "document",
                lastMessageFileName: "arquivo.pdf",
                lastFromMe: true,
                isLowPriority: true
            )
        ])

        let inboxWA = store.filteredChats(searchText: "", filter: .inbox, channel: .wa)
        #expect(inboxWA.count == 1)
        #expect(inboxWA.first?.title == "Cliente WA")

        let lowAll = store.filteredChats(searchText: "", filter: .low, channel: .all)
        #expect(lowAll.count == 1)
        #expect(lowAll.first?.title == "Cliente Email")
    }

    @MainActor
    @Test func messageStoreShouldDeduplicateInlineMessagesByKeyID() {
        let store = MessageStore()
        let now = Date()
        let incoming = [
            Message(
                id: "msg-1",
                keyID: "msg-key-1",
                chatID: "",
                connectionID: "evolution:main",
                senderName: "Cliente",
                text: "Oi",
                sentAt: now,
                fromMe: false,
                type: "text",
                status: "delivered",
                mediaURL: nil,
                mimeType: nil,
                fileName: nil,
                duration: nil,
                quotedMessageID: nil,
                quotedText: nil,
                isDeleted: false,
                isForwarded: false,
                editedAt: nil,
                reactions: []
            ),
            Message(
                id: "msg-1-duplicate",
                keyID: "msg-key-1",
                chatID: "",
                connectionID: "evolution:main",
                senderName: "Cliente",
                text: "Oi duplicada",
                sentAt: now.addingTimeInterval(1),
                fromMe: false,
                type: "text",
                status: "delivered",
                mediaURL: nil,
                mimeType: nil,
                fileName: nil,
                duration: nil,
                quotedMessageID: nil,
                quotedText: nil,
                isDeleted: false,
                isForwarded: false,
                editedAt: nil,
                reactions: []
            )
        ]

        let merged = store.appendInline(incoming, to: "evolution:main|5511@s.whatsapp.net")
        #expect(merged.count == 1)
        #expect(merged.first?.text == "Oi")
    }
}
