import AppKit
import Foundation

@MainActor
final class ChatsViewModel: ObservableObject {
    @Published private(set) var chats: [Chat] = []
    @Published private(set) var visibleChats: [Chat] = []
    @Published private(set) var hasMoreChats = false
    @Published private(set) var messagesByChat: [String: [Message]] = [:]
    @Published var selectedChatID: String?
    @Published var draftMessage = ""
    @Published var errorMessage: String?

    @Published var searchText = "" {
        didSet { resetChatPagination() }
    }

    @Published var selectedFilter: ChatFilter = .inbox {
        didSet { resetChatPagination() }
    }

    @Published var selectedChannel: ChatChannel = .wa {
        didSet { resetChatPagination() }
    }

    private let chatsService = ChatsService()
    private let chatStore = ChatStore()
    private let messageStore = MessageStore()

    private var pollTask: Task<Void, Never>?
    private var pollCursor: Double = 1
    private var pollSeq: Int?
    private var pollIntervalSeconds: UInt64 = 3
    private var chatsLoaded = false
    private var visibleLimit = 150

    private let backoffSchedule: [UInt64] = [3, 15, 30, 60, 120]
    private var backoffIndex = 0

    private var currentSession: PersistedSession? {
        try? AuthService.shared.restoreSession()
    }

    private var selectedChat: Chat? {
        chatStore.chat(for: selectedChatID)
    }

    func loadInitialChatsIfNeeded() async {
        guard !chatsLoaded else { return }
        await reloadChats()
    }

    func reloadChats() async {
        guard let session = currentSession else { return }
        do {
            let response = try await chatsService.fetchChats(session: session)
            chatStore.replaceAll(response.items)
            chatsLoaded = true
            syncChatSnapshots()
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
              let chat = chatStore.chat(for: chatID) else { return }
        do {
            let response = try await chatsService.fetchMessages(session: session, chat: chat)
            messageStore.setMessages(response.messages, for: chatID)
            syncMessages(for: chatID)
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Falha ao carregar mensagens."
        }
    }

    func loadMoreChats() {
        guard hasMoreChats else { return }
        visibleLimit += 150
        syncChatSnapshots()
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

    func markSelectedChatAsRead() async {
        guard let session = currentSession,
              let chat = selectedChat else { return }
        do {
            try await chatsService.markRead(session: session, chat: chat)
            await reloadChats()
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Falha ao marcar conversa como lida."
        }
    }

    func startRealtime() async {
        guard pollTask == nil else { return }
        if pollCursor <= 0 {
            pollCursor = Date().timeIntervalSince1970
        }

        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollOnce()
                let seconds = self?.pollIntervalSeconds ?? 3
                try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            }
        }
    }

    func reset() {
        pollTask?.cancel()
        pollTask = nil

        chats = []
        visibleChats = []
        hasMoreChats = false
        messagesByChat = [:]

        selectedChatID = nil
        draftMessage = ""
        errorMessage = nil

        pollCursor = 1
        pollSeq = nil
        pollIntervalSeconds = 3
        backoffIndex = 0
        chatsLoaded = false
        visibleLimit = 150

        updateBadge()
    }

    private func pollOnce() async {
        guard let session = currentSession else { return }

        do {
            let activeChat = selectedChat
            let newestTS = activeChat.map { messageStore.newestTimestamp(for: $0.id) }

            let response = try await chatsService.poll(
                session: session,
                sinceTS: pollCursor,
                sinceSeq: pollSeq,
                newestTS: newestTS,
                activeChat: activeChat
            )

            pollCursor = response.serverTS ?? Date().timeIntervalSince1970
            pollSeq = response.serverSeq ?? pollSeq
            resetBackoff()

            var shouldReloadSelectedThread = false

            if !response.changedChats.isEmpty {
                _ = chatStore.merge(changes: response.changedChats)

                if let selectedChatID,
                   response.changedChats.contains(where: { $0.chatID == selectedChatID }),
                   response.inlineMessages.isEmpty {
                    shouldReloadSelectedThread = true
                }
            }

            if let activeChat, !response.inlineMessages.isEmpty {
                let incoming = response.inlineMessages.map { $0.withChatID(activeChat.id) }
                let messages = messageStore.appendInline(incoming, to: activeChat.id)
                messagesByChat[activeChat.id] = messages

                if let latest = incoming.last, !latest.fromMe {
                    NotificationPermissionManager.shared.notifyNewMessage(chatTitle: activeChat.title, preview: latest.text)
                }
            }

            if shouldReloadSelectedThread, let selectedChatID {
                await loadMessages(for: selectedChatID)
            }

            if !response.changedChats.isEmpty || !response.inlineMessages.isEmpty {
                syncChatSnapshots()
                updateBadge()
            }
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
            handleBackoff(for: error)
        } catch {
            errorMessage = "Falha no polling do Conversox."
            backoffIndex = min(backoffIndex + 1, backoffSchedule.count - 1)
            pollIntervalSeconds = backoffSchedule[backoffIndex]
        }
    }

    private func syncMessages(for chatID: String) {
        messagesByChat[chatID] = messageStore.messages(for: chatID)
    }

    private func syncChatSnapshots() {
        chats = chatStore.allChatsSorted()
        let filtered = chatStore.filteredChats(searchText: searchText, filter: selectedFilter, channel: selectedChannel)
        hasMoreChats = filtered.count > visibleLimit
        visibleChats = Array(filtered.prefix(visibleLimit))
    }

    private func resetChatPagination() {
        visibleLimit = 150
        syncChatSnapshots()
    }

    private func handleBackoff(for error: ConversoxError) {
        guard let status = error.httpStatus else { return }

        switch status {
        case 403, 429, 503:
            backoffIndex = min(backoffIndex + 1, backoffSchedule.count - 1)
            pollIntervalSeconds = backoffSchedule[backoffIndex]
        default:
            break
        }
    }

    private func resetBackoff() {
        backoffIndex = 0
        pollIntervalSeconds = backoffSchedule[0]
    }

    private func updateBadge() {
        let totalUnread = chatStore.unreadTotal()
        NSApplication.shared.dockTile.badgeLabel = totalUnread > 0 ? String(totalUnread) : nil
    }
}
