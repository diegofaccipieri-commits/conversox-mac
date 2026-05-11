import SwiftUI

struct CXAvatarView: View {
    let title: String
    var size: CGFloat = 40
    var imageURL: URL? = nil
    var online: Bool = false
    var ring: Color? = nil

    private var initials: String {
        let parts = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
        let value = String(parts).uppercased()
        return value.isEmpty ? "?" : value
    }

    private var bg: Color { .cxAvatar(for: title) }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                Circle().fill(bg)
                if let imageURL {
                    AuthedImage(
                        url: imageURL,
                        contentMode: .fill,
                        placeholder: {
                            Text(initials)
                                .font(.system(size: size * 0.36, weight: .semibold))
                                .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.10))
                        },
                        fallback: {
                            Text(initials)
                                .font(.system(size: size * 0.36, weight: .semibold))
                                .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.10))
                        }
                    )
                } else {
                    Text(initials)
                        .font(.system(size: size * 0.36, weight: .semibold))
                        .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.10))
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(ring ?? Color.clear, lineWidth: ring == nil ? 0 : 2)
            )

            if online {
                Circle()
                    .fill(CXColor.success)
                    .frame(width: size * 0.28, height: size * 0.28)
                    .overlay(Circle().stroke(CXColor.surface, lineWidth: 2))
                    .offset(x: 1, y: 1)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Channel dot/icon overlay positioned bottom-right of an avatar.
struct CXChannelBadge: View {
    let connectionID: String
    var size: CGFloat = 14

    private var channelColor: Color { .cxChannel(forConnectionID: connectionID) }
    private var symbol: String {
        let s = connectionID.lowercased()
        if s.contains("telegram") { return "paperplane.fill" }
        if s.contains("instagram") || s.contains("ig") { return "camera.fill" }
        if s.contains("mail") || s.contains("email") { return "envelope.fill" }
        if s.contains("sms") { return "text.bubble.fill" }
        return "message.fill"
    }

    var body: some View {
        ZStack {
            Circle().fill(channelColor)
            Image(systemName: symbol)
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(CXColor.surface, lineWidth: 2))
    }
}

struct CXUnreadBadge: View {
    let count: Int

    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.system(size: 10.5, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .frame(minWidth: 18, minHeight: 18)
            .background(CXColor.accent)
            .clipShape(Capsule())
    }
}

/// Small tag pill (Imigração, Vendas, Suporte...).
struct CXTagPill: View {
    let label: String

    var body: some View {
        let color = Color.cxTag(label)
        return Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .tracking(0.2)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.18))
            .clipShape(Capsule())
    }
}

/// Icon-only secondary button used in chat header (36x36 r10 panel-2 bg).
struct CXIconButton: View {
    let systemName: String
    var isOn = false
    var size: CGFloat = 36
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: size, height: size)
                .foregroundStyle(isOn ? CXColor.accent : CXColor.textSoft)
                .background(isOn ? CXColor.accentBg : CXColor.surface2)
                .clipShape(RoundedRectangle(cornerRadius: CXRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Legacy chip used in micro/version badges. Kept for compatibility.
struct CXOriginBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(CXColor.textMute)
            .padding(.horizontal, 6)
            .frame(height: 16)
            .background(CXColor.surface2)
            .clipShape(Capsule())
    }
}
