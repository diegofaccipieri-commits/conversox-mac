import SwiftUI

struct CXAvatarView: View {
    let title: String
    var size: CGFloat = 42

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
                .fill(CXColor.surface2)
            Text(initials)
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(CXColor.accent)
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(CXColor.borderLight, lineWidth: 1))
    }
}

struct CXUnreadBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .frame(minHeight: 18)
            .background(
                LinearGradient(colors: [CXColor.danger, Color(red: 220 / 255, green: 38 / 255, blue: 38 / 255)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
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
            .background(CXColor.surface)
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
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 32, height: 32)
                .foregroundStyle(isOn ? CXColor.accent : CXColor.textSoft)
                .background(isOn ? CXColor.accentBg.opacity(0.85) : CXColor.surface)
                .clipShape(Circle())
                .overlay(Circle().stroke(isOn ? CXColor.accent.opacity(0.5) : CXColor.borderLight, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
