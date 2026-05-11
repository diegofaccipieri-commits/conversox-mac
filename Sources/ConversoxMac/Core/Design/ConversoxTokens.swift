import SwiftUI
import AppKit

// Tokens espelham 1:1 as CSS variables do web (assets/conversox/v5/conversox-v5.css):
// :root define light, html.dark define dark. Aqui resolvemos por NSAppearance
// para que a UI reaja ao Theme.appearance (light/dark/system).

private func hex(_ v: UInt32) -> NSColor {
    let r = CGFloat((v >> 16) & 0xff) / 255
    let g = CGFloat((v >> 8) & 0xff) / 255
    let b = CGFloat(v & 0xff) / 255
    return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
}

private func rgba(_ v: UInt32, _ a: CGFloat) -> NSColor {
    let r = CGFloat((v >> 16) & 0xff) / 255
    let g = CGFloat((v >> 8) & 0xff) / 255
    let b = CGFloat(v & 0xff) / 255
    return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}

private func dyn(light: NSColor, dark: NSColor) -> Color {
    let ns = NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .aqua, .vibrantLight]) == .darkAqua
            || appearance.bestMatch(from: [.darkAqua, .vibrantDark, .aqua, .vibrantLight]) == .vibrantDark
        return isDark ? dark : light
    }
    return Color(nsColor: ns)
}

// MARK: - Color tokens (CSS-equivalent)

enum CXColor {
    // Neutrals (constant across themes; from --cx-neutral-*)
    static let neutral0   = Color(nsColor: hex(0xffffff))
    static let neutral50  = Color(nsColor: hex(0xf8fafc))
    static let neutral100 = Color(nsColor: hex(0xf1f5f9))
    static let neutral200 = Color(nsColor: hex(0xe2e8f0))
    static let neutral300 = Color(nsColor: hex(0xcbd5e1))
    static let neutral400 = Color(nsColor: hex(0x94a3b8))
    static let neutral500 = Color(nsColor: hex(0x64748b))
    static let neutral600 = Color(nsColor: hex(0x475569))
    static let neutral700 = Color(nsColor: hex(0x334155))
    static let neutral800 = Color(nsColor: hex(0x1e293b))
    static let neutral900 = Color(nsColor: hex(0x0f172a))

    // Brand
    static let waGreen = Color(nsColor: hex(0x25d366))
    static let danger  = Color(nsColor: hex(0xef4444))
    static let warning = Color(nsColor: hex(0xf59e0b))
    static let success = Color(nsColor: hex(0x10b981))
    static let note    = Color(nsColor: hex(0xfacc15))
    static let checkRead = Color(nsColor: hex(0x38bdf8))

    // Theme-aware
    static let bg          = dyn(light: hex(0xf8fafc), dark: hex(0x0f172a))
    static let surface     = dyn(light: hex(0xffffff), dark: hex(0x1e293b))
    static let surface2    = dyn(light: hex(0xf1f5f9), dark: hex(0x162136))
    static let surface3    = dyn(light: hex(0xeff6ff), dark: hex(0x111a2d))
    static let border      = dyn(light: hex(0xe2e8f0), dark: hex(0x263247))
    static let borderLight = dyn(light: hex(0xcbd5e1), dark: hex(0x314057))

    static let text        = dyn(light: hex(0x0f172a), dark: hex(0xe2e8f0))
    static let textSoft    = dyn(light: hex(0x475569), dark: hex(0xcbd5e1))
    static let textMute    = dyn(light: hex(0x64748b), dark: hex(0x94a3b8))

    static let accent       = dyn(light: hex(0x2563eb), dark: hex(0x3b82f6))
    static let accentStrong = dyn(light: hex(0x1d4ed8), dark: hex(0x2563eb))
    static let accentBg     = dyn(light: hex(0xdbeafe), dark: hex(0x1e3a66))

    // Bubble
    static let bubbleIn         = dyn(light: hex(0xffffff), dark: hex(0x142034))
    static let bubbleInBorder   = dyn(light: hex(0xe2e8f0), dark: hex(0x2d3b53))
    static let bubbleInText     = dyn(light: hex(0x1e293b), dark: hex(0xdbeafe))
    static let bubbleOutStart   = dyn(light: hex(0xdbeafe), dark: hex(0x2a5d9a))
    static let bubbleOutEnd     = dyn(light: hex(0xbfdbfe), dark: hex(0x2563eb))
    static let bubbleOutText    = dyn(light: hex(0x102a4c), dark: hex(0xeff6ff))
    static let bubbleOutBorder  = dyn(light: hex(0x93c5fd), dark: hex(0x3267b0))

    static let composer       = dyn(light: hex(0xffffff), dark: hex(0x121d31))
    static let composerBorder = dyn(light: hex(0xe2e8f0), dark: hex(0x2d3b53))
    static let input          = dyn(light: hex(0xffffff), dark: hex(0x0f172a))
    static let inputBorder    = dyn(light: hex(0xcbd5e1), dark: hex(0x334155))

    static let checkColor = dyn(light: hex(0x64748b), dark: hex(0x94a3b8))

    static let skeletonBg    = dyn(light: hex(0xe2e8f0), dark: hex(0x243247))
    static let skeletonShine = dyn(light: hex(0xf8fafc), dark: hex(0x334155))

    // Alpha ink overlays (used for hover/selected states)
    static let alphaInk04 = dyn(light: rgba(0x0f172a, 0.04), dark: rgba(0x000000, 0.20))
    static let alphaInk06 = dyn(light: rgba(0x0f172a, 0.06), dark: rgba(0x000000, 0.24))
    static let alphaInk08 = dyn(light: rgba(0x0f172a, 0.08), dark: rgba(0x000000, 0.28))
    static let alphaInk12 = dyn(light: rgba(0x0f172a, 0.12), dark: rgba(0x000000, 0.34))
    static let alphaInk16 = dyn(light: rgba(0x0f172a, 0.16), dark: rgba(0x000000, 0.44))
    static let alphaInk24 = dyn(light: rgba(0x0f172a, 0.24), dark: rgba(0x000000, 0.58))
    static let alphaOverlay = dyn(light: rgba(0x0f172a, 0.52), dark: rgba(0x020617, 0.70))
}

// MARK: - Gradients (espelham linear-gradient(... ) do CSS)

enum CXGradient {
    static let bubbleOut = LinearGradient(
        colors: [CXColor.bubbleOutStart, CXColor.bubbleOutEnd],
        startPoint: .init(x: 0.15, y: 0.0),   // ~145deg em CSS
        endPoint: .init(x: 0.85, y: 1.0)
    )

    static let unread = LinearGradient(
        colors: [Color(nsColor: hex(0xef4444)), Color(nsColor: hex(0xdc2626))],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentButton = LinearGradient(
        colors: [CXColor.accent, CXColor.accentStrong],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let sidebarHeader = LinearGradient(
        colors: [CXColor.surface, CXColor.surface2],
        startPoint: .init(x: 0.2, y: 0.0),    // ~160deg
        endPoint: .init(x: 0.8, y: 1.0)
    )

    static let chatListBg = LinearGradient(
        colors: [CXColor.surface, CXColor.surface2],
        startPoint: .top,
        endPoint: .bottom
    )

    static let composerBg = LinearGradient(
        colors: [CXColor.composer, CXColor.surface],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Spacing & radius (CSS vars: --cx-s-*, --cx-r-*)

enum CXSize {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s8: CGFloat = 32

    // Legacy radius aliases (mantidos para evitar quebra; usar CXRadius novo)
    static let rSm: CGFloat = CXRadius.sm
    static let rMd: CGFloat = CXRadius.md
    static let rLg: CGFloat = CXRadius.lg
    static let rXl: CGFloat = CXRadius.xl
    static let shellRadius: CGFloat = CXRadius.shell
}

enum CXRadius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 10
    static let lg: CGFloat = 14
    static let xl: CGFloat = 20
    static let full: CGFloat = 999
    static let shell: CGFloat = 24
}

enum CXShadow {
    static let s1 = Shadow(radius: 2, x: 0, y: 1, opacity: 0.12)
    static let s2 = Shadow(radius: 12, x: 0, y: 4, opacity: 0.18)
    static let s3 = Shadow(radius: 32, x: 0, y: 12, opacity: 0.24)
    static let shell = Shadow(radius: 44, x: 0, y: 24, opacity: 0.30)

    struct Shadow {
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
        let opacity: Double
    }
}

// MARK: - Typography (CSS: Manrope com fallback system)

enum CXFont {
    private static let manropeAvailable: Bool = {
        NSFont(name: "Manrope-Regular", size: 13) != nil
            || NSFont(name: "Manrope", size: 13) != nil
    }()

    static func body(_ size: CGFloat = 13, weight: Font.Weight = .regular) -> Font {
        if manropeAvailable, let name = manropeFontName(for: weight) {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: weight)
    }

    private static func manropeFontName(for weight: Font.Weight) -> String? {
        let candidates: [String]
        switch weight {
        case .bold, .heavy, .black:
            candidates = ["Manrope-Bold", "Manrope"]
        case .semibold:
            candidates = ["Manrope-SemiBold", "Manrope"]
        case .medium:
            candidates = ["Manrope-Medium", "Manrope"]
        case .light, .thin, .ultraLight:
            candidates = ["Manrope-Light", "Manrope"]
        default:
            candidates = ["Manrope-Regular", "Manrope"]
        }
        return candidates.first { NSFont(name: $0, size: 13) != nil }
    }
}

// MARK: - Theme manager

@MainActor
final class CXTheme: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var label: String {
            switch self {
            case .system: return "Sistema"
            case .light:  return "Claro"
            case .dark:   return "Escuro"
            }
        }
    }

    static let shared = CXTheme()

    @Published var mode: Mode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: Self.storageKey)
            applyToApp()
        }
    }

    private static let storageKey = "cx.theme.mode"

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey) ?? Mode.system.rawValue
        self.mode = Mode(rawValue: raw) ?? .system
        applyToApp()
    }

    func applyToApp() {
        let appearance: NSAppearance? = {
            switch mode {
            case .system: return nil
            case .light:  return NSAppearance(named: .aqua)
            case .dark:   return NSAppearance(named: .darkAqua)
            }
        }()
        NSApp?.appearance = appearance
    }
}

// MARK: - View helpers

extension View {
    func cxShellPanel(radius: CGFloat = CXRadius.shell) -> some View {
        self
            .background(CXColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(CXColor.border, lineWidth: 1)
            )
    }

    func cxShadow(_ s: CXShadow.Shadow) -> some View {
        self.shadow(color: .black.opacity(s.opacity), radius: s.radius, x: s.x, y: s.y)
    }
}
