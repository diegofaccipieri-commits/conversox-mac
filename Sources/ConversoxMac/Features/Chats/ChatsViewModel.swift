import AppKit
import Foundation

enum SidebarTab: String, CaseIterable, Identifiable {
    case chats
    case contacts

    var id: String { rawValue }
    var title: String { self == .chats ? "Chats" : "Contatos" }
}

struct CXToastState: Identifiable, Sendable {
    let id = UUID()
    let message: String
    let isError: Bool
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
    @Published var forwardedMessage: Message?
    @Published var selectedForwardTargetChatID: String?
    @Published private(set) var notesByChat: [String: [ChatNote]] = [:]
    @Published var noteDraft = ""
    @Published private(set) var stickerPackIDs: [String] = []
    @Published private(set) var stickerIDs: [String] = []
    @Published var selectedStickerPackID: String?

    @Published var searchText = "" {
        didSet { resetChatPagination() }
    }

    @Published var selectedFilter: ChatFilter = .inbox {
        didSet { resetChatPagination() }
    }

    @Published var selectedChannel: ChatChannel = .wa {
        didSet { resetChatPagination() }
    }

    @Published var selectedSidebarTab: SidebarTab = .chats {
        didSet {
            if selectedSidebarTab == .contacts {
                Task { await refreshContactsDirectory() }
            }
        }
    }
    @Published var contactSearchText = "" {
        didSet {
            syncChatSnapshots()
            if selectedSidebarTab == .contacts {
                Task { await refreshContactsDirectory() }
            }
        }
    }
    @Published private(set) var contactsDirectory: [ContactDirectoryEntry] = []
    @Published private(set) var quickReplies: [String] = [
        "Perfeito, vou validar e te retorno em seguida.",
        "Recebido, obrigado! Vamos seguir com a análise.",
        "Consegue me confirmar esse ponto para eu avançar?"
    ]
    @Published var quickReplyDraft = ""
    @Published private(set) var toast: CXToastState?
    @Published private(set) var isBootstrapping = true

    private let chatsService = ChatsService()
    private let chatStore = ChatStore()
    private let messageStore = MessageStore()

    private var pollTask: Task<Void, Never>?
    private var pollCursor: Double = 1
    private var pollSeq: Int?
    private var pollIntervalSeconds: UInt64 = 3
    private var chatsLoaded = false
    private var visibleLimit = 150
    private var didLoadQuickReplies = false
    private var quickReplyIDByBody: [String: String] = [:]

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
            await loadQuickRepliesIfNeeded()
            updateBadge()
            isBootstrapping = false
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
            showToast(error.userMessage, isError: true)
            isBootstrapping = false
        } catch {
            errorMessage = "Falha ao carregar chats."
            showToast("Falha ao carregar chats.", isError: true)
            isBootstrapping = false
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
            await loadNotes(for: chatID)
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

    func openForward(_ message: Message) {
        forwardedMessage = message
        selectedForwardTargetChatID = nil
    }

    func closeForward() {
        forwardedMessage = nil
        selectedForwardTargetChatID = nil
    }

    func toggleInternalNotesMode() {
        isInternalNotesMode.toggle()
    }

    func loadQuickRepliesIfNeeded() async {
        guard !didLoadQuickReplies, let session = currentSession else { return }
        didLoadQuickReplies = true
        do {
            let entries = try await chatsService.fetchQuickReplyEntries(session: session)
            if !entries.isEmpty {
                quickReplies = entries.map(\.body)
                quickReplyIDByBody = entries.reduce(into: [:]) { acc, item in
                    if let id = item.id {
                        acc[item.body] = id
                    }
                }
            }
        } catch {
            // Keep local defaults if backend endpoint is unavailable.
        }
    }

    func refreshContactsDirectory() async {
        guard let session = currentSession else { return }
        do {
            let contacts = try await chatsService.fetchContactsDirectory(session: session, search: contactSearchText)
            if !contacts.isEmpty {
                contactsDirectory = contacts
            } else {
                contactsDirectory = chatStore.contactsDirectory(searchText: contactSearchText, channel: selectedChannel)
            }
        } catch {
            contactsDirectory = chatStore.contactsDirectory(searchText: contactSearchText, channel: selectedChannel)
        }
    }

    func loadNotes(for chatID: String) async {
        guard let session = currentSession,
              let chat = chatStore.chat(for: chatID) else { return }
        do {
            let notes = try await chatsService.fetchNotes(session: session, chat: chat)
            notesByChat[chatID] = notes
        } catch {
            notesByChat[chatID] = notesByChat[chatID] ?? []
        }
    }

    func addNote(for chatID: String) async {
        guard let session = currentSession,
              let chat = chatStore.chat(for: chatID) else { return }
        let text = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            _ = try await chatsService.createNote(session: session, chat: chat, text: text)
            noteDraft = ""
            await loadNotes(for: chatID)
            showToast("Nota salva.", isError: false)
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
            showToast(error.userMessage, isError: true)
        } catch {
            errorMessage = "Falha ao salvar nota."
            showToast("Falha ao salvar nota.", isError: true)
        }
    }

    func removeNote(noteID: String, chatID: String) async {
        guard let session = currentSession else { return }
        do {
            try await chatsService.deleteNote(session: session, noteID: noteID)
            await loadNotes(for: chatID)
            showToast("Nota removida.", isError: false)
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
            showToast(error.userMessage, isError: true)
        } catch {
            errorMessage = "Falha ao remover nota."
            showToast("Falha ao remover nota.", isError: true)
        }
    }

    func loadStickerPacks() async {
        guard let session = currentSession else { return }
        do {
            stickerPackIDs = try await chatsService.fetchStickerPackIDs(session: session)
            if selectedStickerPackID == nil {
                selectedStickerPackID = stickerPackIDs.first
            }
            if let selectedStickerPackID {
                await loadStickers(packID: selectedStickerPackID)
            }
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
            showToast(error.userMessage, isError: true)
        } catch {
            errorMessage = "Falha ao carregar packs de stickers."
            showToast("Falha ao carregar packs de stickers.", isError: true)
        }
    }

    func loadStickers(packID: String) async {
        guard let session = currentSession else { return }
        do {
            selectedStickerPackID = packID
            stickerIDs = try await chatsService.fetchStickers(session: session, packID: packID)
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
            showToast(error.userMessage, isError: true)
        } catch {
            errorMessage = "Falha ao carregar stickers."
            showToast("Falha ao carregar stickers.", isError: true)
        }
    }

    func sendSticker(stickerID: String) async {
        guard let session = currentSession,
              let chat = selectedChat else { return }
        do {
            try await chatsService.sendSticker(session: session, chat: chat, stickerID: stickerID)
            await loadMessages(for: chat.id)
            showToast("Sticker enviado.", isError: false)
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
            showToast(error.userMessage, isError: true)
        } catch {
            errorMessage = "Falha ao enviar sticker."
            showToast("Falha ao enviar sticker.", isError: true)
        }
    }

    func saveStickerFromMessage(_ message: Message) async {
        guard let session = currentSession,
              let mediaURL = message.mediaURL else { return }
        do {
            try await chatsService.saveStickerFromMedia(session: session, mediaURL: mediaURL)
            await loadStickerPacks()
            showToast("Sticker salvo.", isError: false)
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
            showToast(error.userMessage, isError: true)
        } catch {
            errorMessage = "Falha ao salvar sticker."
            showToast("Falha ao salvar sticker.", isError: true)
        }
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
            var outboundText = trimmedText
            if queuedAttachments.isEmpty, let expanded = resolveShortcutIfNeeded(trimmedText) {
                outboundText = expanded
            }

            if queuedAttachments.isEmpty {
                try await chatsService.sendMessage(
                    session: session,
                    chat: chat,
                    text: outboundText,
                    quotedMessageID: replyID,
                    note: isInternalNotesMode
                )
            } else {
                for (index, attachment) in queuedAttachments.enumerated() {
                    try validateAttachmentSize(attachment)
                    let textForThisMessage = index == 0 ? outboundText : ""
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
            showToast("Mensagem enviada.", isError: false)
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
            showToast(error.userMessage, isError: true)
            draftMessage = backupDraft
            replyTarget = backupReply
            composerAttachments = backupAttachments
        } catch {
            errorMessage = "Falha ao enviar mensagem."
            showToast("Falha ao enviar mensagem.", isError: true)
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

    func editMessage(chatID: String, message: Message, newText: String) async {
        guard let session = currentSession,
              let chat = chatStore.chat(for: chatID) else { return }
        let text = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            try await chatsService.editMessage(session: session, chat: chat, messageID: message.id, text: text)
            messagesByChat[chatID] = messageStore.updateMessageText(chatID: chatID, messageID: message.id, text: text)
            showToast("Mensagem editada.", isError: false)
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
            showToast(error.userMessage, isError: true)
        } catch {
            errorMessage = "Falha ao editar mensagem."
            showToast("Falha ao editar mensagem.", isError: true)
        }
    }

    func deleteMessage(chatID: String, message: Message, forEveryone: Bool) async {
        guard let session = currentSession,
              let chat = chatStore.chat(for: chatID) else { return }
        do {
            try await chatsService.deleteMessage(
                session: session,
                chat: chat,
                messageID: message.id,
                deleteScope: forEveryone ? "for_everyone" : "for_me"
            )
            messagesByChat[chatID] = messageStore.markMessageDeleted(chatID: chatID, messageID: message.id)
            showToast("Mensagem apagada.", isError: false)
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
            showToast(error.userMessage, isError: true)
        } catch {
            errorMessage = "Falha ao apagar mensagem."
            showToast("Falha ao apagar mensagem.", isError: true)
        }
    }

    func reactToMessage(chatID: String, message: Message, emoji: String) async {
        guard let session = currentSession,
              let chat = chatStore.chat(for: chatID) else { return }
        do {
            try await chatsService.reactToMessage(session: session, chat: chat, messageID: message.id, emoji: emoji)
            let reaction = Message.Reaction(emoji: emoji, jid: session.user.email, name: session.user.name)
            messagesByChat[chatID] = messageStore.toggleReaction(chatID: chatID, messageID: message.id, reaction: reaction)
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
            showToast(error.userMessage, isError: true)
        } catch {
            errorMessage = "Falha ao reagir à mensagem."
            showToast("Falha ao reagir à mensagem.", isError: true)
        }
    }

    func retryMessage(chatID: String, message: Message) async {
        guard message.status == "failed" else { return }
        draftMessage = message.text
        await sendMessage()
    }

    func forwardMessage() async {
        guard let source = forwardedMessage,
              let targetChatID = selectedForwardTargetChatID,
              let targetChat = chatStore.chat(for: targetChatID),
              let session = currentSession else { return }

        do {
            try await chatsService.forwardMessage(session: session, sourceMessage: source, targetChat: targetChat)
            closeForward()
            showToast("Mensagem encaminhada.", isError: false)
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
            showToast(error.userMessage, isError: true)
        } catch {
            errorMessage = "Falha ao encaminhar mensagem."
            showToast("Falha ao encaminhar mensagem.", isError: true)
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
            showToast("Conversa transferida.", isError: false)
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
            showToast(error.userMessage, isError: true)
        } catch {
            errorMessage = "Falha ao transferir conversa."
            showToast("Falha ao transferir conversa.", isError: true)
        }
    }

    func fetchSelectedGroupInvite() async {
        guard let session = currentSession,
              let chat = selectedChat else { return }
        do {
            let inviteURL = try await chatsService.fetchGroupInvite(session: session, chat: chat)
            if let inviteURL, !inviteURL.isEmpty {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(inviteURL, forType: .string)
                showToast("Link de convite copiado.", isError: false)
            }
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
            showToast(error.userMessage, isError: true)
        } catch {
            errorMessage = "Falha ao obter link de convite do grupo."
            showToast("Falha ao obter link de convite.", isError: true)
        }
    }

    func sendQuickReply(_ text: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        draftMessage = text
        await sendMessage()
    }

    func addQuickReply() async {
        guard let session = currentSession else { return }
        let clean = quickReplyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let parsed = parseQuickReplyInput(clean)
        guard !quickReplies.contains(parsed.body) else {
            quickReplyDraft = ""
            return
        }

        do {
            let created = try await chatsService.createQuickReply(session: session, shortcut: parsed.shortcut, body: parsed.body)
            quickReplies.append(parsed.body)
            quickReplies.sort()
            if let id = created?.id {
                quickReplyIDByBody[parsed.body] = id
            }
            showToast("Quick reply adicionada.", isError: false)
            quickReplyDraft = ""
        } catch let error as ConversoxError {
            errorMessage = error.userMessage
            showToast(error.userMessage, isError: true)
        } catch {
            errorMessage = "Falha ao salvar quick reply."
            showToast("Falha ao salvar quick reply.", isError: true)
        }
    }

    func removeQuickReply(_ value: String) async {
        guard let session = currentSession else { return }
        if let id = quickReplyIDByBody[value] {
            do {
                try await chatsService.deleteQuickReply(session: session, id: id)
                quickReplyIDByBody.removeValue(forKey: value)
            } catch let error as ConversoxError {
                errorMessage = error.userMessage
                showToast(error.userMessage, isError: true)
                return
            } catch {
                errorMessage = "Falha ao remover quick reply."
                showToast("Falha ao remover quick reply.", isError: true)
                return
            }
        }
        quickReplies.removeAll { $0 == value }
        showToast("Quick reply removida.", isError: false)
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
        didLoadQuickReplies = false
        forwardedMessage = nil
        selectedForwardTargetChatID = nil
        notesByChat = [:]
        noteDraft = ""
        stickerPackIDs = []
        stickerIDs = []
        selectedStickerPackID = nil
        quickReplyIDByBody = [:]

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

    private func resolveShortcutIfNeeded(_ text: String) -> String? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.hasPrefix("/") else { return nil }
        let token = String(clean.dropFirst()).lowercased()
        guard !token.isEmpty else { return nil }
        return quickReplies.first { $0.lowercased().contains(token) }
    }

    private func showToast(_ message: String, isError: Bool) {
        toast = CXToastState(message: message, isError: isError)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard let self else { return }
            if self.toast?.message == message {
                self.toast = nil
            }
        }
    }

    private func parseQuickReplyInput(_ input: String) -> (shortcut: String, body: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("/") {
            let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            if let first = parts.first {
                let shortcut = String(first)
                let body = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines) : shortcut
                return (normalizeShortcut(shortcut), body.isEmpty ? shortcut : body)
            }
        }
        return (normalizeShortcut("/qr_\(UUID().uuidString.prefix(8))"), trimmed)
    }

    private func normalizeShortcut(_ raw: String) -> String {
        var shortcut = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !shortcut.hasPrefix("/") {
            shortcut = "/\(shortcut)"
        }
        let cleaned = shortcut.replacingOccurrences(of: "[^/a-z0-9_]", with: "_", options: .regularExpression)
        return cleaned == "/" ? "/qr_\(Int(Date().timeIntervalSince1970))" : cleaned
    }
}
