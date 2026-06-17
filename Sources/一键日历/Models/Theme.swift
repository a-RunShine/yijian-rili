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

    /// 系统 ColorScheme，nil 表示跟随系统外观
    var colorScheme: ColorScheme? {
        switch self {
        case .light, .letterPaper, .claude: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    /// 卡片背景色（非 Optional，所有主题都有）
    var cardBackgroundColor: Color {
        switch self {
        case .light: return Color.secondary.opacity(0.1)
        case .dark: return Color.secondary.opacity(0.15)
        case .letterPaper: return Color(red: 0.91, green: 0.86, blue: 0.78).opacity(0.5)
        case .claude: return Color(red: 0.980, green: 0.976, blue: 0.961)
        case .system: return Color.secondary.opacity(0.1)
        }
    }

    /// 窗口背景色，nil 表示使用系统默认
    var windowBackgroundColor: Color? {
        switch self {
        case .light, .dark, .system: return nil
        case .letterPaper: return Color(red: 0.99, green: 0.97, blue: 0.91)
        case .claude: return Color(red: 0.941, green: 0.933, blue: 0.902)
        }
    }

    /// 强调色，nil 表示使用系统 .accentColor
    var accentColor: Color? {
        switch self {
        case .light, .dark, .letterPaper, .system: return nil
        case .claude: return Color(red: 0.851, green: 0.467, blue: 0.341)
        }
    }

    /// 主文字色，nil 表示使用系统 .primary
    var primaryTextColor: Color? {
        switch self {
        case .light, .dark, .letterPaper, .system: return nil
        case .claude: return Color(red: 0.176, green: 0.165, blue: 0.149)
        }
    }

    /// 次要文字色，nil 表示使用系统 .secondary
    var secondaryTextColor: Color? {
        switch self {
        case .light, .dark, .letterPaper, .system: return nil
        case .claude: return Color(red: 0.420, green: 0.420, blue: 0.420)
        }
    }
}
