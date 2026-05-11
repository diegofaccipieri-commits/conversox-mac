import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

struct CXComposerView: View {
    @EnvironmentObject private var vm: ChatsViewModel

    let chatID: String

    @State private var showFileImporter = false
    @State private var showEmojiPicker = false
    @State private var showStickerPicker = false
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingURL: URL?
    @State private var mentionQuery: String?

    private let quickEmojis = ["😀", "😄", "😂", "😍", "🙏", "👍", "🎉", "🤝", "✅", "📌", "🫶", "🔥"]

    private var operatorName: String { vm.operatorDisplayName }
    private var notes: [ChatNote] { vm.notesByChat[chatID] ?? [] }
    private var quickReplyChips: [String] { Array(vm.quickReplyShortcutChips.prefix(8)) }

    private var isGroupThread: Bool { vm.chats.first(where: { $0.id == chatID })?.isGroup ?? false }
    private var chatJIDForMentions: String? { vm.chats.first(where: { $0.id == chatID })?.jid }
    private var mentionSuggestions: [GroupParticipant] {
        guard isGroupThread, let jid = chatJIDForMentions, let q = mentionQuery else { return [] }
        return vm.mentionSuggestions(for: jid, query: q)
    }

    private var sendDisabled: Bool {
        let textEmpty = vm.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return vm.isSendingMessage || (textEmpty && vm.composerAttachments.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            quickRepliesStrip
            notesStrip
            replyPreview
            attachmentsPreview
            mentionSuggestionsList

            HStack(alignment: .bottom, spacing: 8) {
                composerCard
                sendButton
            }

            if showEmojiPicker { emojiPicker }
            if showStickerPicker { stickerPicker }
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .background(CXColor.bg)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image, .movie, .audio, .pdf, .plainText, .content],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls { vm.attachFile(url: url) }
            case .failure:
                vm.errorMessage = "Falha ao selecionar arquivos."
            }
        }
    }

    // MARK: - Composer card

    private var composerCard: some View {
        HStack(alignment: .bottom, spacing: 4) {
            composerIcon(systemName: "paperclip", help: "Anexar arquivo") {
                showFileImporter = true
            }
            composerIcon(
                systemName: "bolt.fill",
                tint: vm.isInternalNotesMode ? CXColor.warning : nil,
                help: vm.isInternalNotesMode ? "Modo nota interna ON" : "Modo nota interna"
            ) { vm.toggleInternalNotesMode() }

            TextField("Mensagem para \(chatTitle)...", text: $vm.draftMessage, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13.5))
                .foregroundStyle(CXColor.text)
                .lineLimit(1...6)
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
                .onSubmit { Task { await vm.sendMessage() } }
                .onChange(of: vm.draftMessage) { _, _ in updateMentionQuery() }

            composerIcon(systemName: "face.smiling", help: "Emoji") {
                showEmojiPicker.toggle()
                showStickerPicker = false
            }
            composerIcon(systemName: "square.grid.2x2", help: "Stickers") {
                showStickerPicker.toggle()
                showEmojiPicker = false
                Task { await vm.loadStickerPacks() }
            }
            composerIcon(
                systemName: isRecording ? "stop.circle.fill" : "mic.fill",
                tint: isRecording ? CXColor.danger : nil,
                help: isRecording ? "Parar gravação" : "Gravar áudio"
            ) { toggleRecording() }
        }
        .padding(.leading, 6)
        .padding(.trailing, 6)
        .padding(.vertical, 4)
        .background(CXColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CXRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CXRadius.xl, style: .continuous)
                .stroke(vm.isInternalNotesMode ? CXColor.warning : CXColor.border, lineWidth: 1)
        )
    }

    private var sendButton: some View {
        Button {
            Task { await vm.sendMessage() }
        } label: {
            ZStack {
                Circle()
                    .fill(sendDisabled ? AnyShapeStyle(CXColor.surface2) : AnyShapeStyle(CXGradient.bubbleOut))
                if vm.isSendingMessage {
                    ProgressView().controlSize(.small).tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(sendDisabled ? CXColor.textMute : .white)
                }
            }
            .frame(width: 38, height: 38)
            .shadow(color: sendDisabled ? .clear : CXColor.accent.opacity(0.45), radius: 14, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(sendDisabled)
        .help("Enviar")
    }

    private func composerIcon(
        systemName: String,
        tint: Color? = nil,
        help: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint ?? CXColor.textMute)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .help(help ?? "")
    }

    private var chatTitle: String {
        vm.chats.first(where: { $0.id == chatID })?.title ?? ""
    }

    // MARK: - Quick replies strip

    @ViewBuilder
    private var quickRepliesStrip: some View {
        if !quickReplyChips.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(quickReplyChips, id: \.self) { shortcut in
                        Button(shortcut) {
                            Task { await vm.sendQuickReplyShortcut(shortcut) }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CXColor.text)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 28)
                        .background(CXColor.surface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(CXColor.border, lineWidth: 1))
                    }
                }
            }
        }
    }

    // MARK: - Reply preview

    @ViewBuilder
    private var replyPreview: some View {
        if let reply = vm.replyTarget {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(CXColor.accent)
                    .frame(width: 3)
                    .clipShape(Capsule())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Respondendo")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(CXColor.accent)
                    Text(reply.text.isEmpty ? mediaPlaceholder(type: reply.type) : reply.text)
                        .font(.system(size: 11.5))
                        .foregroundStyle(CXColor.textSoft)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    vm.clearReplyTarget()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(CXColor.textMute)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(CXColor.surface2)
            .clipShape(RoundedRectangle(cornerRadius: CXRadius.md, style: .continuous))
        }
    }

    // MARK: - Attachments preview

    @ViewBuilder
    private var attachmentsPreview: some View {
        if !vm.composerAttachments.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(vm.composerAttachments) { attachment in
                        HStack(spacing: 6) {
                            Image(systemName: "paperclip")
                                .font(.system(size: 10, weight: .bold))
                            Text(attachment.fileName)
                                .font(.system(size: 11, weight: .medium))
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
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(CXColor.surface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(CXColor.border, lineWidth: 1))
                    }
                }
            }
        }
    }

    // MARK: - Mention list

    @ViewBuilder
    private var mentionSuggestionsList: some View {
        if !mentionSuggestions.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(mentionSuggestions, id: \.jid) { p in
                    Button {
                        insertMention(p)
                    } label: {
                        HStack(spacing: 8) {
                            CXAvatarView(title: p.name ?? p.phone ?? p.jid, size: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(p.name ?? p.phone ?? p.jid)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(CXColor.text)
                                if let phone = p.phone, p.name != nil {
                                    Text(phone)
                                        .font(.system(size: 10))
                                        .foregroundStyle(CXColor.textMute)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CXColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: CXRadius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CXRadius.md, style: .continuous).stroke(CXColor.border, lineWidth: 1))
        }
    }

    // MARK: - Notes strip

    @ViewBuilder
    private var notesStrip: some View {
        if !notes.isEmpty || vm.isInternalNotesMode {
            VStack(alignment: .leading, spacing: 6) {
                if !notes.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(notes) { note in
                                HStack(spacing: 6) {
                                    Text(note.text)
                                        .font(.system(size: 11))
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
                                .background(CXColor.noteCardBg)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(CXColor.noteCardBorder, lineWidth: 1))
                            }
                        }
                    }
                }
                if vm.isInternalNotesMode {
                    HStack(spacing: 8) {
                        TextField("Nova nota interna...", text: $vm.noteDraft)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                            .padding(.horizontal, 8)
                            .frame(height: 28)
                            .background(CXColor.noteCardBg)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(CXColor.noteCardBorder, lineWidth: 1)
                            )
                        Button("Salvar") {
                            Task { await vm.addNote(for: chatID) }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CXColor.note)
                    }
                }
            }
        }
    }

    // MARK: - Emoji + sticker pickers

    private var emojiPicker: some View {
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
        .clipShape(RoundedRectangle(cornerRadius: CXRadius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CXRadius.md, style: .continuous).stroke(CXColor.border, lineWidth: 1))
    }

    private var stickerPicker: some View {
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
                        .background(vm.selectedStickerPackID == packID ? CXColor.accentBg : CXColor.surface2)
                        .foregroundStyle(vm.selectedStickerPackID == packID ? CXColor.accent : CXColor.textSoft)
                        .clipShape(Capsule())
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
                    .background(CXColor.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .padding(8)
        .background(CXColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CXRadius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CXRadius.md, style: .continuous).stroke(CXColor.border, lineWidth: 1))
    }

    // MARK: - Helpers

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

    private func updateMentionQuery() {
        guard isGroupThread else { mentionQuery = nil; return }
        let text = vm.draftMessage
        guard let atIdx = text.lastIndex(of: "@") else { mentionQuery = nil; return }
        let after = text[text.index(after: atIdx)...]
        if after.contains(where: { $0 == " " || $0 == "\n" }) { mentionQuery = nil; return }
        if atIdx > text.startIndex {
            let prev = text[text.index(before: atIdx)]
            if prev.isLetter || prev.isNumber { mentionQuery = nil; return }
        }
        mentionQuery = String(after)
    }

    private func insertMention(_ participant: GroupParticipant) {
        var text = vm.draftMessage
        guard let atIdx = text.lastIndex(of: "@") else { return }
        text.removeSubrange(atIdx..<text.endIndex)
        let handle = participant.phone ?? participant.jid.split(separator: "@").first.map(String.init) ?? participant.jid
        text.append("@\(handle) ")
        vm.draftMessage = text
        mentionQuery = nil
    }

    private func toggleRecording() {
        if isRecording {
            audioRecorder?.stop()
            isRecording = false
            if let url = recordingURL { vm.attachFile(url: url) }
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
