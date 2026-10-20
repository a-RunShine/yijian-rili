import AppKit
import SwiftUI

enum Theme: String, CaseIterable, Codable, Sendable {
    case light
    case dark
    case letterPaper
    case claude
    case system
}

extension Theme {
    var displayName: String {
        switch self {
        case .light: return NSLocalizedString("theme_light", comment: "")
        case .dark: return NSLocalizedString("theme_dark", comment: "")
        case .letterPaper: return NSLocalizedString("theme_letter_paper", comment: "")
        case .claude: return NSLocalizedString("theme_claude", comment: "")
        case .system: return NSLocalizedString("theme_system", comment: "")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light, .letterPaper, .claude: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    var cardBackgroundColor: Color {
        switch self {
        case .light: return Color.secondary.opacity(0.12)
        case .dark: return Color.secondary.opacity(0.18)
        case .letterPaper: return Color(red: 0.91, green: 0.86, blue: 0.78).opacity(0.5)
        case .claude: return Color(red: 0.980, green: 0.976, blue: 0.961)
        case .system: return Color.secondary.opacity(0.12)
        }
    }

    var windowBackgroundColor: Color? {
        switch self {
        case .light, .dark, .system: return nil
        case .letterPaper: return Color(red: 0.99, green: 0.97, blue: 0.91)
        case .claude: return Color(red: 0.941, green: 0.933, blue: 0.902)
        }
    }

    var accentColor: Color? {
        switch self {
        case .light, .dark, .letterPaper, .system: return nil
        case .claude: return Color(red: 0.851, green: 0.467, blue: 0.341)
        }
    }

    var primaryTextColor: Color? {
        switch self {
        case .light, .dark, .letterPaper, .system: return nil
        case .claude: return Color(red: 0.176, green: 0.165, blue: 0.149)
        }
    }

    var secondaryTextColor: Color? {
        switch self {
        case .light, .dark, .letterPaper, .system: return nil
        case .claude: return Color(red: 0.420, green: 0.420, blue: 0.420)
        }
    }

    var palette: ThemePalette {
        switch self {
        case .claude:
            return ThemePalette(
                background: rgb(0xF0EEE6),
                chrome: rgb(0xE9E5DB),
                card: rgb(0xFAF9F5),
                primary: rgb(0x2C2923),
                secondary: rgb(0x79746A),
                separator: rgb(0xDCD6C8),
                accent: rgb(0xD97757),
                onAccent: rgb(0x251610),
                chip: rgb(0xE7E2D7),
                hover: rgb(0xE2DDD1),
                success: rgb(0x2E6B52)
            )
        case .light:
            return ThemePalette(
                background: rgb(0xF5F5F7),
                chrome: rgb(0xECECEF),
                card: rgb(0xFFFFFF),
                primary: rgb(0x1D1D1F),
                secondary: rgb(0x7E7E83),
                separator: rgb(0xE1E1E5),
                accent: rgb(0x0A6CD6),
                onAccent: rgb(0xFFFFFF),
                chip: rgb(0xE7E7EA),
                hover: rgb(0xDEDEE2),
                success: rgb(0x1F7A4D)
            )
        case .dark:
            return ThemePalette(
                background: rgb(0x1B1B1D),
                chrome: rgb(0x232325),
                card: rgb(0x2A2A2D),
                primary: rgb(0xF2F2F7),
                secondary: rgb(0x9A9AA0),
                separator: rgb(0x3A3A3D),
                accent: rgb(0x409CFF),
                onAccent: rgb(0x06121F),
                chip: rgb(0x333336),
                hover: rgb(0x343437),
                success: rgb(0x5BC08C)
            )
        case .letterPaper:
            return ThemePalette(
                background: rgb(0xFCF7E8),
                chrome: rgb(0xF4EDD9),
                card: rgb(0xFAF2DF),
                primary: rgb(0x3B352A),
                secondary: rgb(0x7C7261),
                separator: rgb(0xE1D6BF),
                accent: rgb(0x8A6540),
                onAccent: rgb(0xFFF9EE),
                chip: rgb(0xEDE4D0),
                hover: rgb(0xE7DCC5),
                success: rgb(0x4A6B4F)
            )
        case .system:
            return ThemePalette(
                background: Color(nsColor: .windowBackgroundColor),
                chrome: Color(nsColor: .windowBackgroundColor),
                card: Color(nsColor: .controlBackgroundColor),
                primary: Color(nsColor: .labelColor),
                secondary: Color(nsColor: .secondaryLabelColor),
                separator: Color(nsColor: .separatorColor),
                accent: Color(nsColor: .controlAccentColor),
                onAccent: Color(nsColor: .alternateSelectedControlTextColor),
                chip: Color(nsColor: .controlBackgroundColor),
                hover: Color(nsColor: .unemphasizedSelectedContentBackgroundColor),
                success: Color(nsColor: .systemGreen)
            )
        }
    }
}

struct ThemePalette {
    let background: Color
    let chrome: Color
    let card: Color
    let primary: Color
    let secondary: Color
    let separator: Color
    let accent: Color
    let onAccent: Color
    let chip: Color
    let hover: Color
    let success: Color
}

private func rgb(_ hex: UInt32) -> Color {
    let red = Double((hex >> 16) & 0xFF) / 255
    let green = Double((hex >> 8) & 0xFF) / 255
    let blue = Double(hex & 0xFF) / 255
    return Color(red: red, green: green, blue: blue)
}
