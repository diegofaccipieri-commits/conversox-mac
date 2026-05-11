import SwiftUI

struct CXChatHeaderView: View {
    @EnvironmentObject private var vm: ChatsViewModel

    let chat: Chat

    @State private var showRenamePrompt = false
    @State private var renameDraft = ""
    @State private var showTransferPrompt = false
    @State private var transferTarget = ""
    @State private var showQuickReplies = false
    @State private var showScheduleSheet = false
    @State private var scheduleText = ""
    @State private var scheduleDate = Date()
    @State private var editingQuickReply: ChatsViewModel.QuickReplyDisplay?
    @State private var editingQRShortcut = ""
    @State private var editingQRBody = ""

    var body: some View {
        HStack(spacing: 14) {
            CXAvatarView(title: chat.title, size: 44, imageURL: resolvedAvatarURL, online: false, ring: CXColor.accent)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(chat.title)
                        .font(.system(size: 15, weight: .bold))
                        .tracking(-0.2)
                        .foregroundStyle(CXColor.text)
                        .lineLimit(1)

                    CXChannelBadge(connectionID: chat.connectionID, size: 12)

                    Button {
                        renameDraft = chat.title
                        showRenamePrompt = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(CXColor.textMute)
                    }
                    .buttonStyle(.plain)
                    .help("Renomear contato")

                    if chat.isLowPriority {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(CXColor.textMute)
                            .help("Baixa prioridade")
                    }
                }
                metaLine
            }

            Spacer()

            actions
        }
        .padding(.horizontal, 24)
        .frame(height: 72)
        .background(CXColor.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(CXColor.border).frame(height: 1)
        }
        .alert("Transferir conversa", isPresented: $showTransferPrompt) {
            TextField("Destino (agente/fila)", text: $transferTarget)
            Button("Cancelar", role: .cancel) {}
            Button("Transferir") {
                Task { await vm.transferSelectedChat(target: transferTarget) }
                transferTarget = ""
            }
        } message: {
            Text("Informe o destino da transferência.")
        }
        .alert("Renomear contato", isPresented: $showRenamePrompt) {
            TextField("Novo nome", text: $renameDraft)
            Button("Cancelar", role: .cancel) {}
            Button("Salvar") {
                let next = renameDraft
                Task { await vm.renameSelectedContact(to: next) }
                renameDraft = ""
            }
        } message: {
            Text("Define um nome de exibição para esse contato.")
        }
        .popover(isPresented: $showQuickReplies, arrowEdge: .top) {
            quickRepliesPopover
        }
        .sheet(item: $editingQuickReply) { reply in
            editQuickReplySheet(reply)
        }
        .sheet(isPresented: $showScheduleSheet) {
            scheduleMessageSheet
        }
    }

    private var metaLine: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Circle()
                    .fill(CXColor.success)
                    .frame(width: 6, height: 6)
                Text("online")
                    .font(.system(size: 11.5))
                    .foregroundStyle(CXColor.success)
            }
            Text("·")
                .font(.system(size: 11.5))
                .foregroundStyle(CXColor.textMute)
            Text(companyLabel)
                .font(.system(size: 11.5))
                .foregroundStyle(CXColor.textSoft)
            if chat.isGroup {
                Text("· grupo")
                    .font(.system(size: 11.5))
                    .foregroundStyle(CXColor.textMute)
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 6) {
            Button {
                showQuickReplies = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Resumir IA")
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .foregroundStyle(CXColor.accent)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(CXColor.accentBg)
                .clipShape(RoundedRectangle(cornerRadius: CXRadius.md, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Quick replies / resumir conversa")

            CXIconButton(systemName: "link") { vm.copySelectedChatLink() }
                .help("Copiar link da conversa")

            if chat.isGroup {
                CXIconButton(systemName: "person.3.fill") {
                    Task { await vm.fetchSelectedGroupInvite() }
                }
                .help("Copiar link do grupo")
            }

            CXIconButton(systemName: "point.3.connected.trianglepath.dotted") {
                showTransferPrompt = true
            }
            .help("Transferir conversa")

            CXIconButton(
                systemName: chat.isLowPriority ? "arrow.up.circle" : "arrow.down.circle",
                isOn: chat.isLowPriority
            ) {
                Task { await vm.toggleSelectedChatLowPriority() }
            }
            .help(chat.isLowPriority ? "Tirar baixa prioridade" : "Marcar baixa prioridade")

            CXIconButton(systemName: "calendar") {
                scheduleText = vm.draftMessage
                scheduleDate = Date().addingTimeInterval(3600)
                showScheduleSheet = true
            }
            .help("Agendar mensagem")

            CXIconButton(
                systemName: vm.isInternalNotesMode ? "note.text" : "note.text.badge.plus",
                isOn: vm.isInternalNotesMode
            ) {
                vm.toggleInternalNotesMode()
            }
            .help("Notas internas")

            CXIconButton(systemName: "checkmark") {
                Task { await vm.markSelectedChatAsRead() }
            }
            .help("Marcar como lida")

            CXIconButton(systemName: "ellipsis") {}
                .help("Mais opções")
        }
    }

    private var resolvedAvatarURL: URL? {
        if let raw = chat.avatarPath?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            if let absolute = URL(string: raw), absolute.scheme != nil {
                return absolute
            }
            guard var components = URLComponents(url: AppConfig.shared.serverBaseURL, resolvingAgainstBaseURL: false) else {
                return nil
            }
            components.path = raw.hasPrefix("/") ? raw : "/\(raw)"
            return components.url
        }
        return vm.resolvedAvatarURL(jid: chat.jid, connectionID: chat.connectionID)
    }

    private var companyLabel: String {
        if let badge = chat.badge?.trimmingCharacters(in: .whitespacesAndNewlines), !badge.isEmpty {
            return badge.capitalized
        }
        let source = chat.connectionID
            .replacingOccurrences(of: "evolution:", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        return source.capitalized
    }

    // MARK: - Sheets / popovers (mantidos)

    private var scheduleMessageSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Agendar mensagem")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(CXColor.text)

            TextField("Mensagem", text: $scheduleText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...8)

            DatePicker("Quando enviar", selection: $scheduleDate, in: Date()...)
                .datePickerStyle(.compact)

            HStack {
                Button("Cancelar") { showScheduleSheet = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Agendar") {
                    let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
                    let tf = DateFormatter(); tf.dateFormat = "HH:mm"
                    let dateStr = df.string(from: scheduleDate)
                    let timeStr = tf.string(from: scheduleDate)
                    let tz = TimeZone.current.identifier
                    let text = scheduleText
                    Task {
                        await vm.scheduleSelectedMessage(text: text, date: dateStr, time: timeStr, timezone: tz)
                    }
                    showScheduleSheet = false
                    scheduleText = ""
                }
                .keyboardShortcut(.defaultAction)
                .disabled(scheduleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private var quickRepliesPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Replies")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(CXColor.text)
            HStack(spacing: 8) {
                TextField("Nova: /shortcut texto", text: $vm.quickReplyDraft)
                    .textFieldStyle(.roundedBorder)
                Button("Adicionar") {
                    Task { await vm.addQuickReply() }
                }
            }
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(vm.quickReplyDisplays) { reply in
                        HStack(spacing: 8) {
                            Button {
                                showQuickReplies = false
                                Task { await vm.sendQuickReply(reply.body) }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    if let shortcut = reply.shortcut, !shortcut.isEmpty {
                                        Text(shortcut)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(CXColor.accent)
                                    }
                                    Text(reply.body)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(CXColor.textSoft)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)

                            if vm.quickReplyIDByBody(reply.body) != nil {
                                Button {
                                    editingQuickReply = reply
                                    editingQRShortcut = reply.shortcut ?? ""
                                    editingQRBody = reply.body
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(CXColor.textMute)
                                }
                                .buttonStyle(.plain)
                            }
                            Button(role: .destructive) {
                                Task { await vm.removeQuickReply(reply.body) }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 6)
                        .background(CXColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .frame(maxHeight: 320)
        }
        .padding(16)
        .frame(width: 360)
        .background(CXColor.surface2)
    }

    private func editQuickReplySheet(_ reply: ChatsViewModel.QuickReplyDisplay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Editar quick reply")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(CXColor.text)
            VStack(alignment: .leading, spacing: 4) {
                Text("Shortcut (sem barra)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(CXColor.textMute)
                TextField("oi", text: $editingQRShortcut)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Texto")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(CXColor.textMute)
                TextEditor(text: $editingQRBody)
                    .font(.system(size: 13))
                    .frame(minHeight: 100)
                    .padding(4)
                    .background(CXColor.input)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(CXColor.inputBorder, lineWidth: 1))
            }
            HStack {
                Spacer()
                Button("Cancelar") { editingQuickReply = nil }
                Button("Salvar") {
                    let id = reply.id
                    let s = editingQRShortcut
                    let b = editingQRBody
                    Task { await vm.updateQuickReplyEntry(id: id, shortcut: s, body: b) }
                    editingQuickReply = nil
                }
                .keyboardShortcut(.defaultAction)
                .disabled(editingQRShortcut.trimmingCharacters(in: .whitespaces).isEmpty || editingQRBody.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 460)
        .background(CXColor.surface2)
    }
}
