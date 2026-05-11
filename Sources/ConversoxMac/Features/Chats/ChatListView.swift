import SwiftUI

struct ChatListView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var vm: ChatsViewModel
    @StateObject private var theme = CXTheme.shared
    @State private var showNewChatSheet = false
    @State private var newChatPhone = ""
    @State private var newChatName = ""
    @State private var newChatConnectionID = ""

    var body: some View {
        ZStack {
            // Body bg: solid --cx-bg + dois radials sutis (espelha CSS web `body`).
            CXColor.bg
                .ignoresSafeArea()
            GeometryReader { proxy in
                ZStack {
                    RadialGradient(
                        colors: [CXColor.surface3.opacity(0.55), .clear],
                        center: UnitPoint(x: 0.18, y: 0.12),
                        startRadius: 0,
                        endRadius: max(proxy.size.width, proxy.size.height) * 0.45
                    )
                    RadialGradient(
                        colors: [CXColor.accentBg.opacity(0.4), .clear],
                        center: UnitPoint(x: 0.82, y: 0.10),
                        startRadius: 0,
                        endRadius: max(proxy.size.width, proxy.size.height) * 0.5
                    )
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            HStack(spacing: 0) {
                sidebar
                    .frame(width: 68 + 340)
                    .overlay(alignment: .trailing) {
                        Rectangle().fill(CXColor.border).frame(width: 1)
                    }

                mainPanel
            }
            .background(CXColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: CXRadius.shell, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CXRadius.shell, style: .continuous)
                    .stroke(CXColor.border, lineWidth: 1)
            )
            .padding(8)
        }
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

            }
            .padding(.top, 18)

            CXToastOverlay()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .allowsHitTesting(true)
        }
        .task {
            await vm.loadInitialChatsIfNeeded()
            await vm.startRealtime()
        }
    }

    private var sidebar: some View {
        HStack(spacing: 0) {
            channelRail
                .frame(width: 68)
                .background(CXColor.surface2)
                .overlay(alignment: .trailing) {
                    Rectangle().fill(CXColor.border).frame(width: 1)
                }

            sidebarColumn
                .frame(width: 340)
        }
    }

    // Coluna vertical à esquerda: logo Cx, filtros de canal, tabs CH/CT.
    // Espelha .conversox-sidebar grid 68px column do v5.css (desktop >=901px).
    private var channelRail: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(CXGradient.accentButton)
                Text("Cx")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 40, height: 40)
            .shadow(color: CXColor.accent.opacity(0.45), radius: 8, x: 0, y: 4)
            .padding(.top, 14)
            .padding(.bottom, 6)

            ForEach([ChatChannel.td, .wa, .ig, .tg, .em, .sm], id: \.id) { channel in
                railChannelButton(channel)
            }

            Spacer(minLength: 6)

            // Tabs verticais CH (Chats) / CT (Contatos)
            ForEach(SidebarTab.allCases, id: \.self) { tab in
                railTabButton(tab)
            }
            .padding(.bottom, 14)
        }
        .frame(maxHeight: .infinity)
    }

    private var sidebarColumn: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Conversas")
                        .font(.system(size: 22, weight: .bold))
                        .tracking(-0.5)
                        .foregroundStyle(CXColor.text)
                    Text("\(vm.visibleChats.count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CXColor.textMute)
                        .padding(.horizontal, 6)
                        .frame(minHeight: 18)
                        .background(CXColor.surface2)
                        .clipShape(Capsule())

                    Spacer(minLength: 4)

                    CXIconButton(systemName: "plus") {}
                    CXIconButton(systemName: themeIconName, isOn: false) { cycleTheme() }
                }

                searchField

                HStack(spacing: 6) {
                    ForEach(ChatFilter.allCases) { filter in
                        filterButton(filter)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(CXGradient.sidebarHeader)

            Divider().overlay(CXColor.border)

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
                    .background(CXGradient.chatListBg)
                }
            } else {
                contactsPanel
            }
        }
    }

    private func railChannelButton(_ channel: ChatChannel) -> some View {
        let isActive = vm.selectedChannel == channel
        return Button {
            vm.selectedChannel = channel
        } label: {
            Text(channel.rawValue)
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.4)
                .foregroundStyle(isActive ? CXColor.accent : CXColor.textMute)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isActive ? CXColor.accentBg : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private func railTabButton(_ tab: SidebarTab) -> some View {
        let isActive = vm.selectedSidebarTab == tab
        let label = tab == .chats ? "CH" : "CT"
        return Button {
            vm.selectedSidebarTab = tab
        } label: {
            Text(label)
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.4)
                .foregroundStyle(isActive ? CXColor.accent : CXColor.textMute)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isActive ? CXColor.accentBg : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Theme cycle

    private var themeIconName: String {
        switch theme.mode {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    private func cycleTheme() {
        switch theme.mode {
        case .system: theme.mode = .light
        case .light:  theme.mode = .dark
        case .dark:   theme.mode = .system
        }
    }

    private var mainPanel: some View {
        Group {
            if let chatID = vm.selectedChatID, let chat = vm.chats.first(where: { $0.id == chatID }) {
                HStack(spacing: 0) {
                    MessageThreadView(chatID: chatID)
                        .safeAreaInset(edge: .top, spacing: 0) {
                            CXChatHeaderView(chat: chat)
                        }
                        .frame(maxWidth: .infinity)

                    Rectangle().fill(CXColor.border).frame(width: 1)

                    DetailPanelView(chat: chat, avatarURL: resolvedChatAvatarURL(chat))
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


    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CXColor.textMute)
            TextField("Buscar conversas...", text: vm.selectedSidebarTab == .contacts ? $vm.contactSearchText : $vm.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(CXColor.text)
            if !(vm.selectedSidebarTab == .contacts ? vm.contactSearchText : vm.searchText).isEmpty {
                Button {
                    if vm.selectedSidebarTab == .contacts {
                        vm.contactSearchText = ""
                    } else {
                        vm.searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(CXColor.textMute)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(CXColor.input)
        .clipShape(RoundedRectangle(cornerRadius: CXRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CXRadius.md, style: .continuous)
                .stroke(CXColor.inputBorder, lineWidth: 1)
        )
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
            HStack(spacing: 8) {
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

                Button {
                    newChatPhone = ""
                    newChatName = ""
                    newChatConnectionID = vm.availableConnections.first ?? ""
                    showNewChatSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(CXColor.accent)
                }
                .buttonStyle(.plain)
                .help("Nova conversa")
            }
            .padding(CXSize.s3)

            ScrollView {
                LazyVStack(spacing: CXSize.s1) {
                    ForEach(vm.contactsDirectory) { contact in
                        Button {
                            Task { await vm.openOrCreateContact(contact) }
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
        .sheet(isPresented: $showNewChatSheet) {
            newChatSheet
        }
    }

    private var newChatSheet: some View {
        VStack(alignment: .leading, spacing: CXSize.s3) {
            Text("Nova conversa")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(CXColor.text)

            VStack(alignment: .leading, spacing: 4) {
                Text("Conexão")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(CXColor.textMute)
                Picker("", selection: $newChatConnectionID) {
                    ForEach(vm.availableConnections, id: \.self) { conn in
                        Text(conn).tag(conn)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Telefone (com DDI, ex.: 5511999999999)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(CXColor.textMute)
                TextField("5511999999999", text: $newChatPhone)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Nome (opcional)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(CXColor.textMute)
                TextField("Nome do contato", text: $newChatName)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("Cancelar") { showNewChatSheet = false }
                Button("Criar") {
                    let digits = newChatPhone.filter { $0.isNumber }
                    guard !digits.isEmpty, !newChatConnectionID.isEmpty else { return }
                    let jid = "\(digits)@s.whatsapp.net"
                    let conn = newChatConnectionID
                    let name = newChatName
                    showNewChatSheet = false
                    Task { await vm.openOrCreateContact(jid: jid, connectionID: conn, name: name) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newChatPhone.filter { $0.isNumber }.isEmpty || newChatConnectionID.isEmpty)
            }
        }
        .padding(CXSize.s4)
        .frame(width: 380)
        .background(CXColor.surface2)
    }
}
