import SwiftUI
import UniformTypeIdentifiers

struct MessageThreadView: View {
    @EnvironmentObject private var vm: ChatsViewModel

    let chatID: String

    @State private var showFileImporter = false
    @State private var isDropTargeted = false

    private var messages: [Message] {
        vm.messagesByChat[chatID] ?? []
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
                                    onReply: { vm.setReplyTarget(message) },
                                    onFetchMedia: {
                                        Task { await vm.fetchMedia(for: chatID, message: message) }
                                    }
                                )
                                .id(message.id)
                            }
                        }
                        .padding(CXSize.s4)
                        .padding(.top, CXSize.s2)
                    }
                    .onChange(of: messages.last?.id) { _, newValue in
                        guard let newValue else { return }
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(newValue, anchor: .bottom)
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
        .task(id: chatID) {
            await vm.loadMessages(for: chatID)
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: CXSize.s2) {
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
        }
        .padding(CXSize.s3)
        .background(CXColor.composer)
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
}

struct CXMessageBubbleView: View {
    let message: Message
    let mediaURL: URL?
    let onReply: () -> Void
    let onFetchMedia: () -> Void

    var body: some View {
        HStack {
            if message.fromMe { Spacer(minLength: 80) }

            VStack(alignment: .leading, spacing: 6) {
                if !message.fromMe {
                    Text(message.senderName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(CXColor.accent)
                }

                if let quotedText = message.quotedText, !quotedText.isEmpty {
                    Text(quotedText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(CXColor.textSoft)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(CXColor.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

                HStack(spacing: 5) {
                    if message.isForwarded {
                        Text("Encaminhada")
                            .font(.system(size: 10, weight: .medium))
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
            .overlay(
                RoundedRectangle(cornerRadius: CXSize.rLg, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.22), radius: 2, x: 0, y: 1)
            .contextMenu {
                Button("Responder") { onReply() }
                if !message.text.isEmpty {
                    Button("Copiar") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(message.text, forType: .string)
                    }
                }
                if shouldOfferFetchMedia {
                    Button("Carregar mídia") { onFetchMedia() }
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
                CXColor.bubbleIn
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
}
