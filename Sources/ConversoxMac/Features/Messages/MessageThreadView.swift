import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

struct MessageThreadView: View {
    @EnvironmentObject private var vm: ChatsViewModel

    let chatID: String

    @State private var isDropTargeted = false
    @State private var showForwardSheet = false
    @State private var editingMessage: Message?
    @State private var editedText = ""
    @State private var isNearBottom = true
    @State private var pendingNewMessages = 0
    @State private var highlightedMessageID: String?
    @State private var lightboxURL: URL?

    private let quickReactions = ["👍", "❤️", "😂", "😮", "😢", "🙏"]

    private var messages: [Message] {
        vm.messagesByChat[chatID] ?? []
    }

    private var chatConnectionID: String? {
        vm.chats.first(where: { $0.id == chatID })?.connectionID
    }

    private var isGroupThread: Bool {
        vm.chats.first(where: { $0.id == chatID })?.isGroup ?? false
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                CXColor.bg.ignoresSafeArea()

                ScrollViewReader { proxy in
                    GeometryReader { geo in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            if vm.hasOlderByChat[chatID] == true {
                                Button {
                                    Task { await vm.loadOlderMessages(for: chatID) }
                                } label: {
                                    Text(vm.isLoadingOlderByChat[chatID] == true ? "Carregando..." : "Carregar mais histórico")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(CXColor.textSoft)
                                        .padding(.horizontal, CXSize.s3)
                                        .frame(height: 28)
                                        .background(CXColor.surface)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(CXColor.borderLight, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .padding(.bottom, CXSize.s2)
                            }

                            ForEach(Array(messages.enumerated()), id: \.1.id) { index, message in
                                if shouldShowDateSeparator(at: index) {
                                    dateSeparator(formattedDayLabel(for: message.sentAt))
                                }

                                CXMessageBubbleView(
                                    message: message,
                                    mediaURL: vm.resolvedMediaURL(message.mediaURL),
                                    groupAvatarURL: groupAvatarURL(for: index),
                                    hasGroupAvatarSlot: hasGroupAvatarSlot(at: index),
                                    showGroupAvatar: shouldShowGroupAvatar(at: index),
                                    isFirstOfGroup: isFirstOfGroup(at: index),
                                    isHighlighted: isMessageHighlighted(message),
                                    quickReactions: quickReactions,
                                    onReply: { vm.setReplyTarget(message) },
                                    onJumpToQuoted: { quotedID in
                                        jumpToQuotedMessage(quotedID, proxy: proxy)
                                    },
                                    onFetchMedia: {
                                        Task { await vm.fetchMedia(for: chatID, message: message) }
                                    },
                                    onEdit: {
                                        editingMessage = message
                                        editedText = message.text
                                    },
                                    onDeleteForMe: {
                                        Task { await vm.deleteMessage(chatID: chatID, message: message, forEveryone: false) }
                                    },
                                    onDeleteForEveryone: {
                                        Task { await vm.deleteMessage(chatID: chatID, message: message, forEveryone: true) }
                                    },
                                    onReact: { emoji in
                                        Task { await vm.reactToMessage(chatID: chatID, message: message, emoji: emoji) }
                                    },
                                    onForward: {
                                        vm.openForward(message)
                                        showForwardSheet = true
                                    },
                                    onRetry: {
                                        Task { await vm.retryMessage(chatID: chatID, message: message) }
                                    },
                                    onSaveSticker: {
                                        Task { await vm.saveStickerFromMessage(message) }
                                    },
                                    onOpenLightbox: { url in
                                        lightboxURL = url
                                    }
                                )
                                .id(message.id)
                                .onAppear {
                                    if message.id == messages.last?.id {
                                        isNearBottom = true
                                        pendingNewMessages = 0
                                    }
                                }
                                .onDisappear {
                                    if message.id == messages.last?.id {
                                        isNearBottom = false
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 18)
                        .padding(.bottom, 16)
                        .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .bottom)
                    }
                    .defaultScrollAnchor(.bottom)
                    .onChange(of: messages.last?.id) { _, newValue in
                        guard let newValue else { return }
                        if isNearBottom {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(newValue, anchor: .bottom)
                            }
                            pendingNewMessages = 0
                        } else {
                            pendingNewMessages += 1
                        }
                    }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if !isNearBottom {
                            Button {
                                guard let lastID = messages.last?.id else { return }
                                withAnimation(.easeOut(duration: 0.22)) {
                                    proxy.scrollTo(lastID, anchor: .bottom)
                                }
                                isNearBottom = true
                                pendingNewMessages = 0
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "arrow.down")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 32, height: 32)
                                        .background(
                                            LinearGradient(colors: [CXColor.accent, CXColor.accentStrong], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        )
                                        .clipShape(Circle())
                                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 1)

                                    if pendingNewMessages > 0 {
                                        Text("\(pendingNewMessages)")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 4)
                                            .frame(minWidth: 14, minHeight: 14)
                                            .background(Color.red)
                                            .clipShape(Capsule())
                                            .offset(x: 4, y: -4)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 12)
                            .padding(.bottom, 12)
                            .transition(.opacity)
                        }
                    }
                }

                if isDropTargeted {
                    RoundedRectangle(cornerRadius: CXSize.rXl, style: .continuous)
                        .stroke(CXColor.accent, style: StrokeStyle(lineWidth: 2, dash: [8]))
                        .background(CXColor.accentBg.opacity(0.2))
                        .padding(CXSize.s4)
                        .transition(.opacity)
                }
            }

            Divider().overlay(CXColor.border)

            CXComposerView(chatID: chatID)
        }
        .background(CXColor.bg)
        .overlay {
            if let lightboxURL {
                CXLightboxView(url: lightboxURL) {
                    self.lightboxURL = nil
                }
                .transition(.opacity)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
        .onPasteCommand(of: [.image]) { providers in
            handlePaste(providers: providers)
        }
        .sheet(isPresented: $showForwardSheet, onDismiss: { vm.closeForward() }) {
            forwardSheet
        }
        .alert("Editar mensagem", isPresented: Binding(
            get: { editingMessage != nil },
            set: { if !$0 { editingMessage = nil } }
        )) {
            TextField("Texto", text: $editedText)
            Button("Cancelar", role: .cancel) {
                editingMessage = nil
            }
            Button("Salvar") {
                if let editingMessage {
                    Task { await vm.editMessage(chatID: chatID, message: editingMessage, newText: editedText) }
                }
                self.editingMessage = nil
            }
        } message: {
            Text("Atualize o conteúdo da mensagem")
        }
        .task(id: chatID) {
            await vm.loadMessages(for: chatID)
            if isGroupThread {
                await vm.loadGroupParticipantsForSelected()
            }
        }
    }

    private var forwardSheet: some View {
        VStack(alignment: .leading, spacing: CXSize.s3) {
            Text("Encaminhar mensagem")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(CXColor.text)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(vm.chats) { chat in
                        Button {
                            vm.selectedForwardTargetChatID = chat.id
                        } label: {
                            HStack(spacing: 8) {
                                CXAvatarView(title: chat.title, size: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(chat.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(CXColor.text)
                                    Text(chat.connectionID)
                                        .font(.system(size: 10))
                                        .foregroundStyle(CXColor.textMute)
                                }
                                Spacer()
                                if vm.selectedForwardTargetChatID == chat.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(CXColor.accent)
                                }
                            }
                            .padding(8)
                            .background(CXColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(vm.selectedForwardTargetChatID == chat.id ? CXColor.accent : CXColor.borderLight, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancelar") {
                    showForwardSheet = false
                    vm.closeForward()
                }
                Button("Encaminhar") {
                    Task { await vm.forwardMessage() }
                    showForwardSheet = false
                }
                .disabled(vm.selectedForwardTargetChatID == nil)
            }
        }
        .padding(CXSize.s4)
        .frame(minWidth: 420, minHeight: 420)
        .background(CXColor.surface2)
    }


    private func shouldShowDateSeparator(at index: Int) -> Bool {
        guard messages.indices.contains(index) else { return false }
        if index == 0 { return true }
        let previous = messages[index - 1].sentAt
        let current = messages[index].sentAt
        return !Calendar.current.isDate(previous, inSameDayAs: current)
    }

    private func formattedDayLabel(for date: Date) -> String {
        if date == .distantPast {
            return ""
        }
        if Calendar.current.isDateInToday(date) {
            return "Hoje"
        }
        if Calendar.current.isDateInYesterday(date) {
            return "Ontem"
        }
        return date.formatted(Date.FormatStyle().day(.twoDigits).month(.twoDigits).year())
    }

    private func dateSeparator(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(CXColor.textMute.opacity(0.9))
            .tracking(1.1)
            .textCase(.uppercase)
            .padding(.vertical, 10)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in
                    vm.attachFile(url: url)
                }
            }
        }
        return !providers.isEmpty
    }

    private func handlePaste(providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.png.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.png.identifier) { data, _ in
                    guard let data else { return }
                    Task { @MainActor in
                        vm.attachPastedImage(data: data)
                    }
                }
                return
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.tiff.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.tiff.identifier) { data, _ in
                    guard let data else { return }
                    Task { @MainActor in
                        vm.attachPastedImage(data: data)
                    }
                }
                return
            }
        }
    }


    private func hasGroupAvatarSlot(at index: Int) -> Bool {
        guard isGroupThread,
              messages.indices.contains(index) else { return false }
        let message = messages[index]
        return !message.fromMe && message.type != "note" && message.participantIdentityKey != nil
    }

    private func shouldShowGroupAvatar(at index: Int) -> Bool {
        guard hasGroupAvatarSlot(at: index) else { return false }
        if index == 0 { return true }
        let current = messages[index]
        let previous = messages[index - 1]
        guard !previous.fromMe, previous.type != "note" else { return true }
        return current.participantIdentityKey != previous.participantIdentityKey
    }

    private func groupAvatarURL(for index: Int) -> URL? {
        guard hasGroupAvatarSlot(at: index), shouldShowGroupAvatar(at: index), messages.indices.contains(index) else { return nil }
        let message = messages[index]
        return vm.resolvedAvatarURL(
            jid: message.participantAvatarJID,
            connectionID: message.connectionID ?? chatConnectionID
        )
    }

    private func isFirstOfGroup(at index: Int) -> Bool {
        guard messages.indices.contains(index) else { return true }
        if index == 0 { return true }
        let current = messages[index]
        let previous = messages[index - 1]
        if previous.fromMe != current.fromMe { return true }
        if (previous.type == "note") != (current.type == "note") { return true }
        if !current.fromMe, current.participantIdentityKey != previous.participantIdentityKey { return true }
        let gap = current.sentAt.timeIntervalSince(previous.sentAt)
        if gap > 90 { return true }
        return false
    }

    private func isMessageHighlighted(_ message: Message) -> Bool {
        guard let highlightedMessageID else { return false }
        return message.id == highlightedMessageID || message.keyID == highlightedMessageID
    }

    private func jumpToQuotedMessage(_ quotedID: String, proxy: ScrollViewProxy) {
        guard !quotedID.isEmpty else { return }
        guard let target = messages.first(where: { $0.id == quotedID || $0.keyID == quotedID }) else { return }
        withAnimation(.easeOut(duration: 0.24)) {
            proxy.scrollTo(target.id, anchor: .center)
        }
        highlightedMessageID = target.id
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if highlightedMessageID == target.id {
                withAnimation(.easeOut(duration: 0.2)) {
                    highlightedMessageID = nil
                }
            }
        }
    }

}

struct CXMessageBubbleView: View {
    let message: Message
    let mediaURL: URL?
    let groupAvatarURL: URL?
    let hasGroupAvatarSlot: Bool
    let showGroupAvatar: Bool
    let isFirstOfGroup: Bool
    let isHighlighted: Bool
    let quickReactions: [String]
    let onReply: () -> Void
    let onJumpToQuoted: (String) -> Void
    let onFetchMedia: () -> Void
    let onEdit: () -> Void
    let onDeleteForMe: () -> Void
    let onDeleteForEveryone: () -> Void
    let onReact: (String) -> Void
    let onForward: () -> Void
    let onRetry: () -> Void
    let onSaveSticker: () -> Void
    var onOpenLightbox: ((URL) -> Void)? = nil

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.fromMe { Spacer(minLength: 64) }

            if hasGroupAvatarSlot {
                Group {
                    if showGroupAvatar {
                        if let groupAvatarURL {
                            AuthedImage(
                                url: groupAvatarURL,
                                contentMode: .fill,
                                placeholder: {
                                    Text(initials(message.senderName))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(CXColor.text)
                                },
                                fallback: {
                                    Text(initials(message.senderName))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(CXColor.text)
                                }
                            )
                        } else {
                            Text(initials(message.senderName))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(CXColor.text)
                        }
                    }
                }
                .frame(width: 28, height: 28)
                .background(CXColor.surface2)
                .clipShape(Circle())
                .overlay(Circle().stroke(CXColor.border, lineWidth: 1))
                .opacity(showGroupAvatar ? 1 : 0)
            }

            VStack(alignment: .leading, spacing: 7) {
                if message.type == "note" {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(CXColor.warning)
                        Text(message.senderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Nota interna" : message.senderName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(CXColor.warning)
                    }
                } else if !message.fromMe, isFirstOfGroup, !message.senderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(message.senderName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.cxAvatar(for: message.senderName))
                }

                if let quotedText = message.quotedText, !quotedText.isEmpty {
                    Group {
                        if let quotedID = message.quotedMessageID, !quotedID.isEmpty {
                            Button {
                                onJumpToQuoted(quotedID)
                            } label: {
                                quotedBlock(quotedText: quotedText)
                            }
                            .buttonStyle(.plain)
                        } else {
                            quotedBlock(quotedText: quotedText)
                        }
                    }
                }

                if message.isDeleted {
                    Text("Mensagem apagada")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(CXColor.textMute)
                        .italic()
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    mediaContent
                    if !message.text.isEmpty {
                        Text(message.text)
                            .font(.system(size: 15))
                            .lineSpacing(3)
                            .foregroundStyle(message.fromMe ? CXColor.bubbleOutText : CXColor.bubbleInText)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !message.reactions.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(Set(message.reactions.map(\.emoji))), id: \.self) { emoji in
                            Text(emoji)
                                .font(.system(size: 11))
                                .padding(.horizontal, 6)
                                .frame(height: 20)
                                .background(CXColor.surface2)
                                .clipShape(Capsule())
                        }
                    }
                }

                if message.isForwarded || message.editedAt != nil {
                    HStack(spacing: 5) {
                        if message.isForwarded {
                            Text("⤳ Encaminhado")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle((message.fromMe ? CXColor.bubbleOutText : CXColor.textMute).opacity(0.72))
                        }
                        if message.editedAt != nil {
                            Text("editada")
                                .font(.system(size: 10, weight: .medium))
                                .italic()
                                .foregroundStyle((message.fromMe ? CXColor.bubbleOutText : CXColor.textMute).opacity(0.72))
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 18)
            .padding(.trailing, message.fromMe ? 58 : 46)
            .background(bubbleBackground)
            .clipShape(bubbleShape)
            .opacity(message.isDeleted ? 0.72 : (message.status == "pending" ? 0.92 : 1))
            .saturation(message.isDeleted ? 0.24 : 1)
            .overlay(bubbleShape.stroke(borderColor, lineWidth: 1))
            .overlay(bubbleShape.fill(CXColor.accent.opacity(isHighlighted ? 0.16 : 0)))
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 4) {
                    Text(message.sentAt == .distantPast ? "" : message.sentAt.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 10, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle((message.fromMe ? CXColor.bubbleOutText : CXColor.textMute).opacity(0.78))
                    if message.fromMe {
                        Image(systemName: statusSymbol)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(message.status == "read" ? CXColor.checkRead : CXColor.bubbleOutText.opacity(0.78))
                    }
                }
                .padding(.trailing, 12)
                .padding(.bottom, 6)
            }
            .frame(maxWidth: 520, alignment: message.fromMe ? .trailing : .leading)
            .shadow(color: bubbleShadowColor, radius: message.fromMe ? 20 : 6, x: 0, y: 4)
            .contextMenu {
                Button("Responder") { onReply() }
                if !message.isDeleted {
                    Button("Encaminhar") { onForward() }
                    if message.fromMe {
                        Button("Editar") { onEdit() }
                    }
                    if !message.text.isEmpty {
                        Button("Copiar") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.text, forType: .string)
                        }
                    }
                }
                Divider()
                Button("Apagar (pra mim)") { onDeleteForMe() }
                Button("Apagar (todos)") { onDeleteForEveryone() }
                if message.status == "failed" {
                    Button("Tentar novamente") { onRetry() }
                }
                if message.type == "sticker" {
                    Button("Salvar nos stickers") { onSaveSticker() }
                }
                if shouldOfferFetchMedia {
                    Button("Carregar mídia") { onFetchMedia() }
                }
                Divider()
                ForEach(quickReactions, id: \.self) { emoji in
                    Button("Reagir \(emoji)") { onReact(emoji) }
                }
            }

            if !message.fromMe { Spacer(minLength: 64) }
        }
        .frame(maxWidth: .infinity)
    }

    private var bubbleShadowColor: Color {
        if message.fromMe {
            return CXColor.accent.opacity(0.35)
        }
        return Color.black.opacity(0.08)
    }

    @ViewBuilder
    private var mediaContent: some View {
        switch message.type {
        case "image", "sticker":
            if let mediaURL {
                AuthedImage(
                    url: mediaURL,
                    contentMode: .fit,
                    placeholder: {
                        ProgressView()
                            .frame(width: 220, height: 120)
                    },
                    fallback: {
                        mediaFallback("Falha ao carregar mídia")
                    }
                )
                .frame(maxWidth: 260, maxHeight: 260)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onTapGesture {
                    if message.type == "image" {
                        onOpenLightbox?(mediaURL)
                    }
                }
            } else {
                mediaFallback("Imagem indisponível")
            }
        case "video", "gif":
            if let mediaURL {
                Link(destination: mediaURL) {
                    mediaFallback("Abrir vídeo")
                }
                .buttonStyle(.plain)
            } else {
                mediaFallback("Vídeo indisponível")
            }
        case "audio", "ptt":
            if let mediaURL {
                Link(destination: mediaURL) {
                    mediaFallback(audioLabel)
                }
                .buttonStyle(.plain)
            } else {
                mediaFallback("Áudio indisponível")
            }
        case "document":
            if let mediaURL {
                Link(destination: mediaURL) {
                    mediaFallback(message.fileName ?? "Abrir documento")
                }
                .buttonStyle(.plain)
            } else {
                mediaFallback(message.fileName ?? "Documento indisponível")
            }
        default:
            EmptyView()
        }
    }

    private var shouldOfferFetchMedia: Bool {
        ["image", "sticker", "video", "gif", "audio", "ptt", "document"].contains(message.type) && mediaURL == nil
    }

    private var audioLabel: String {
        if let duration = message.duration, duration > 0 {
            return "Áudio (\(duration)s)"
        }
        return "Abrir áudio"
    }

    private func mediaFallback(_ label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "paperclip")
                .font(.system(size: 11, weight: .bold))
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(message.fromMe ? CXColor.bubbleOutText : CXColor.textSoft)
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background((message.fromMe ? CXColor.bubbleOutText : CXColor.surface2).opacity(0.12))
        .clipShape(Capsule())
    }

    private var bubbleBackground: some View {
        Group {
            if message.fromMe {
                CXGradient.bubbleOut
            } else {
                if message.type == "note" {
                    CXColor.note.opacity(0.2)
                } else {
                    CXColor.bubbleIn
                }
            }
        }
    }

    private var bubbleShape: AnyShape {
        let rad = CXRadius.bubble
        let notch: CGFloat = 6
        let topLeft: CGFloat = (!message.fromMe && isFirstOfGroup) ? notch : rad
        let topRight: CGFloat = (message.fromMe && isFirstOfGroup) ? notch : rad
        return AnyShape(BubbleShape(topLeft: topLeft, topRight: topRight, bottomLeft: rad, bottomRight: rad))
    }

    private var borderColor: Color {
        if message.status == "failed" {
            return CXColor.danger
        }
        if message.type == "note" {
            return CXColor.note.opacity(0.5)
        }
        return message.fromMe ? CXColor.bubbleOutBorder : CXColor.bubbleInBorder
    }

    private var statusSymbol: String {
        switch message.status {
        case "read":
            return "checkmark.circle.fill"
        case "delivered":
            return "checkmark.circle"
        case "sent":
            return "checkmark"
        case "failed":
            return "exclamationmark.triangle.fill"
        default:
            return "clock"
        }
    }

    @ViewBuilder
    private func quotedBlock(quotedText: String) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(message.fromMe ? Color.white.opacity(0.6) : CXColor.accent)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 2) {
                if let quotedSender = message.quotedSender, !quotedSender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(quotedSender)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(message.fromMe ? CXColor.bubbleOutText.opacity(0.9) : CXColor.accent)
                }
                Text(quotedText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(message.fromMe ? CXColor.bubbleOutText.opacity(0.85) : CXColor.textSoft)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background((message.fromMe ? Color.white.opacity(0.12) : CXColor.accentBg))
        .clipShape(RoundedRectangle(cornerRadius: CXRadius.sm, style: .continuous))
    }

    private func initials(_ name: String) -> String {
        let parts = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .map(String.init)
        guard !parts.isEmpty else { return "?" }
        let first = parts[0].prefix(1)
        let second = parts.count > 1 ? parts[1].prefix(1) : ""
        return (first + second).uppercased()
    }
}

// MARK: - Bubble asymmetric corner shape

struct BubbleShape: Shape {
    let topLeft: CGFloat
    let topRight: CGFloat
    let bottomLeft: CGFloat
    let bottomRight: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let tl = min(topLeft, min(w, h) / 2)
        let tr = min(topRight, min(w, h) / 2)
        let bl = min(bottomLeft, min(w, h) / 2)
        let br = min(bottomRight, min(w, h) / 2)

        p.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
                 radius: tr,
                 startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        p.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
                 radius: br,
                 startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl),
                 radius: bl,
                 startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        p.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl),
                 radius: tl,
                 startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}

