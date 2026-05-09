import AppKit
import Foundation

enum SidebarTab: String, CaseIterable, Identifiable {
    case chats
    case contacts

    var id: String { rawValue }
    var title: String { self == .chats ? "Chats" : "Contatos" }
}

@MainActor
final class ChatsViewModel: ObservableObject {
    @Published private(set) var chats: [Chat] = []
    @Published private(set) var visibleChats: [Chat] = []
    @Published private(set) var hasMoreChats = false
    @Published private(set) var messagesByChat: [String: [Message]] = [:]
    @Published private(set) var hasOlderByChat: [String: Bool] = [:]
    @Published private(set) var isLoadingOlderByChat: [String: Bool] = [:]

    @Published var selectedChatID: String?
    @Published var draftMessage = ""
    @Published var errorMessage: String?
    @Published var replyTarget: Message?
    @Published var composerAttachments: [ComposerAttachment] = []
    @Published private(set) var isSendingMessage = false
    @Published var isInternalNotesMode = false

    @Published var searchText = "" {
        didSet { resetChatPagination() }
    }

    @Published var selectedFilter: ChatFilter = .inbox {
        didSet { resetChatPagination() }
    }

    @Published var selectedChannel: ChatChannel = .wa {
        didSet { resetChatPagination() }
    }

    @Published var selectedSidebarTab: SidebarTab = .chats
    @Published var contactSearchText = "" {
        didSet { syncChatSnapshots() }
    }
    @Published private(set) var contactsDirectory: [ContactDirectoryEntry] = []
    @Published private(set) var quickReplies: [String] = [
        "Perfeito, vou validar e te retorno em seguida.",
        "Recebido, obrigado! Vamos seguir com a análise.",
        "Consegue me confirmar esse ponto para eu avançar?"
    ]

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

    private let maxAttachmentBytes = 16 * 1024 * 1024

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
            hasOlderByChat[chatID] = response.hasOlder ?? false
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Falha ao carregar mensagens."
        }
    }

    func loadOlderMessages(for chatID: String) async {
        guard isLoadingOlderByChat[chatID] != true,
              hasOlderByChat[chatID] == true,
              let session = currentSession,
              let chat = chatStore.chat(for: chatID),
              let firstMessage = messageStore.messages(for: chatID).first else { return }

        isLoadingOlderByChat[chatID] = true
        defer { isLoadingOlderByChat[chatID] = false }

        do {
            let beforeTS = max(Int(firstMessage.sentAt.timeIntervalSince1970), 1)
            let response = try await chatsService.fetchMessages(session: session, chat: chat, limit: 50, beforeTS: beforeTS)
            let merged = messageStore.prependOlder(response.messages, to: chatID)
            messagesByChat[chatID] = merged

            if let explicit = response.hasOlder {
                hasOlderByChat[chatID] = explicit
            } else {
                hasOlderByChat[chatID] = !response.messages.isEmpty
            }
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Falha ao carregar histórico antigo."
        }
    }

    func loadMoreChats() {
        guard hasMoreChats else { return }
        visibleLimit += 150
        syncChatSnapshots()
    }

    func setReplyTarget(_ message: Message) {
        replyTarget = message
    }

    func clearReplyTarget() {
        replyTarget = nil
    }

    func toggleInternalNotesMode() {
        isInternalNotesMode.toggle()
    }

    func attachFile(url: URL) {
        do {
            let attachment = try ComposerAttachment.fromFileURL(url)
            try validateAttachmentSize(attachment)
            composerAttachments.append(attachment)
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Falha ao anexar arquivo."
        }
    }

    func attachPastedImage(data: Data) {
        let attachment = ComposerAttachment(fileName: "paste-\(Int(Date().timeIntervalSince1970)).png", mimeType: "image/png", data: data)
        do {
            try validateAttachmentSize(attachment)
            composerAttachments.append(attachment)
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Imagem colada excede o limite de tamanho."
        }
    }

    func removeAttachment(_ attachment: ComposerAttachment) {
        composerAttachments.removeAll { $0.id == attachment.id }
    }

    func sendMessage() async {
        guard let chat = selectedChat,
              let session = currentSession else { return }

        let trimmedText = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let queuedAttachments = composerAttachments
        let replyID = replyTarget?.id

        guard !trimmedText.isEmpty || !queuedAttachments.isEmpty else { return }
        guard !isSendingMessage else { return }

        isSendingMessage = true
        defer { isSendingMessage = false }

        let backupDraft = draftMessage
        let backupReply = replyTarget
        let backupAttachments = composerAttachments

        do {
            if queuedAttachments.isEmpty {
                try await chatsService.sendMessage(
                    session: session,
                    chat: chat,
                    text: trimmedText,
                    quotedMessageID: replyID,
                    note: isInternalNotesMode
                )
            } else {
                for (index, attachment) in queuedAttachments.enumerated() {
                    try validateAttachmentSize(attachment)
                    let textForThisMessage = index == 0 ? trimmedText : ""
                    let replyForThisMessage = index == 0 ? replyID : nil

                    try await chatsService.sendMessage(
                        session: session,
                        chat: chat,
                        text: textForThisMessage,
                        quotedMessageID: replyForThisMessage,
                        note: isInternalNotesMode,
                        attachment: attachment
                    )
                }
            }

            draftMessage = ""
            composerAttachments = []
            replyTarget = nil

            await loadMessages(for: chat.id)
            await reloadChats()
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
            draftMessage = backupDraft
            replyTarget = backupReply
            composerAttachments = backupAttachments
        } catch {
            errorMessage = "Falha ao enviar mensagem."
            draftMessage = backupDraft
            replyTarget = backupReply
            composerAttachments = backupAttachments
        }
    }

    func fetchMedia(for chatID: String, message: Message) async {
        guard let session = currentSession,
              let chat = chatStore.chat(for: chatID) else { return }
        do {
            let mediaURL = try await chatsService.fetchMedia(
                session: session,
                chat: chat,
                messageID: message.id,
                mimeType: message.mimeType
            )
            let messages = messageStore.updateMediaURL(chatID: chatID, messageID: message.id, mediaURL: mediaURL)
            messagesByChat[chatID] = messages
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Falha ao carregar mídia."
        }
    }

    func resolvedMediaURL(_ raw: String?) -> URL? {
        guard let raw, !raw.isEmpty else { return nil }
        if let absolute = URL(string: raw), absolute.scheme != nil {
            return absolute
        }

        guard var components = URLComponents(url: AppConfig.shared.serverBaseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.path = raw.hasPrefix("/") ? raw : "/\(raw)"
        return components.url
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

    func markSelectedChatAsUnread() async {
        guard let session = currentSession,
              let chat = selectedChat else { return }
        do {
            try await chatsService.markUnread(session: session, chat: chat)
            await reloadChats()
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Falha ao marcar conversa como nao lida."
        }
    }

    func toggleSelectedChatLowPriority() async {
        guard let session = currentSession,
              let chat = selectedChat else { return }
        do {
            try await chatsService.setLowPriority(session: session, chat: chat, isLowPriority: !chat.isLowPriority)
            await reloadChats()
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Falha ao alterar prioridade da conversa."
        }
    }

    func transferSelectedChat(target: String) async {
        guard let session = currentSession,
              let chat = selectedChat else { return }
        let clean = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        do {
            try await chatsService.transfer(session: session, chat: chat, target: clean)
            await reloadChats()
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Falha ao transferir conversa."
        }
    }

    func inviteSelectedChatToGroup(members: String) async {
        guard let session = currentSession,
              let chat = selectedChat else { return }
        let clean = members.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        do {
            try await chatsService.groupInvite(session: session, chat: chat, members: clean)
            await reloadChats()
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Falha ao convidar para grupo."
        }
    }

    func sendQuickReply(_ text: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        draftMessage = text
        await sendMessage()
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
        hasOlderByChat = [:]
        isLoadingOlderByChat = [:]

        selectedChatID = nil
        draftMessage = ""
        errorMessage = nil
        replyTarget = nil
        composerAttachments = []
        isSendingMessage = false
        isInternalNotesMode = false

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
        contactsDirectory = chatStore.contactsDirectory(searchText: contactSearchText, channel: selectedChannel)
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

    private func validateAttachmentSize(_ attachment: ComposerAttachment) throws {
        guard attachment.data.count <= maxAttachmentBytes else {
            throw ConversoxError.backend(httpStatus: 413, backendError: "file_too_large", rawBody: nil)
        }
    }
}
