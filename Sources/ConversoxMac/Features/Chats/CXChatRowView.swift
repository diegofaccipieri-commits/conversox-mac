import SwiftUI

struct CXChatRowView: View {
    let chat: Chat
    let isActive: Bool
    let avatarURL: URL?
    var draftPreview: String? = nil

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: CXSize.s3) {
            CXAvatarView(title: chat.title, size: 40, imageURL: avatarURL)

            VStack(alignment: .leading, spacing: 4) {
                topRow
                previewRow
                bottomRow
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: CXRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CXRadius.md, style: .continuous)
                .stroke(isActive ? CXColor.accent.opacity(0.55) : Color.clear, lineWidth: 1)
        )
        .opacity(chat.isLowPriority && !isActive ? 0.7 : 1)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
    }

    // MARK: - Rows

    private var topRow: some View {
        HStack(spacing: CXSize.s2) {
            Text(chat.title)
                .font(.system(size: 15, weight: chat.unreadCount > 0 ? .bold : .semibold))
                .foregroundStyle(CXColor.text)
                .lineLimit(1)

            Spacer(minLength: CXSize.s2)

            HStack(spacing: 6) {
                if chat.isLowPriority {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(CXColor.warning)
                }
                Text(relativeTime(chat.updatedAt))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(chat.unreadCount > 0 ? CXColor.accent : CXColor.textMute)
            }
        }
    }

    private var previewRow: some View {
        HStack(spacing: 6) {
            if let draft = draftPreview, !draft.isEmpty {
                Text("Rascunho:")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CXColor.accent)
                Text(draft)
                    .font(.system(size: 13, weight: .regular).italic())
                    .foregroundStyle(CXColor.accent.opacity(0.85))
                    .lineLimit(1)
            } else {
                if chat.lastFromMe {
                    statusIcon
                }
                Text(lastPreviewText)
                    .font(.system(size: 13, weight: chat.unreadCount > 0 ? .medium : .regular))
                    .foregroundStyle(chat.unreadCount > 0 ? CXColor.textSoft : CXColor.textMute)
                    .lineLimit(1)
            }

            Spacer(minLength: CXSize.s2)

            if chat.unreadCount > 0 {
                CXUnreadBadge(count: chat.unreadCount)
            }
        }
    }

    private var bottomRow: some View {
        HStack(spacing: 6) {
            CXOriginBadge(text: companyLabel)
            if chat.isGroup {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(CXColor.textMute)
            }
            Spacer()
        }
    }

    private var statusIcon: some View {
        // pending=clock, sent=checkmark, delivered=double, read=double sky.
        // Hoje só temos last_from_me; usamos checkmark generic.
        Image(systemName: "checkmark")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(CXColor.checkColor)
    }

    private var rowBackground: some View {
        Group {
            if isActive {
                LinearGradient(
                    colors: [CXColor.accentBg.opacity(0.72), CXColor.surface2.opacity(0.98)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            } else if isHovered {
                CXColor.alphaInk04
            } else {
                Color.clear
            }
        }
    }

    private var companyLabel: String {
        if let badge = chat.badge?.trimmingCharacters(in: .whitespacesAndNewlines), !badge.isEmpty {
            return badge.uppercased()
        }
        let source = chat.connectionID
            .replacingOccurrences(of: "evolution:", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        return source.uppercased()
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
        default:
            return "Sem mensagens"
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
        let now = Date()
        let diff = now.timeIntervalSince(date)
        if diff < 7 * 24 * 3600 {
            return date.formatted(.dateTime.weekday(.abbreviated))
        }
        return date.formatted(.dateTime.day().month())
    }
}
