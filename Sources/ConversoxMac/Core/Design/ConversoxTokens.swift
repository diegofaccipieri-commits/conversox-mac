import SwiftUI

enum CXColor {
    static let bg = Color(red: 15 / 255, green: 23 / 255, blue: 42 / 255)
    static let surface = Color(red: 30 / 255, green: 41 / 255, blue: 59 / 255)
    static let surface2 = Color(red: 13 / 255, green: 20 / 255, blue: 39 / 255)
    static let surface3 = Color(red: 16 / 255, green: 25 / 255, blue: 46 / 255)
    static let composer = Color(red: 18 / 255, green: 29 / 255, blue: 49 / 255)
    static let input = Color(red: 15 / 255, green: 23 / 255, blue: 42 / 255)
    static let border = Color(red: 29 / 255, green: 41 / 255, blue: 67 / 255)
    static let borderLight = Color(red: 39 / 255, green: 53 / 255, blue: 82 / 255)
    static let text = Color(red: 226 / 255, green: 232 / 255, blue: 240 / 255)
    static let textSoft = Color(red: 203 / 255, green: 213 / 255, blue: 225 / 255)
    static let textMute = Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255)
    static let accent = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255)
    static let accentStrong = Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255)
    static let accentBg = Color(red: 30 / 255, green: 58 / 255, blue: 102 / 255)
    static let bubbleIn = Color(red: 24 / 255, green: 30 / 255, blue: 46 / 255)
    static let bubbleInText = Color(red: 219 / 255, green: 234 / 255, blue: 254 / 255)
    static let bubbleOutStart = Color(red: 42 / 255, green: 93 / 255, blue: 154 / 255)
    static let bubbleOutEnd = Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255)
    static let bubbleOutText = Color(red: 239 / 255, green: 246 / 255, blue: 255 / 255)
    static let waGreen = Color(red: 37 / 255, green: 211 / 255, blue: 102 / 255)
    static let success = Color(red: 16 / 255, green: 185 / 255, blue: 129 / 255)
    static let warning = Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255)
    static let danger = Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255)
    static let note = Color(red: 250 / 255, green: 204 / 255, blue: 21 / 255)
    static let checkRead = Color(red: 56 / 255, green: 189 / 255, blue: 248 / 255)
}

enum CXSize {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let rSm: CGFloat = 6
    static let rMd: CGFloat = 10
    static let rLg: CGFloat = 14
    static let rXl: CGFloat = 20
    static let shellRadius: CGFloat = 24
}

extension View {
    func cxShellPanel() -> some View {
        self
            .background(CXColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 0, style: .continuous)
                    .stroke(CXColor.border, lineWidth: 1)
            )
    }
}
