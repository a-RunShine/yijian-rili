import SwiftUI

enum Theme: String, CaseIterable, Codable, Sendable {
    case light
    case dark
    case letterPaper
}

extension Theme {
    var displayName: String {
        switch self {
        case .light: return NSLocalizedString("theme_light", comment: "")
        case .dark: return NSLocalizedString("theme_dark", comment: "")
        case .letterPaper: return NSLocalizedString("theme_letter_paper", comment: "")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .letterPaper: return .light
        }
    }

    var cardBackgroundColor: Color {
        switch self {
        case .light: return Color.secondary.opacity(0.1)
        case .dark: return Color.secondary.opacity(0.15)
        case .letterPaper: return Color(red: 0.91, green: 0.86, blue: 0.78).opacity(0.5)
        }
    }

    var windowBackgroundColor: Color? {
        switch self {
        case .light, .dark: return nil
        case .letterPaper: return Color(red: 0.99, green: 0.97, blue: 0.91)
        }
    }
}