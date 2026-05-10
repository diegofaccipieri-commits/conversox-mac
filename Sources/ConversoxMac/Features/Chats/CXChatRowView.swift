import SwiftUI

struct CXChatRowView: View {
    let chat: Chat
    let isActive: Bool
    let avatarURL: URL?

    var body: some View {
        HStack(alignment: .top, spacing: CXSize.s3) {
            CXAvatarView(title: chat.title, size: 52, imageURL: avatarURL)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: CXSize.s2) {
                    Text(chat.title)
                        .font(.system(size: 15, weight: chat.unreadCount > 0 ? .bold : .semibold))
                        .foregroundStyle(CXColor.text)
                        .lineLimit(1)

                    Spacer(minLength: CXSize.s2)

                    HStack(spacing: 6) {
                        if chat.isLowPriority {
                            Circle()
                                .fill(CXColor.warning)
                                .frame(width: 8, height: 8)
                        }
                        Text(relativeTime(chat.updatedAt))
                    }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(chat.unreadCount > 0 ? CXColor.accent : CXColor.textMute)
                }

                HStack(spacing: CXSize.s2) {
                    if chat.lastFromMe {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(CXColor.textMute)
                    }

                    Text(lastPreviewText)
                        .font(.system(size: 13, weight: chat.unreadCount > 0 ? .medium : .regular))
                        .foregroundStyle(chat.unreadCount > 0 ? CXColor.textSoft : CXColor.textMute)
                        .lineLimit(1)

                    Spacer(minLength: CXSize.s2)

                    if chat.unreadCount > 0 {
                        CXUnreadBadge(count: chat.unreadCount)
                    }
                }

                Text(companyLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(CXColor.textMute.opacity(0.82))
                    .lineLimit(1)
                    .textCase(.uppercase)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: CXSize.rMd, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CXSize.rMd, style: .continuous)
                .stroke(isActive ? CXColor.accent.opacity(0.65) : Color.clear, lineWidth: 1)
        )
    }

    private var rowBackground: some View {
        Group {
            if isActive {
                LinearGradient(colors: [CXColor.accentBg.opacity(0.72), CXColor.surface2.opacity(0.98)], startPoint: .leading, endPoint: .trailing)
            } else {
                Color.clear
            }
        }
    }

    private var companyLabel: String {
        if let badge = chat.badge?.trimmingCharacters(in: .whitespacesAndNewlines), !badge.isEmpty {
            return badge
        }
        let source = chat.connectionID
            .replacingOccurrences(of: "evolution:", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        return source
    }

    private var lastPreviewText: String {
        if let preview = chat.lastMessagePreview?.trimmingCharacters(in: .whitespacesAndNewlines), !preview.isEmpty {
            return preview
        }

        switch chat.lastMessageType {
        case "image":
            return "Imagem"
        case "audio", "ptt":
            return "Audio"
        case "video":
            return "Video"
        case "document":
            return chat.lastMessageFileName ?? "Documento"
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
        return date.formatted(.dateTime.day().month())
    }
}
