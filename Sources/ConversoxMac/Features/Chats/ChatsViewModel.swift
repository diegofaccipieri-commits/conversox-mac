import AppKit
import Foundation

@MainActor
final class ChatsViewModel: ObservableObject {
    @Published private(set) var chats: [Chat] = []
    @Published private(set) var messagesByChat: [String: [Message]] = [:]
    @Published var selectedChatID: String?
    @Published var draftMessage = ""
    @Published var errorMessage: String?

    private let chatsService = ChatsService()
    private var pollTask: Task<Void, Never>?
    private var pollCursor = Date().timeIntervalSince1970

    private var currentSession: PersistedSession? {
        try? AuthService.shared.restoreSession()
    }

    private var selectedChat: Chat? {
        guard let selectedChatID else { return nil }
        return chats.first { $0.id == selectedChatID }
    }

    func loadInitialChatsIfNeeded() async {
        guard chats.isEmpty else { return }
        await reloadChats()
    }

    func reloadChats() async {
        guard let session = currentSession else { return }
        do {
            let response = try await chatsService.fetchChats(session: session)
            chats = response.items
            if selectedChatID == nil {
                selectedChatID = chats.first?.id
            }
            updateBadge()
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Falha ao carregar chats."
        }
    }

    func loadMessages(for chatID: String) async {
        guard let session = currentSession,
              let chat = chats.first(where: { $0.id == chatID }) else { return }
        do {
            let response = try await chatsService.fetchMessages(session: session, chat: chat)
            messagesByChat[chatID] = response.messages
            try? await chatsService.markRead(session: session, chat: chat)
            await reloadChats()
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Falha ao carregar mensagens."
        }
    }

    func sendMessage() async {
        guard let chat = selectedChat,
              !draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let session = currentSession else { return }

        let text = draftMessage
        draftMessage = ""

        do {
            try await chatsService.sendMessage(session: session, chat: chat, text: text)
            await loadMessages(for: chat.id)
            await reloadChats()
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
            draftMessage = text
        } catch {
            errorMessage = "Falha ao enviar mensagem."
            draftMessage = text
        }
    }

    func startRealtime() async {
        guard pollTask == nil else { return }
        pollCursor = Date().timeIntervalSince1970
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollOnce()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    func reset() {
        pollTask?.cancel()
        pollTask = nil
        chats = []
        messagesByChat = [:]
        selectedChatID = nil
        draftMessage = ""
        errorMessage = nil
        updateBadge()
    }

    private func pollOnce() async {
        guard let session = currentSession else { return }
        do {
            let response = try await chatsService.poll(session: session, sinceTS: pollCursor, activeChat: selectedChat)
            pollCursor = response.serverTS ?? Date().timeIntervalSince1970

            if !response.inlineMessages.isEmpty, let selectedChat {
                let messages = response.inlineMessages.map { $0.withChatID(selectedChat.id) }
                messagesByChat[selectedChat.id, default: []].append(contentsOf: messages)
                if let latest = messages.last, !latest.fromMe {
                    NotificationPermissionManager.shared.notifyNewMessage(chatTitle: selectedChat.title, preview: latest.text)
                }
            }

            if !response.changedChats.isEmpty || response.inlineMessages.isEmpty == false {
                await reloadChats()
            }
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Falha no polling do Conversox."
        }
    }

    private func updateBadge() {
        let totalUnread = chats.reduce(0) { $0 + $1.unreadCount }
        NSApplication.shared.dockTile.badgeLabel = totalUnread > 0 ? String(totalUnread) : nil
    }
}
