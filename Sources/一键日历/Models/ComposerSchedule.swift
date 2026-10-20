import Foundation

enum ComposerPresetSelection: Equatable {
    case classic
    case exam
    case daily
    case custom(name: String?)
}

enum ComposerSchedule {
    static func presetSelection(intervals: [Int], savedPresets: [CustomPreset]) -> ComposerPresetSelection {
        if let preset = IntervalPreset.allCases.first(where: { $0.intervals == intervals }) {
            switch preset {
            case .classic:
                return .classic
            case .exam:
                return .exam
            case .daily:
                return .daily
            }
        }
        return .custom(name: savedPresets.first { $0.intervals == intervals }?.name)
    }
}
