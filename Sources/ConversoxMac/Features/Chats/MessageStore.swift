import Foundation

@MainActor
final class MessageStore {
    private struct Entry {
        var messages: [Message]
        var knownIDs: Set<String>
        var lastAccess: Date
    }

    private var entries: [String: Entry] = [:]
    private let cacheTTL: TimeInterval
    private let maxCachedChats: Int

    init(cacheTTL: TimeInterval = 180, maxCachedChats: Int = 12) {
        self.cacheTTL = cacheTTL
        self.maxCachedChats = maxCachedChats
    }

    func messages(for chatID: String) -> [Message] {
        touch(chatID)
        return entries[chatID]?.messages ?? []
    }

    func setMessages(_ messages: [Message], for chatID: String) {
        let normalized = normalize(messages: messages, chatID: chatID)
        entries[chatID] = Entry(messages: normalized.messages, knownIDs: normalized.knownIDs, lastAccess: Date())
        pruneIfNeeded()
    }

    @discardableResult
    func prependOlder(_ messages: [Message], to chatID: String) -> [Message] {
        guard !messages.isEmpty else {
            touch(chatID)
            return entries[chatID]?.messages ?? []
        }

        var entry = entries[chatID] ?? Entry(messages: [], knownIDs: [], lastAccess: Date())
        var prepended: [Message] = []
        for message in messages {
            let normalized = message.withChatID(chatID)
            let id = dedupID(for: normalized)
            guard !entry.knownIDs.contains(id) else { continue }
            entry.knownIDs.insert(id)
            prepended.append(normalized)
        }

        entry.messages = prepended + entry.messages
        entry.messages.sort { $0.sentAt < $1.sentAt }
        entry.lastAccess = Date()
        entries[chatID] = entry
        pruneIfNeeded()
        return entry.messages
    }

    @discardableResult
    func appendInline(_ messages: [Message], to chatID: String) -> [Message] {
        guard !messages.isEmpty else {
            touch(chatID)
            return entries[chatID]?.messages ?? []
        }

        var entry = entries[chatID] ?? Entry(messages: [], knownIDs: [], lastAccess: Date())
        for message in messages {
            let normalized = message.withChatID(chatID)
            let id = dedupID(for: normalized)
            guard !entry.knownIDs.contains(id) else { continue }
            entry.knownIDs.insert(id)
            entry.messages.append(normalized)
        }

        entry.messages.sort { $0.sentAt < $1.sentAt }
        entry.lastAccess = Date()
        entries[chatID] = entry
        pruneIfNeeded()
        return entry.messages
    }

    func newestTimestamp(for chatID: String) -> Int {
        let ts = entries[chatID]?.messages.last?.sentAt.timeIntervalSince1970 ?? 0
        return max(Int(ts), 0)
    }

    @discardableResult
    func updateMediaURL(chatID: String, messageID: String, mediaURL: String) -> [Message] {
        guard var entry = entries[chatID] else { return [] }
        if let index = entry.messages.firstIndex(where: { $0.id == messageID || $0.keyID == messageID }) {
            entry.messages[index] = entry.messages[index].withMediaURL(mediaURL)
            entry.lastAccess = Date()
            entries[chatID] = entry
        }
        return entry.messages
    }

    private func normalize(messages: [Message], chatID: String) -> (messages: [Message], knownIDs: Set<String>) {
        var knownIDs: Set<String> = []
        var normalized: [Message] = []

        for message in messages {
            let patched = message.withChatID(chatID)
            let id = dedupID(for: patched)
            guard !knownIDs.contains(id) else { continue }
            knownIDs.insert(id)
            normalized.append(patched)
        }

        normalized.sort { $0.sentAt < $1.sentAt }
        return (normalized, knownIDs)
    }

    private func dedupID(for message: Message) -> String {
        if let keyID = message.keyID, !keyID.isEmpty { return keyID }
        if !message.id.isEmpty { return message.id }
        return "fallback-\(message.sentAt.timeIntervalSince1970)-\(message.senderName)-\(message.text)"
    }

    private func touch(_ chatID: String) {
        guard var entry = entries[chatID] else { return }
        entry.lastAccess = Date()
        entries[chatID] = entry
    }

    private func pruneIfNeeded() {
        let cutoff = Date().addingTimeInterval(-cacheTTL)
        entries = entries.filter { _, entry in
            entry.lastAccess > cutoff
        }

        if entries.count <= maxCachedChats { return }

        let sortedByAccess = entries.sorted { lhs, rhs in
            lhs.value.lastAccess < rhs.value.lastAccess
        }
        let overflow = entries.count - maxCachedChats
        for index in 0..<overflow {
            entries.removeValue(forKey: sortedByAccess[index].key)
        }
    }
}
