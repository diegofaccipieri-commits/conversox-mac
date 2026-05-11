import SwiftUI

enum CXToastKind: Sendable {
    case info, success, warning, error

    var iconName: String {
        switch self {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    var background: Color {
        switch self {
        case .info: return CXColor.accent.opacity(0.95)
        case .success: return CXColor.success.opacity(0.95)
        case .warning: return CXColor.warning.opacity(0.95)
        case .error: return CXColor.danger.opacity(0.95)
        }
    }
}

struct CXToast: Identifiable, Equatable, Sendable {
    let id = UUID()
    let message: String
    let kind: CXToastKind
    let duration: TimeInterval

    static func == (lhs: CXToast, rhs: CXToast) -> Bool { lhs.id == rhs.id }
}

@MainActor
final class CXToastCenter: ObservableObject {
    static let shared = CXToastCenter()

    @Published private(set) var toasts: [CXToast] = []
    private let maxVisible = 4

    private init() {}

    func push(_ message: String, kind: CXToastKind = .info, duration: TimeInterval = 4.0) {
        let toast = CXToast(message: message, kind: kind, duration: duration)
        toasts.append(toast)
        if toasts.count > maxVisible {
            toasts.removeFirst(toasts.count - maxVisible)
        }
        Task { [weak self, id = toast.id] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            await self?.dismiss(id: id)
        }
    }

    func info(_ message: String) { push(message, kind: .info) }
    func success(_ message: String) { push(message, kind: .success) }
    func warning(_ message: String) { push(message, kind: .warning) }
    func error(_ message: String) { push(message, kind: .error) }

    func dismiss(id: UUID) {
        toasts.removeAll { $0.id == id }
    }
}

struct CXToastOverlay: View {
    @ObservedObject private var center = CXToastCenter.shared

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(center.toasts) { toast in
                HStack(spacing: 8) {
                    Image(systemName: toast.kind.iconName)
                        .font(.system(size: 13, weight: .bold))
                    Text(toast.message)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(toast.kind.background)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 3)
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .onTapGesture { center.dismiss(id: toast.id) }
            }
        }
        .padding(16)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: center.toasts)
    }
}
