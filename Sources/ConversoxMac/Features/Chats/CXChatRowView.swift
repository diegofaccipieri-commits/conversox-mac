import SwiftUI

struct CXChatRowView: View {
    let chat: Chat
    let isActive: Bool

    var body: some View {
        HStack(alignment: .top, spacing: CXSize.s3) {
            CXAvatarView(title: chat.title)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: CXSize.s2) {
                    Text(chat.title)
                        .font(.system(size: 12, weight: chat.unreadCount > 0 ? .bold : .semibold))
                        .foregroundStyle(CXColor.text)
                        .lineLimit(1)

                    Spacer(minLength: CXSize.s2)

                    Text(relativeTime(chat.updatedAt))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(CXColor.textMute)
                }

                HStack(spacing: CXSize.s2) {
                    Text(chat.lastMessagePreview ?? "Sem mensagens")
                        .font(.system(size: 11))
                        .foregroundStyle(chat.unreadCount > 0 ? CXColor.textSoft : CXColor.textMute)
                        .lineLimit(1)

                    Spacer(minLength: CXSize.s2)

                    if chat.unreadCount > 0 {
                        CXUnreadBadge(count: chat.unreadCount)
                    }
                }

                HStack(spacing: 5) {
                    if let badge = chat.badge {
                        CXOriginBadge(text: badge)
                    }
                    CXOriginBadge(text: chat.connectionID.replacingOccurrences(of: "evolution:", with: ""))
                }
            }
        }
        .padding(CXSize.s3)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: CXSize.rMd, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CXSize.rMd, style: .continuous)
                .stroke(isActive ? CXColor.accent.opacity(0.45) : Color.clear, lineWidth: 1)
        )
    }

    private var rowBackground: some View {
        Group {
            if isActive {
                LinearGradient(colors: [CXColor.accentBg.opacity(0.72), CXColor.surface.opacity(0.96)], startPoint: .leading, endPoint: .trailing)
            } else {
                Color.clear
            }
        }
    }

    private func relativeTime(_ date: Date) -> String {
        guard date != .distantPast else { return "" }
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 60 { return "agora" }
        if seconds < 3600 { return "\(seconds / 60)min" }
        if seconds < 86_400 { return "\(seconds / 3600)h" }
        return date.formatted(.dateTime.day().month())
    }
}
