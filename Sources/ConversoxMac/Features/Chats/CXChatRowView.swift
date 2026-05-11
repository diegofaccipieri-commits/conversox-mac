import SwiftUI

struct CXChatRowView: View {
    let chat: Chat
    let isActive: Bool
    let avatarURL: URL?
    var draftPreview: String? = nil

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 3) {
                topRow
                previewRow
                bottomRow
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: CXRadius.lg, style: .continuous)
                .stroke(isActive ? CXColor.accentBg : Color.clear, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: CXRadius.lg, style: .continuous))
        .opacity(chat.isLowPriority && !isActive ? 0.65 : 1)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
    }

    // MARK: - Pieces

    private var avatar: some View {
        ZStack(alignment: .bottomTrailing) {
            CXAvatarView(title: chat.title, size: 40, imageURL: avatarURL)
            CXChannelBadge(connectionID: chat.connectionID, size: 14)
                .offset(x: 3, y: 3)
        }
        .frame(width: 40, height: 40)
    }

    private var topRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(chat.title)
                .font(.system(size: 13.5, weight: (chat.unreadCount > 0 || isActive) ? .bold : .medium))
                .foregroundStyle(CXColor.text)
                .lineLimit(1)

            Spacer(minLength: 6)

            Text(relativeTime(chat.updatedAt))
                .font(.system(size: 10.5, weight: chat.unreadCount > 0 ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(chat.unreadCount > 0 ? CXColor.accent : CXColor.textMute)
        }
    }

    private var previewRow: some View {
        HStack(spacing: 6) {
            if let draft = draftPreview, !draft.isEmpty {
                Text("Rascunho:")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(CXColor.accent)
                Text(draft)
                    .font(.system(size: 12.5).italic())
                    .foregroundStyle(CXColor.accent.opacity(0.85))
                    .lineLimit(1)
            } else if chat.isTyping {
                Text("● ● ●  digitando")
                    .font(.system(size: 12.5).italic())
                    .foregroundStyle(CXColor.accent)
                    .lineLimit(1)
            } else {
                if chat.lastFromMe {
                    statusIcon
                }
                Text(lastPreviewText)
                    .font(.system(size: 12.5))
                    .foregroundStyle(CXColor.textSoft)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if chat.unreadCount > 0 {
                CXUnreadBadge(count: chat.unreadCount)
            }
        }
    }

    private var bottomRow: some View {
        HStack(spacing: 6) {
            if let tag = chat.tagLabel {
                CXTagPill(label: tag)
            }
            if let owner = chat.ownerLabel {
                Text("@ \(owner)")
                    .font(.system(size: 10))
                    .foregroundStyle(CXColor.textMute)
            }
            if chat.isGroup {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(CXColor.textMute)
            }
            Spacer()
        }
        .padding(.top, 2)
    }

    private var statusIcon: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(CXColor.checkColor)
    }

    @ViewBuilder
    private var background: some View {
        if isActive {
            CXGradient.activeRow
        } else if isHovered {
            CXColor.alphaInk04
        } else {
            Color.clear
        }
    }

    private func relativeTime(_ date: Date) -> String {
        guard date != .distantPast else { return "" }
        if Calendar.current.isDateInToday(date) {
            return date.formatted(.dateTime.hour().minute())
        }
        if Calendar.current.isDateInYesterday(date) {
            return "Ontem"
        }
        let diff = Date().timeIntervalSince(date)
        if diff < 7 * 24 * 3600 {
            return date.formatted(.dateTime.weekday(.abbreviated))
        }
        return date.formatted(.dateTime.day().month())
    }

    private var lastPreviewText: String {
        if let preview = chat.lastMessagePreview?.trimmingCharacters(in: .whitespacesAndNewlines), !preview.isEmpty {
            return preview
        }
        switch chat.lastMessageType {
        case "image":    return "📷 Imagem"
        case "audio":    return "🎤 Áudio"
        case "ptt":      return "🎤 PTT"
        case "video":    return "🎬 Vídeo"
        case "sticker":  return "Sticker"
        case "document": return "📄 \(chat.lastMessageFileName ?? "Documento")"
        case "location": return "📍 Localização"
        case "contact":  return "👤 Contato"
        default:         return "Sem mensagens"
        }
    }
}

// MARK: - Convenience for tag / owner inference from existing Chat model

private extension Chat {
    var tagLabel: String? {
        if let badge = badge?.trimmingCharacters(in: .whitespacesAndNewlines), !badge.isEmpty {
            return badge.capitalized
        }
        return nil
    }

    var ownerLabel: String? {
        // The current Chat model doesn't expose an assigned operator; surface the
        // connection name as a soft fallback (mirrors web's "@ Atendente" line).
        let raw = connectionID
            .replacingOccurrences(of: "evolution:", with: "")
            .replacingOccurrences(of: "telegram:", with: "")
        let cleaned = raw
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return cleaned.split(separator: " ").first.map(String.init)?.capitalized
    }

    var isTyping: Bool { false }
}
