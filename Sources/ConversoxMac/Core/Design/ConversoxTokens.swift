import SwiftUI
import AppKit

// Bold design tokens (per IMPLEMENTATION.md from Conversox Redesign).
// OKLCH values from the spec converted to sRGB hex (deterministic conversion
// done once at design time; do not "fix" the hex values without going back
// through the same OKLCH input).

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
        let match = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .aqua, .vibrantLight])
        let isDark = match == .darkAqua || match == .vibrantDark
        return isDark ? dark : light
    }
    return Color(nsColor: ns)
}

// MARK: - Bold color tokens

enum CXColor {
    // --bg / --panel / --panel-2 / --panel-3
    static let bg       = dyn(light: hex(0xF7F8FD), dark: hex(0x080811))
    static let surface  = dyn(light: hex(0xFFFFFF), dark: hex(0x10111A))   // --panel
    static let surface2 = dyn(light: hex(0xF1F1F6), dark: hex(0x191A24))   // --panel-2
    static let surface3 = dyn(light: hex(0xE7E7EC), dark: hex(0x22232E))   // --panel-3

    // --border / --border-soft
    static let border       = dyn(light: hex(0xDDDEE2), dark: hex(0x272833))
    static let borderLight  = dyn(light: hex(0xEAEBEF), dark: hex(0x1D1E29)) // --border-soft

    // --text / --text-dim / --text-dim-2
    static let text     = dyn(light: hex(0x14151F), dark: hex(0xF4F5F9))
    static let textSoft = dyn(light: hex(0x5B5D69), dark: hex(0xA3A4AB))    // --text-dim
    static let textMute = dyn(light: hex(0x838592), dark: hex(0x707177))    // --text-dim-2

    // Accent (teal) + gradient end (indigo)
    static let accent       = Color(nsColor: hex(0x008E89))                 // oklch(0.58 0.11 190)
    static let accentEnd    = Color(nsColor: hex(0x0089ED))                 // oklch(0.62 0.18 250)
    static let accentStrong = Color(nsColor: hex(0x006E6A))
    static let accentBg     = dyn(light: rgba(0x008E89, 0.12), dark: rgba(0x008E89, 0.18))
    static let accentBgSoft = dyn(light: rgba(0x008E89, 0.06), dark: rgba(0x008E89, 0.08))

    // States
    static let success = Color(nsColor: hex(0x53BE70))   // online dot, WA
    static let warning = Color(nsColor: hex(0xD29000))
    static let danger  = Color(nsColor: hex(0xE85760))
    static let note    = Color(nsColor: hex(0xCB9317))
    static let waGreen = Color(nsColor: hex(0x53BE70))

    // Channels
    static let chWhatsapp  = Color(nsColor: hex(0x53BE70))
    static let chInstagram = Color(nsColor: hex(0xE85760))
    static let chTelegram  = Color(nsColor: hex(0x3CA2E0))
    static let chEmail     = Color(nsColor: hex(0x6B727E))
    static let chSMS       = Color(nsColor: hex(0x9E91E4))

    // Tags
    static let tagImigracao = Color(nsColor: hex(0x00B4BC))
    static let tagVendas    = Color(nsColor: hex(0xE87A69))
    static let tagSuporte   = Color(nsColor: hex(0x9E91E4))

    // Internal note card (amber)
    static let noteCardBg     = dyn(light: rgba(0xF7C56D, 0.20), dark: rgba(0xF7C56D, 0.15))
    static let noteCardBorder = dyn(light: rgba(0xCB9317, 0.45), dark: rgba(0xCB9317, 0.30))
    static let noteCardLine   = Color(nsColor: hex(0xCB9317))

    // Bubbles
    static let bubbleIn       = dyn(light: hex(0xFFFFFF), dark: hex(0x191A24))   // panel/panel-2
    static let bubbleInBorder = dyn(light: hex(0xEAEBEF), dark: hex(0x272833))
    static let bubbleInText   = dyn(light: hex(0x14151F), dark: hex(0xF4F5F9))
    // outbound uses CXGradient.bubbleOut (accent->indigo); single-color fallbacks:
    static let bubbleOutStart = Color(nsColor: hex(0x008E89))
    static let bubbleOutEnd   = Color(nsColor: hex(0x0089ED))
    static let bubbleOutText  = Color.white
    static let bubbleOutBorder = Color(nsColor: hex(0x008E89))

    // Composer + input
    static let composer       = dyn(light: hex(0xFFFFFF), dark: hex(0x10111A))
    static let composerBorder = dyn(light: hex(0xDDDEE2), dark: hex(0x272833))
    static let input          = dyn(light: hex(0xF1F1F6), dark: hex(0x191A24))   // panel-2
    static let inputBorder    = dyn(light: hex(0xDDDEE2), dark: hex(0x272833))

    // Status check icons
    static let checkColor = dyn(light: hex(0x838592), dark: hex(0x707177))
    static let checkRead  = Color(nsColor: hex(0x008E89))

    // Skeleton shimmer
    static let skeletonBg    = dyn(light: hex(0xF1F1F6), dark: hex(0x22232E))
    static let skeletonShine = dyn(light: hex(0xFFFFFF), dark: hex(0x363753))

    // Ink overlays
    static let alphaInk04 = dyn(light: rgba(0x14151F, 0.04), dark: rgba(0xFFFFFF, 0.04))
    static let alphaInk06 = dyn(light: rgba(0x14151F, 0.06), dark: rgba(0xFFFFFF, 0.06))
    static let alphaInk08 = dyn(light: rgba(0x14151F, 0.08), dark: rgba(0xFFFFFF, 0.08))
    static let alphaInk12 = dyn(light: rgba(0x14151F, 0.12), dark: rgba(0xFFFFFF, 0.12))
    static let alphaInk16 = dyn(light: rgba(0x14151F, 0.16), dark: rgba(0xFFFFFF, 0.16))
    static let alphaInk24 = dyn(light: rgba(0x14151F, 0.24), dark: rgba(0xFFFFFF, 0.24))
    static let alphaOverlay = dyn(light: rgba(0x14151F, 0.52), dark: rgba(0x000000, 0.70))

    // Neutrals kept for backward compatibility with existing call sites
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
}

// MARK: - Helpers

extension Color {
    static func cxTag(_ tag: String?) -> Color {
        guard let key = tag?.lowercased() else { return CXColor.textMute }
        if key.contains("imig")   { return CXColor.tagImigracao }
        if key.contains("vend") || key.contains("sales") { return CXColor.tagVendas }
        if key.contains("sup")    { return CXColor.tagSuporte }
        return CXColor.tagImigracao
    }

    /// Color tint for a connection identifier (channel inference).
    static func cxChannel(forConnectionID raw: String) -> Color {
        let s = raw.lowercased()
        if s.contains("telegram")     { return CXColor.chTelegram }
        if s.contains("instagram") || s.contains("ig") { return CXColor.chInstagram }
        if s.contains("evolution") || s.contains("whats") || s.contains("wa") { return CXColor.chWhatsapp }
        if s.contains("mail") || s.contains("email")   { return CXColor.chEmail }
        if s.contains("sms")          { return CXColor.chSMS }
        return CXColor.chWhatsapp
    }

    /// Stable avatar background colour from a hash of the title (oklch(0.78 0.06 hue) approximated).
    static func cxAvatar(for name: String) -> Color {
        var h: Int = 0
        for u in name.unicodeScalars { h = h &* 31 &+ Int(u.value) }
        let hue = Double(abs(h) % 360)
        // Approximate oklch(0.78 0.06 hue) as HSB: keep desaturated, light.
        return Color(hue: hue / 360.0, saturation: 0.35, brightness: 0.78)
    }
}

// MARK: - Gradients

enum CXGradient {
    /// Outbound message bubble + primary button: linear-gradient(135deg, teal, indigo).
    static let bubbleOut = LinearGradient(
        colors: [CXColor.bubbleOutStart, CXColor.bubbleOutEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentButton = LinearGradient(
        colors: [CXColor.bubbleOutStart, CXColor.bubbleOutEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Rail logo "Cx": linear-gradient(135deg, teal, pinkish).
    static let railLogo = LinearGradient(
        colors: [CXColor.bubbleOutStart, Color(nsColor: NSColor(srgbRed: 0.85, green: 0.36, blue: 0.55, alpha: 1))],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Active chat row: 90deg accent-bg -> transparent.
    static let activeRow = LinearGradient(
        colors: [CXColor.accentBg, .clear],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let unread = LinearGradient(
        colors: [CXColor.accent, CXColor.accentEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let sidebarHeader = LinearGradient(
        colors: [CXColor.surface, CXColor.surface],
        startPoint: .top,
        endPoint: .bottom
    )

    static let chatListBg = LinearGradient(
        colors: [CXColor.surface, CXColor.surface],
        startPoint: .top,
        endPoint: .bottom
    )

    static let composerBg = LinearGradient(
        colors: [CXColor.composer, CXColor.composer],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Spacing & radius (Bold)

enum CXSize {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s8: CGFloat = 32

    static let rSm: CGFloat = CXRadius.sm
    static let rMd: CGFloat = CXRadius.md
    static let rLg: CGFloat = CXRadius.lg
    static let rXl: CGFloat = CXRadius.xl
    static let shellRadius: CGFloat = CXRadius.shell
}

enum CXRadius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 10     // buttons, inputs, icon-only
    static let lg: CGFloat = 12     // list items, cards
    static let xl: CGFloat = 16     // composer container
    static let bubble: CGFloat = 22 // pill bubbles
    static let full: CGFloat = 999
    static let shell: CGFloat = 14  // outer window shell
}

enum CXShadow {
    static let card = Shadow(radius: 1, x: 0, y: 1, opacity: 0.06)
    static let s1   = Shadow(radius: 2, x: 0, y: 1, opacity: 0.12)
    static let s2   = Shadow(radius: 12, x: 0, y: 4, opacity: 0.18)
    static let s3   = Shadow(radius: 32, x: 0, y: 12, opacity: 0.24)
    static let me   = Shadow(radius: 20, x: 0, y: 4, opacity: 0.35)   // -8px y-offset compensated
    static let float = Shadow(radius: 40, x: 0, y: 12, opacity: 0.25)
    static let shell = Shadow(radius: 44, x: 0, y: 24, opacity: 0.30)

    struct Shadow {
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
        let opacity: Double
    }
}

// MARK: - Typography (Bold: system-ui, scale per spec section 3)

enum CXFont {
    static func micro(_ weight: Font.Weight = .bold) -> Font  { .system(size: 10.5, weight: weight) }
    static func small(_ weight: Font.Weight = .regular) -> Font { .system(size: 12, weight: weight) }
    static func body(_ size: CGFloat = 14, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    static func bodyStrong(_ size: CGFloat = 14) -> Font { .system(size: size, weight: .semibold) }
    static func h2() -> Font      { .system(size: 18, weight: .bold) }
    static func h1() -> Font      { .system(size: 22, weight: .bold) }
    static func display() -> Font { .system(size: 32, weight: .bold) }
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

    /// Outbound bubble glow: 0 4px 20px -8px var(--accent).
    func cxAccentGlow(_ opacity: Double = 0.35) -> some View {
        self.shadow(color: CXColor.accent.opacity(opacity), radius: 20, x: 0, y: 4)
    }

    /// UPPERCASE micro-section label.
    func cxMicroLabel() -> some View {
        self
            .font(CXFont.micro(.bold))
            .tracking(0.8)
            .foregroundStyle(CXColor.textMute)
            .textCase(.uppercase)
    }
}
