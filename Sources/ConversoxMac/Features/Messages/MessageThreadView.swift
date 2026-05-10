import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

struct MessageThreadView: View {
    @EnvironmentObject private var vm: ChatsViewModel

    let chatID: String

    @State private var showFileImporter = false
    @State private var isDropTargeted = false
    @State private var showForwardSheet = false
    @State private var editingMessage: Message?
    @State private var editedText = ""
    @State private var showEmojiPicker = false
    @State private var showStickerPicker = false
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingURL: URL?
    @State private var isNearBottom = true
    @State private var pendingNewMessages = 0
    @State private var highlightedMessageID: String?

    private let quickReactions = ["👍", "❤️", "😂", "😮", "😢", "🙏"]
    private let quickEmojis = ["😀", "😄", "😂", "😍", "🙏", "👍", "🎉", "🤝", "✅", "📌", "🫶", "🔥"]

    private var messages: [Message] {
        vm.messagesByChat[chatID] ?? []
    }

    private var notes: [ChatNote] {
        vm.notesByChat[chatID] ?? []
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
                CXColor.bg
                RadialGradient(colors: [CXColor.accentBg.opacity(0.42), .clear], center: .topLeading, startRadius: 80, endRadius: 520)
                RadialGradient(colors: [CXColor.waGreen.opacity(0.12), .clear], center: .topTrailing, startRadius: 80, endRadius: 520)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: CXSize.s2) {
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
                        .padding(CXSize.s4)
                        .padding(.top, CXSize.s2)
                    }
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

                    if !isNearBottom {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Button {
                                    guard let lastID = messages.last?.id else { return }
                                    withAnimation(.easeOut(duration: 0.22)) {
                                        proxy.scrollTo(lastID, anchor: .bottom)
                                    }
                                    isNearBottom = true
                                    pendingNewMessages = 0
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.down")
                                            .font(.system(size: 11, weight: .bold))
                                        if pendingNewMessages > 0 {
                                            Text("\(pendingNewMessages)")
                                                .font(.system(size: 10, weight: .bold))
                                        }
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .frame(height: 28)
                                    .background(
                                        LinearGradient(colors: [CXColor.accent, CXColor.accentStrong], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .clipShape(Capsule())
                                    .shadow(color: CXColor.accent.opacity(0.35), radius: 8, x: 0, y: 2)
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, CXSize.s4)
                                .padding(.bottom, CXSize.s4)
                            }
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

            composer
        }
        .background(CXColor.bg)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image, .movie, .audio, .pdf, .plainText, .content],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    vm.attachFile(url: url)
                }
            case .failure:
                vm.errorMessage = "Falha ao selecionar arquivos."
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

    private var composer: some View {
        VStack(alignment: .leading, spacing: CXSize.s2) {
            notesPanel

            if let reply = vm.replyTarget {
                HStack(spacing: CXSize.s2) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Respondendo")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(CXColor.accent)
                        Text(reply.text.isEmpty ? mediaPlaceholder(type: reply.type) : reply.text)
                            .font(.system(size: 11))
                            .foregroundStyle(CXColor.textSoft)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        vm.clearReplyTarget()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(CXColor.textMute)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, CXSize.s3)
                .padding(.vertical, 8)
                .background(CXColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: CXSize.rMd, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CXSize.rMd, style: .continuous)
                        .stroke(CXColor.borderLight, lineWidth: 1)
                )
            }

            if !vm.composerAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CXSize.s2) {
                        ForEach(vm.composerAttachments) { attachment in
                            HStack(spacing: 6) {
                                Image(systemName: "paperclip")
                                    .font(.system(size: 10, weight: .bold))
                                Text(attachment.fileName)
                                    .font(.system(size: 10, weight: .medium))
                                    .lineLimit(1)
                                Button {
                                    vm.removeAttachment(attachment)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .buttonStyle(.plain)
                            }
                            .foregroundStyle(CXColor.textSoft)
                            .padding(.horizontal, 8)
                            .frame(height: 24)
                            .background(CXColor.surface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(CXColor.borderLight, lineWidth: 1))
                        }
                    }
                }
            }

            HStack(alignment: .bottom, spacing: CXSize.s2) {
                CXIconButton(systemName: "paperclip") {
                    showFileImporter = true
                }
                CXIconButton(systemName: vm.isInternalNotesMode ? "note.text" : "note.text.badge.plus") {
                    vm.toggleInternalNotesMode()
                }
                CXIconButton(systemName: "face.smiling") {
                    showEmojiPicker.toggle()
                    showStickerPicker = false
                }
                CXIconButton(systemName: "square.grid.2x2") {
                    showStickerPicker.toggle()
                    showEmojiPicker = false
                    Task { await vm.loadStickerPacks() }
                }
                CXIconButton(systemName: isRecording ? "stop.circle.fill" : "mic.fill") {
                    toggleRecording()
                }

                TextField("Digite uma mensagem", text: $vm.draftMessage, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(CXColor.text)
                    .lineLimit(1...6)
                    .padding(.horizontal, CXSize.s3)
                    .padding(.vertical, 9)
                    .background(CXColor.input)
                    .clipShape(RoundedRectangle(cornerRadius: CXSize.rLg, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CXSize.rLg, style: .continuous)
                            .stroke(vm.isInternalNotesMode ? CXColor.warning : CXColor.borderLight, lineWidth: 1)
                    )
                    .onSubmit {
                        Task { await vm.sendMessage() }
                    }

                Button {
                    Task { await vm.sendMessage() }
                } label: {
                    if vm.isSendingMessage {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                            .frame(width: 38, height: 38)
                            .background(
                                LinearGradient(colors: [CXColor.accent, CXColor.accentStrong], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(
                                LinearGradient(colors: [CXColor.accent, CXColor.accentStrong], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: CXColor.accent.opacity(0.35), radius: 10, x: 0, y: 4)
                    }
                }
                .buttonStyle(.plain)
                .disabled(sendDisabled)
            }

            if showEmojiPicker {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(quickEmojis, id: \.self) { emoji in
                            Button(emoji) {
                                vm.draftMessage += emoji
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 20))
                        }
                    }
                }
                .padding(8)
                .background(CXColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(CXColor.borderLight, lineWidth: 1))
            }

            if showStickerPicker {
                VStack(alignment: .leading, spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(vm.stickerPackIDs, id: \.self) { packID in
                                Button(packID) {
                                    Task { await vm.loadStickers(packID: packID) }
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 8)
                                .frame(height: 22)
                                .background(vm.selectedStickerPackID == packID ? CXColor.accentBg : CXColor.surface)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(vm.selectedStickerPackID == packID ? CXColor.accent : CXColor.borderLight, lineWidth: 1))
                            }
                        }
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 48)), count: 6), spacing: 8) {
                        ForEach(vm.stickerIDs, id: \.self) { stickerID in
                            Button("🙂") {
                                Task { await vm.sendSticker(stickerID: stickerID) }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 20))
                            .frame(height: 40)
                            .frame(maxWidth: .infinity)
                            .background(CXColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }
                .padding(8)
                .background(CXColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(CXColor.borderLight, lineWidth: 1))
            }
        }
        .padding(CXSize.s3)
        .background(CXColor.composer)
    }

    private var notesPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !notes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(notes) { note in
                            HStack(spacing: 6) {
                                Text(note.text)
                                    .font(.system(size: 10, weight: .medium))
                                    .lineLimit(1)
                                if let author = note.author {
                                    Text(author)
                                        .font(.system(size: 9))
                                        .foregroundStyle(CXColor.textMute)
                                }
                                Button {
                                    Task { await vm.removeNote(noteID: note.id, chatID: chatID) }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .frame(height: 24)
                            .background(CXColor.note.opacity(0.2))
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Adicionar nota interna", text: $vm.noteDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .background(CXColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Button("Salvar") {
                    Task { await vm.addNote(for: chatID) }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(CXColor.warning)
            }
        }
    }

    private var sendDisabled: Bool {
        let textEmpty = vm.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return vm.isSendingMessage || (textEmpty && vm.composerAttachments.isEmpty)
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
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(CXColor.textMute)
            .padding(.horizontal, CXSize.s3)
            .frame(height: 24)
            .background(CXColor.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(CXColor.borderLight, lineWidth: 1))
            .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
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

    private func mediaPlaceholder(type: String) -> String {
        switch type {
        case "image": return "[imagem]"
        case "audio", "ptt": return "[audio]"
        case "video", "gif": return "[video]"
        case "document": return "[documento]"
        case "sticker": return "[sticker]"
        default: return "[mensagem]"
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

    private func toggleRecording() {
        if isRecording {
            audioRecorder?.stop()
            isRecording = false
            if let url = recordingURL {
                vm.attachFile(url: url)
            }
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cx-ptt-\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: tempURL, settings: settings)
            audioRecorder?.record()
            recordingURL = tempURL
            isRecording = true
        } catch {
            vm.errorMessage = "Falha ao iniciar gravação de áudio."
        }
    }
}

struct CXMessageBubbleView: View {
    let message: Message
    let mediaURL: URL?
    let groupAvatarURL: URL?
    let hasGroupAvatarSlot: Bool
    let showGroupAvatar: Bool
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

    var body: some View {
        HStack {
            if message.fromMe { Spacer(minLength: 80) }

            if hasGroupAvatarSlot {
                Group {
                    if showGroupAvatar {
                        if let groupAvatarURL {
                            AsyncImage(url: groupAvatarURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                default:
                                    Text(initials(message.senderName))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(CXColor.text)
                                }
                            }
                        } else {
                            Text(initials(message.senderName))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(CXColor.text)
                        }
                    }
                }
                .frame(width: 24, height: 24)
                .background(CXColor.surface2)
                .clipShape(Circle())
                .overlay(Circle().stroke(CXColor.border, lineWidth: 1))
                .opacity(showGroupAvatar ? 1 : 0)
            }

            VStack(alignment: .leading, spacing: 6) {
                if message.type == "note" {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(CXColor.warning)
                        Text(message.senderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Nota interna" : message.senderName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(CXColor.warning)
                    }
                } else if !message.fromMe, !message.senderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(message.senderName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(CXColor.accent)
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
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CXColor.textMute)
                        .italic()
                } else {
                    mediaContent
                    if !message.text.isEmpty {
                        Text(message.text)
                            .font(.system(size: 14))
                            .lineSpacing(2)
                            .foregroundStyle(message.fromMe ? CXColor.bubbleOutText : CXColor.bubbleInText)
                            .textSelection(.enabled)
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
                    Spacer(minLength: 4)
                    Text(message.sentAt == .distantPast ? "" : message.sentAt.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle((message.fromMe ? CXColor.bubbleOutText : CXColor.textMute).opacity(0.72))
                    if message.fromMe {
                        Image(systemName: statusSymbol)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(message.status == "read" ? CXColor.checkRead : CXColor.textMute)
                    }
                }
            }
            .padding(.horizontal, CXSize.s3)
            .padding(.vertical, CXSize.s2)
            .frame(maxWidth: 720, alignment: .leading)
            .background(bubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: CXSize.rLg, style: .continuous))
            .opacity(message.isDeleted ? 0.72 : (message.status == "pending" ? 0.92 : 1))
            .saturation(message.isDeleted ? 0.24 : 1)
            .overlay(
                RoundedRectangle(cornerRadius: CXSize.rLg, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CXSize.rLg, style: .continuous)
                    .fill(CXColor.accent.opacity(isHighlighted ? 0.16 : 0))
            )
            .shadow(color: .black.opacity(0.22), radius: 2, x: 0, y: 1)
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

            if !message.fromMe { Spacer(minLength: 80) }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var mediaContent: some View {
        switch message.type {
        case "image", "sticker":
            if let mediaURL {
                AsyncImage(url: mediaURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 260, maxHeight: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    case .failure(_):
                        mediaFallback("Falha ao carregar imagem")
                    case .empty:
                        ProgressView()
                            .frame(width: 220, height: 120)
                    @unknown default:
                        mediaFallback("Mídia indisponível")
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
        .frame(height: 30)
        .background((message.fromMe ? CXColor.bubbleOutText : CXColor.surface2).opacity(0.12))
        .clipShape(Capsule())
    }

    private var bubbleBackground: some View {
        Group {
            if message.fromMe {
                LinearGradient(colors: [CXColor.bubbleOutStart, CXColor.bubbleOutEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                if message.type == "note" {
                    CXColor.note.opacity(0.2)
                } else {
                    CXColor.bubbleIn
                }
            }
        }
    }

    private var borderColor: Color {
        if message.status == "failed" {
            return CXColor.danger
        }
        return message.fromMe ? CXColor.accent.opacity(0.35) : CXColor.border
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
            return "exclamationmark.circle.fill"
        default:
            return "clock"
        }
    }

    @ViewBuilder
    private func quotedBlock(quotedText: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if let quotedSender = message.quotedSender, !quotedSender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(quotedSender)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(CXColor.textMute)
            }
            Text(quotedText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(CXColor.textSoft)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(CXColor.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
