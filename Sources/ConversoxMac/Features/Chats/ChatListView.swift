import SwiftUI

struct ChatListView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var vm: ChatsViewModel

    @State private var searchText = ""
    @State private var selectedFilter: ChatFilter = .inbox

    private var filteredChats: [Chat] {
        vm.chats
            .filter { chat in
                switch selectedFilter {
                case .inbox:
                    return true
                case .unread:
                    return chat.unreadCount > 0
                case .low:
                    return false
                case .all:
                    return true
                }
            }
            .filter { chat in
                let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !query.isEmpty else { return true }
                return chat.title.localizedCaseInsensitiveContains(query)
                    || chat.jid.localizedCaseInsensitiveContains(query)
                    || (chat.lastMessagePreview ?? "").localizedCaseInsensitiveContains(query)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        ZStack {
            CXColor.bg.ignoresSafeArea()
            RadialGradient(colors: [CXColor.accentBg.opacity(0.35), .clear], center: .topLeading, startRadius: 80, endRadius: 520)
                .ignoresSafeArea()
            RadialGradient(colors: [CXColor.waGreen.opacity(0.12), .clear], center: .topTrailing, startRadius: 80, endRadius: 560)
                .ignoresSafeArea()

            HStack(spacing: CXSize.s3) {
                sidebar
                    .frame(minWidth: 300, idealWidth: 360, maxWidth: 390)
                    .cxShellPanel()

                mainPanel
                    .cxShellPanel()
            }
            .padding(CXSize.s3)
        }
        .preferredColorScheme(.dark)
        .task {
            await vm.loadInitialChatsIfNeeded()
            await vm.startRealtime()
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            VStack(spacing: CXSize.s3) {
                HStack(spacing: CXSize.s2) {
                    Text("ConversoxMac v0.1.1")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(CXColor.accent)
                        .padding(.horizontal, 9)
                        .frame(height: 28)
                        .background(CXColor.accentBg.opacity(0.72))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(CXColor.accent.opacity(0.32), lineWidth: 1))

                    searchField

                    CXIconButton(systemName: "plus") {}
                    CXIconButton(systemName: "bell") {}
                    CXIconButton(systemName: "moon.fill", isOn: true) {}
                }

                HStack(spacing: CXSize.s2) {
                    ForEach(ChatFilter.allCases) { filter in
                        filterButton(filter)
                    }
                }
            }
            .padding(CXSize.s4)
            .background(
                LinearGradient(colors: [CXColor.surface, CXColor.surface2], startPoint: .top, endPoint: .bottom)
            )

            Divider().overlay(CXColor.border)

            HStack(spacing: CXSize.s2) {
                channelPill("TD", isActive: false)
                channelPill("WA", isActive: true, tint: CXColor.waGreen)
                channelPill("IG", isActive: false)
                channelPill("TG", isActive: false)
                channelPill("EM", isActive: false)
                channelPill("SM", isActive: false)
            }
            .padding(.horizontal, CXSize.s4)
            .padding(.vertical, CXSize.s3)

            ScrollView {
                LazyVStack(spacing: CXSize.s1) {
                    ForEach(filteredChats) { chat in
                        Button {
                            vm.selectedChatID = chat.id
                            Task { await vm.loadMessages(for: chat.id) }
                        } label: {
                            CXChatRowView(chat: chat, isActive: vm.selectedChatID == chat.id)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(CXSize.s2)
            }
            .background(
                LinearGradient(colors: [CXColor.surface, CXColor.surface2.opacity(0.75)], startPoint: .top, endPoint: .bottom)
            )
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
                    Text("A lista de chats aparece à esquerda.")
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
            CXAvatarView(title: chat.title, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(chat.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(CXColor.text)
                HStack(spacing: 6) {
                    CXOriginBadge(text: chat.connectionID.replacingOccurrences(of: "evolution:", with: ""))
                    Text(chat.isGroup ? "grupo" : "online")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(chat.isGroup ? CXColor.textMute : CXColor.waGreen)
                }
            }

            Spacer()

            ForEach(["link", "arrowshape.turn.up.right", "tray.and.arrow.down", "sparkles", "note.text", "calendar", "checkmark"], id: \.self) { icon in
                CXIconButton(systemName: icon) {}
            }
        }
        .padding(.horizontal, CXSize.s4)
        .padding(.vertical, CXSize.s3)
        .background(
            LinearGradient(colors: [CXColor.surface, CXColor.surface2], startPoint: .top, endPoint: .bottom)
        )
        .overlay(alignment: .bottom) {
            Rectangle().fill(CXColor.border).frame(height: 1)
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(CXColor.textMute)
            TextField("Buscar", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(CXColor.text)
        }
        .padding(.horizontal, CXSize.s3)
        .frame(height: 36)
        .background(CXColor.input)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(CXColor.borderLight, lineWidth: 1))
    }

    private func filterButton(_ filter: ChatFilter) -> some View {
        let isActive = selectedFilter == filter
        return Button {
            selectedFilter = filter
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
            .foregroundStyle(isActive ? CXColor.accent : CXColor.textSoft)
            .frame(maxWidth: .infinity, minHeight: 30)
            .background(isActive ? CXColor.accentBg.opacity(0.72) : CXColor.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isActive ? CXColor.accent : CXColor.borderLight, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func channelPill(_ text: String, isActive: Bool, tint: Color = CXColor.accent) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(isActive ? tint : CXColor.textMute)
            .frame(width: 38, height: 34)
            .background(isActive ? CXColor.accentBg.opacity(0.72) : CXColor.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isActive ? tint.opacity(0.55) : CXColor.borderLight, lineWidth: 1))
    }
}

enum ChatFilter: String, CaseIterable, Identifiable {
    case inbox
    case unread
    case low
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inbox: return "Inbox"
        case .unread: return "Unread"
        case .low: return "Low"
        case .all: return "Todos"
        }
    }
}
