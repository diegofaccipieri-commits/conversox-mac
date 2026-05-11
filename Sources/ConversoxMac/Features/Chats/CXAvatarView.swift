import SwiftUI

struct CXAvatarView: View {
    let title: String
    var size: CGFloat = 42
    var imageURL: URL? = nil

    private var initials: String {
        let parts = title
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
        let value = String(parts).uppercased()
        return value.isEmpty ? "?" : value
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [CXColor.surface3, CXColor.surface2],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let imageURL {
                AuthedImage(
                    url: imageURL,
                    contentMode: .fill,
                    placeholder: {
                        Text(initials)
                            .font(.system(size: size * 0.34, weight: .bold))
                            .foregroundStyle(.white.opacity(0.92))
                    },
                    fallback: {
                        Text(initials)
                            .font(.system(size: size * 0.34, weight: .bold))
                            .foregroundStyle(.white.opacity(0.92))
                    }
                )
            } else {
                Text(initials)
                    .font(.system(size: size * 0.34, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(CXColor.borderLight.opacity(0.9), lineWidth: 1))
    }
}

struct CXUnreadBadge: View {
    let count: Int

    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.system(size: 10, weight: .heavy, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .frame(minWidth: 18)
            .background(CXGradient.unread)
            .clipShape(Capsule())
    }
}

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
            .overlay(Capsule().stroke(CXColor.borderLight, lineWidth: 1))
    }
}

struct CXIconButton: View {
    let systemName: String
    var isOn = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 36, height: 36)
                .foregroundStyle(isOn ? CXColor.accent : CXColor.textSoft)
                .background(isOn ? CXColor.accentBg.opacity(0.85) : CXColor.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(isOn ? CXColor.accent.opacity(0.5) : CXColor.borderLight, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
