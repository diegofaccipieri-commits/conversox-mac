import Foundation

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

enum ChatChannel: String, CaseIterable, Identifiable {
    case all = "ALL"
    case td = "TD"
    case wa = "WA"
    case ig = "IG"
    case tg = "TG"
    case em = "EM"
    case sm = "SM"

    var id: String { rawValue }
}

struct ContactDirectoryEntry: Identifiable, Sendable {
    let id: String
    let title: String
    let jid: String
    let connectionID: String
    let isGroup: Bool
    let updatedAt: Date
}

@MainActor
final class ChatStore {
    private var byID: [String: Chat] = [:]

    func replaceAll(_ chats: [Chat]) {
        byID = Dictionary(uniqueKeysWithValues: chats.map { ($0.id, $0) })
    }

    func allChatsSorted() -> [Chat] {
        byID.values.sorted { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.id < rhs.id
        }
    }

    @discardableResult
    func merge(changes: [ChatChange]) -> Bool {
        var changed = false
        for change in changes {
            guard var chat = byID[change.chatID] else { continue }

            if let unread = change.unread, unread != chat.unreadCount {
                chat.unreadCount = unread
                changed = true
            }

            if let lastMessage = change.lastMessage, lastMessage != chat.lastMessagePreview {
                chat.lastMessagePreview = lastMessage
                changed = true
            }

            if let lastFromMe = change.lastFromMe, lastFromMe != chat.lastFromMe {
                chat.lastFromMe = lastFromMe
                changed = true
            }

            if let lastMessageType = change.lastMessageType, lastMessageType != chat.lastMessageType {
                chat.lastMessageType = lastMessageType
                changed = true
            }

            if let isLowPriority = change.isLowPriority, isLowPriority != chat.isLowPriority {
                chat.isLowPriority = isLowPriority
                changed = true
            }

            if let timestamp = change.sortTimestamp {
                let candidateDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
                if candidateDate != chat.updatedAt {
                    chat.updatedAt = candidateDate
                    changed = true
                }
            } else if let lastMessageAt = change.lastMessageAt, let date = DateParser.parse(lastMessageAt), date != chat.updatedAt {
                chat.updatedAt = date
                changed = true
            }

            byID[chat.id] = chat
        }
        return changed
    }

    func chat(for chatID: String?) -> Chat? {
        guard let chatID else { return nil }
        return byID[chatID]
    }

    func unreadTotal() -> Int {
        byID.values.reduce(0) { $0 + $1.unreadCount }
    }

    func contactsDirectory(searchText: String, channel: ChatChannel) -> [ContactDirectoryEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return allChatsSorted()
            .filter { passesChannel($0, channel: channel) }
            .filter { chat in
                guard !query.isEmpty else { return true }
                return chat.title.localizedCaseInsensitiveContains(query)
                    || chat.jid.localizedCaseInsensitiveContains(query)
            }
            .map { chat in
                ContactDirectoryEntry(
                    id: chat.id,
                    title: chat.title,
                    jid: chat.jid,
                    connectionID: chat.connectionID,
                    isGroup: chat.isGroup,
                    updatedAt: chat.updatedAt
                )
            }
    }

    func filteredChats(
        searchText: String,
        filter: ChatFilter,
        channel: ChatChannel
    ) -> [Chat] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return allChatsSorted()
            .filter { chat in
                guard passesFilter(chat, filter: filter) else { return false }
                guard passesChannel(chat, channel: channel) else { return false }
                guard isActive(chat) else { return false }
                guard !query.isEmpty else { return true }

                return chat.title.localizedCaseInsensitiveContains(query)
                    || chat.jid.localizedCaseInsensitiveContains(query)
                    || (chat.lastMessagePreview ?? "").localizedCaseInsensitiveContains(query)
                    || (chat.lastMessageFileName ?? "").localizedCaseInsensitiveContains(query)
            }
    }

    private func isActive(_ chat: Chat) -> Bool {
        if chat.unreadCount > 0 { return true }
        return chat.updatedAt > Date.distantPast
    }

    private func passesFilter(_ chat: Chat, filter: ChatFilter) -> Bool {
        switch filter {
        case .inbox:
            return !chat.isLowPriority
        case .unread:
            return chat.unreadCount > 0
        case .low:
            return chat.isLowPriority
        case .all:
            return true
        }
    }

    private func passesChannel(_ chat: Chat, channel: ChatChannel) -> Bool {
        guard channel != .all else { return true }
        return chat.resolvedChannel == channel
    }
}
