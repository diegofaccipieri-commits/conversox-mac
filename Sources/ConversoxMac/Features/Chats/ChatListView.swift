import SwiftUI

struct ChatListView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var vm: ChatsViewModel
    @State private var showTransferPrompt = false
    @State private var showQuickReplies = false
    @State private var transferTarget = ""

    var body: some View {
        ZStack {
            CXColor.bg.ignoresSafeArea()

            HStack(spacing: 0) {
                sidebar
                    .frame(minWidth: 360, idealWidth: 410, maxWidth: 450)
                    .cxShellPanel()

                mainPanel
                    .cxShellPanel()
            }
            .padding(0)
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                if let notice = sessionStore.sessionNotice {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.shield.fill")
                        Text(notice)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(CXColor.warning.opacity(0.95))
                    .clipShape(Capsule())
                }

                if let toast = vm.toast {
                    HStack(spacing: 8) {
                        Image(systemName: toast.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        Text(toast.message)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(toast.isError ? CXColor.danger.opacity(0.95) : CXColor.success.opacity(0.95))
                    .clipShape(Capsule())
                }
            }
            .padding(.top, 18)
        }
        .task {
            await vm.loadInitialChatsIfNeeded()
            await vm.startRealtime()
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            VStack(spacing: CXSize.s3) {
                HStack(spacing: CXSize.s2) {
                    Text(AppVersion.badgeLabel)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(CXColor.textSoft)
                        .padding(.horizontal, 0)
                        .frame(height: 28)
                        .clipShape(Capsule())

                    searchField

                    CXIconButton(systemName: "plus") {}
                    CXIconButton(systemName: "bell.slash") {}
                    CXIconButton(systemName: "sun.max.fill", isOn: true) {}
                }

                HStack(spacing: CXSize.s2) {
                    ForEach(ChatFilter.allCases) { filter in
                        filterButton(filter)
                    }
                }
            }
            .padding(.horizontal, CXSize.s4)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .background(CXColor.surface)

            Divider().overlay(CXColor.border)

            if vm.selectedSidebarTab == .contacts {
                HStack(spacing: CXSize.s2) {
                    ForEach([ChatChannel.td, .wa, .ig, .tg, .em, .sm], id: \.id) { channel in
                        channelPill(channel)
                    }
                }
                .padding(.horizontal, CXSize.s4)
                .padding(.vertical, CXSize.s3)
            }

            if vm.selectedSidebarTab == .chats {
                if vm.isBootstrapping && vm.visibleChats.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(0..<8, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 10)
                                .fill(CXColor.surface3)
                                .frame(height: 58)
                        }
                    }
                    .padding(CXSize.s3)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(vm.visibleChats) { chat in
                                Button {
                                    vm.selectedChatID = chat.id
                                    Task { await vm.loadMessages(for: chat.id) }
                                } label: {
                                    CXChatRowView(
                                        chat: chat,
                                        isActive: vm.selectedChatID == chat.id,
                                        avatarURL: resolvedChatAvatarURL(chat)
                                    )
                                }
                                .buttonStyle(.plain)
                                .onAppear {
                                    if chat.id == vm.visibleChats.last?.id {
                                        vm.loadMoreChats()
                                    }
                                }
                            }
                        }
                        .padding(8)
                    }
                    .background(CXColor.surface)
                }
            } else {
                contactsPanel
            }
        }
    }

    private var mainPanel: some View {
        Group {
            if let chatID = vm.selectedChatID, let chat = vm.chats.first(where: { $0.id == chatID }) {
                MessageThreadView(chatID: chatID)
                    .safeAreaInset(edge: .top, spacing: 0) {
                        chatHeader(chat)
                    }
            } else {
                VStack(spacing: CXSize.s3) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(CXColor.accent)
                    Text("Selecione uma conversa")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(CXColor.text)
                    Text("A lista de chats aparece a esquerda.")
                        .font(.system(size: 12))
                        .foregroundStyle(CXColor.textMute)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(CXColor.surface2)
            }
        }
    }

    private func chatHeader(_ chat: Chat) -> some View {
        HStack(spacing: CXSize.s3) {
            CXAvatarView(title: chat.title, size: 44, imageURL: resolvedChatAvatarURL(chat))
            VStack(alignment: .leading, spacing: 4) {
                Text(chat.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(CXColor.text)
                HStack(spacing: 6) {
                    Text(companyLabel(for: chat))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CXColor.textSoft)
                    Text(chat.isGroup ? "grupo" : "")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(CXColor.textMute)
                }
            }

            Spacer()

            CXIconButton(systemName: "link") {}
            CXIconButton(systemName: "point.3.connected.trianglepath.dotted") { showTransferPrompt = true }
            CXIconButton(systemName: "arrow.up.left.and.arrow.down.right") {}
            CXIconButton(systemName: "bell.badge") {}
            Button {
                showQuickReplies = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                    Text("Resumir IA")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(CXColor.accentBg.opacity(0.95))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(CXColor.accent.opacity(0.55), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            CXIconButton(systemName: "bubble.left.and.text.bubble.right") {}
            CXIconButton(systemName: "calendar") {}
            CXIconButton(systemName: vm.isInternalNotesMode ? "note.text" : "note.text.badge.plus") {
                vm.toggleInternalNotesMode()
            }
            CXIconButton(systemName: "checkmark") {
                Task { await vm.markSelectedChatAsRead() }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
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
        .popover(isPresented: $showQuickReplies, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: CXSize.s2) {
                Text("Quick Replies")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(CXColor.text)
                HStack(spacing: 8) {
                    TextField("Nova quick reply ou /shortcut", text: $vm.quickReplyDraft)
                        .textFieldStyle(.roundedBorder)
                    Button("Adicionar") {
                        Task { await vm.addQuickReply() }
                    }
                }
                ForEach(vm.quickReplies, id: \.self) { reply in
                    HStack(spacing: 8) {
                        Button(reply) {
                            showQuickReplies = false
                            Task { await vm.sendQuickReply(reply) }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CXColor.textSoft)
                        Spacer()
                        Button(role: .destructive) {
                            Task { await vm.removeQuickReply(reply) }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(CXSize.s4)
            .frame(width: 300)
            .background(CXColor.surface2)
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(CXColor.textMute)
            TextField("Buscar conversas...", text: vm.selectedSidebarTab == .contacts ? $vm.contactSearchText : $vm.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(CXColor.text)
            if !(vm.selectedSidebarTab == .contacts ? vm.contactSearchText : vm.searchText).isEmpty {
                Button {
                    if vm.selectedSidebarTab == .contacts {
                        vm.contactSearchText = ""
                    } else {
                        vm.searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(CXColor.textMute)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(CXColor.input)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(CXColor.borderLight, lineWidth: 1))
    }

    private func filterButton(_ filter: ChatFilter) -> some View {
        let isActive = vm.selectedFilter == filter
        return Button {
            vm.selectedFilter = filter
        } label: {
            HStack(spacing: 5) {
                Text(filter.title)
                    .lineLimit(1)
                if filter == .unread {
                    let total = vm.chats.reduce(0) { $0 + $1.unreadCount }
                    if total > 0 { CXUnreadBadge(count: total) }
                }
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(isActive ? CXColor.accent : CXColor.textMute)
            .frame(maxWidth: .infinity, minHeight: 30)
            .background(isActive ? CXColor.accentBg.opacity(0.72) : CXColor.surface2)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isActive ? CXColor.accent : CXColor.borderLight, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func companyLabel(for chat: Chat) -> String {
        if let badge = chat.badge?.trimmingCharacters(in: .whitespacesAndNewlines), !badge.isEmpty {
            return badge
        }
        let source = chat.connectionID
            .replacingOccurrences(of: "evolution:", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        return source.capitalized
    }

    private func resolvedChatAvatarURL(_ chat: Chat) -> URL? {
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

    private func sidebarTabButton(_ tab: SidebarTab) -> some View {
        let isActive = vm.selectedSidebarTab == tab
        return Button {
            vm.selectedSidebarTab = tab
        } label: {
            Text(tab.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isActive ? CXColor.accent : CXColor.textSoft)
                .frame(maxWidth: .infinity, minHeight: 30)
                .background(isActive ? CXColor.accentBg.opacity(0.72) : CXColor.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isActive ? CXColor.accent : CXColor.borderLight, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func channelPill(_ channel: ChatChannel) -> some View {
        let isActive = vm.selectedChannel == channel
        let tint = channel == .wa ? CXColor.waGreen : CXColor.accent

        return Button {
            vm.selectedChannel = channel
        } label: {
            Text(channel.rawValue)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(isActive ? tint : CXColor.textMute)
                .frame(width: 38, height: 34)
                .background(isActive ? CXColor.accentBg.opacity(0.72) : CXColor.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isActive ? tint.opacity(0.55) : CXColor.borderLight, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var contactsPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CXColor.textMute)
                TextField("Buscar contato", text: $vm.contactSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(CXColor.text)
            }
            .padding(.horizontal, CXSize.s3)
            .frame(height: 36)
            .background(CXColor.input)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(CXColor.borderLight, lineWidth: 1))
            .padding(CXSize.s3)

            ScrollView {
                LazyVStack(spacing: CXSize.s1) {
                    ForEach(vm.contactsDirectory) { contact in
                        Button {
                            vm.selectedSidebarTab = .chats
                            vm.selectedChatID = contact.id
                            Task { await vm.loadMessages(for: contact.id) }
                        } label: {
                            HStack(spacing: CXSize.s3) {
                                CXAvatarView(title: contact.title, size: 34)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(contact.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(CXColor.text)
                                        .lineLimit(1)
                                    Text(contact.jid)
                                        .font(.system(size: 10))
                                        .foregroundStyle(CXColor.textMute)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(contact.isGroup ? "Grupo" : "Contato")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(CXColor.textMute)
                            }
                            .padding(.horizontal, CXSize.s3)
                            .padding(.vertical, 8)
                            .background(CXColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(CXColor.borderLight, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(CXSize.s2)
            }
        }
        .background(
            LinearGradient(colors: [CXColor.surface, CXColor.surface2.opacity(0.75)], startPoint: .top, endPoint: .bottom)
        )
    }
}
