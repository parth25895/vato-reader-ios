import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

struct Palette {
    let bg: UIColor
    let surface: UIColor
    let surface2: UIColor
    let ink: UIColor
    let muted: UIColor
    let line: UIColor
    let accent: UIColor
    let accentInk: UIColor
    let gold: UIColor
    let danger: UIColor
    let hl: [String: UIColor]
    let isDark: Bool

    var cBg: Color { Color(uiColor: bg) }
    var cSurface: Color { Color(uiColor: surface) }
    var cSurface2: Color { Color(uiColor: surface2) }
    var cInk: Color { Color(uiColor: ink) }
    var cMuted: Color { Color(uiColor: muted) }
    var cLine: Color { Color(uiColor: line) }
    var cAccent: Color { Color(uiColor: accent) }
    var cAccentInk: Color { Color(uiColor: accentInk) }
    var cGold: Color { Color(uiColor: gold) }
    var cDanger: Color { Color(uiColor: danger) }

    func hlColor(_ c: String) -> UIColor { hl[c] ?? hl["y"]! }

    static let lightHL: [String: UIColor] = ["y": UIColor(hex: 0xF7DE7E), "g": UIColor(hex: 0xBFE3B4), "p": UIColor(hex: 0xF5C3CF), "b": UIColor(hex: 0xBFD9F2)]
    static let darkHL: [String: UIColor] = ["y": UIColor(hex: 0x6B5814), "g": UIColor(hex: 0x245636), "p": UIColor(hex: 0x6B2C42), "b": UIColor(hex: 0x23496E)]

    // App default: ivory and bronze by day, midnight and gold by night
    static let ivory = Palette(bg: UIColor(hex: 0xF6F1E7), surface: UIColor(hex: 0xFFFCF6), surface2: UIColor(hex: 0xEFE6D6), ink: UIColor(hex: 0x1F1A14), muted: UIColor(hex: 0x7A6E5E), line: UIColor(hex: 0xE4D9C6), accent: UIColor(hex: 0x8E5A24), accentInk: .white, gold: UIColor(hex: 0xB88A3E), danger: UIColor(hex: 0xA8321E), hl: lightHL, isDark: false)
    static let midnight = Palette(bg: UIColor(hex: 0x0D0E11), surface: UIColor(hex: 0x17191E), surface2: UIColor(hex: 0x21242B), ink: UIColor(hex: 0xEDE7DB), muted: UIColor(hex: 0x9B9486), line: UIColor(hex: 0x2B2E36), accent: UIColor(hex: 0xD9B46E), accentInk: UIColor(hex: 0x16120B), gold: UIColor(hex: 0xD9B46E), danger: UIColor(hex: 0xFF8A7A), hl: darkHL, isDark: true)

    static let paper = Palette(bg: UIColor(hex: 0xF7F1E3), surface: UIColor(hex: 0xFBF7EC), surface2: UIColor(hex: 0xEFE6D2), ink: UIColor(hex: 0x2B2620), muted: UIColor(hex: 0x6B6254), line: UIColor(hex: 0xE2D8C2), accent: UIColor(hex: 0x7A4B1E), accentInk: .white, gold: UIColor(hex: 0xB0823A), danger: UIColor(hex: 0xA8281E), hl: lightHL, isDark: false)
    static let sepia = Palette(bg: UIColor(hex: 0xEFE3C8), surface: UIColor(hex: 0xF5EBD4), surface2: UIColor(hex: 0xE6D7B6), ink: UIColor(hex: 0x3A2F22), muted: UIColor(hex: 0x7A6A52), line: UIColor(hex: 0xD9C9A5), accent: UIColor(hex: 0x8A5A24), accentInk: .white, gold: UIColor(hex: 0xA77B33), danger: UIColor(hex: 0xA8281E), hl: lightHL, isDark: false)
    static let grey = Palette(bg: UIColor(hex: 0xECEDEA), surface: UIColor(hex: 0xF5F6F3), surface2: UIColor(hex: 0xE2E4DF), ink: UIColor(hex: 0x222426), muted: UIColor(hex: 0x62666A), line: UIColor(hex: 0xD6D8D3), accent: UIColor(hex: 0x3E5A7A), accentInk: .white, gold: UIColor(hex: 0x8A7448), danger: UIColor(hex: 0xB3261E), hl: lightHL, isDark: false)
    static let dusk = Palette(bg: UIColor(hex: 0x2A2A2E), surface: UIColor(hex: 0x333338), surface2: UIColor(hex: 0x3C3C42), ink: UIColor(hex: 0xDDD8CC), muted: UIColor(hex: 0xA39F94), line: UIColor(hex: 0x45454B), accent: UIColor(hex: 0xE0B97A), accentInk: UIColor(hex: 0x2A2A2E), gold: UIColor(hex: 0xE0B97A), danger: UIColor(hex: 0xFF8A80), hl: darkHL, isDark: true)
    static let night = Palette(bg: UIColor(hex: 0x0B0B0B), surface: UIColor(hex: 0x161616), surface2: UIColor(hex: 0x1F1F1F), ink: UIColor(hex: 0xC9C4B8), muted: UIColor(hex: 0x8E8A80), line: UIColor(hex: 0x2A2A2A), accent: UIColor(hex: 0xD9B36F), accentInk: UIColor(hex: 0x121212), gold: UIColor(hex: 0xD9B36F), danger: UIColor(hex: 0xFF8A80), hl: darkHL, isDark: true)

    static func resolve(rbg: String, scheme: ColorScheme) -> Palette {
        switch rbg {
        case "paper": return .paper
        case "sepia": return .sepia
        case "grey": return .grey
        case "dusk": return .dusk
        case "night": return .night
        default: return scheme == .dark ? .midnight : .ivory
        }
    }
}

struct BackgroundOption: Identifiable {
    let id: String
    let name: String
    let bg: UInt32?
    let ink: UInt32?
}

let backgroundOptions: [BackgroundOption] = [
    .init(id: "app", name: "Ivory / Midnight", bg: nil, ink: nil),
    .init(id: "paper", name: "Paper", bg: 0xF7F1E3, ink: 0x2B2620),
    .init(id: "sepia", name: "Sepia", bg: 0xEFE3C8, ink: 0x3A2F22),
    .init(id: "grey", name: "Soft grey", bg: 0xECEDEA, ink: 0x222426),
    .init(id: "dusk", name: "Dusk", bg: 0x2A2A2E, ink: 0xDDD8CC),
    .init(id: "night", name: "Night", bg: 0x0B0B0B, ink: 0xC9C4B8),
]

struct ReadingFont: Identifiable {
    let id: String
    let name: String
    let ps: String
    let scale: CGFloat
}

let readingFonts: [ReadingFont] = [
    .init(id: "serif", name: "Noto Serif Gujarati", ps: "NotoSerifGujarati-Regular", scale: 1.0),
    .init(id: "rasa", name: "Rasa", ps: "Rasa-Regular", scale: 1.1),
    .init(id: "sans", name: "Noto Sans Gujarati", ps: "NotoSansGujarati-Regular", scale: 1.0),
    .init(id: "hind", name: "Hind Vadodara", ps: "HindVadodara-Regular", scale: 1.0),
    .init(id: "mukta", name: "Mukta Vaani", ps: "MuktaVaani-Regular", scale: 1.05),
    .init(id: "anek", name: "Anek Gujarati", ps: "AnekGujarati-Medium", scale: 1.0),
]

enum Typo {
    static func readingFont(_ id: String) -> ReadingFont { readingFonts.first { $0.id == id } ?? readingFonts[0] }

    static func uiFont(_ id: String, size: CGFloat) -> UIFont {
        let f = readingFont(id)
        return UIFont(name: f.ps, size: size * f.scale) ?? UIFont.systemFont(ofSize: size * f.scale)
    }
    static func font(_ id: String, size: CGFloat) -> Font {
        Font(uiFont(id, size: size))
    }
    /// Gujarati UI text (titles, list rows) in the user's chosen reading font.
    static func gu(_ store: Store, _ size: CGFloat) -> Font { font(store.s.rfont, size: size) }

    static let display = Font.system(size: 34, weight: .semibold, design: .serif)
    static let title = Font.system(size: 22, weight: .semibold, design: .serif)
    static let eyebrow = Font.system(size: 11.5, weight: .semibold).width(.expanded)
}

// MARK: - Environment

private struct PaletteKey: EnvironmentKey {
    static let defaultValue: Palette = .ivory
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

// MARK: - Reusable styling

struct CardBackground: ViewModifier {
    @Environment(\.palette) private var p
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(p.cSurface)
                    .shadow(color: .black.opacity(p.isDark ? 0.35 : 0.06), radius: 14, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(p.cLine.opacity(0.7), lineWidth: 0.5)
            )
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View { modifier(CardBackground(padding: padding)) }
}

struct Eyebrow: View {
    @Environment(\.palette) private var p
    let text: String
    init(_ t: String) { text = t }
    var body: some View {
        Text(text.uppercased())
            .font(Typo.eyebrow)
            .tracking(1.2)
            .foregroundStyle(p.cMuted)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.palette) private var p
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .foregroundStyle(p.cAccentInk)
            .background(
                Capsule().fill(LinearGradient(colors: [p.cAccent, p.cAccent.opacity(0.85)], startPoint: .top, endPoint: .bottom))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SoftButtonStyle: ButtonStyle {
    @Environment(\.palette) private var p
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(p.cInk)
            .background(Capsule().fill(p.cSurface2))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct ProgressRing: View {
    @Environment(\.palette) private var p
    var value: Double
    var lineWidth: CGFloat = 9
    var body: some View {
        ZStack {
            Circle().stroke(p.cLine, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, value)))
                .stroke(AngularGradient(colors: [p.cGold, p.cAccent, p.cGold], center: .center), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

struct Chip: View {
    @Environment(\.palette) private var p
    let text: String
    var on: Bool = false
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .foregroundStyle(on ? p.cAccentInk : p.cInk)
            .background(Capsule().fill(on ? p.cAccent : p.cSurface2))
    }
}

struct ToastView: View {
    @Environment(\.palette) private var p
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .foregroundStyle(p.cInk)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(p.cLine, lineWidth: 0.5))
            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
    }
}

struct ToastOverlay: ViewModifier {
    @Environment(Store.self) private var store
    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let t = store.toastText {
                ToastView(text: t)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(t)
            }
        }
        .animation(.spring(duration: 0.35), value: store.toastText)
    }
}

extension View {
    func toasts() -> some View { modifier(ToastOverlay()) }
}
