import XCTest
@testable import 一键日历

final class ComposerScheduleTests: XCTestCase {
    func testBuiltinIntervalsSelectTheMatchingPresetAheadOfASavedCopy() {
        let saved = CustomPreset(name: "我的经典", intervals: [1, 2, 4, 7, 15])

        XCTAssertEqual(
            ComposerSchedule.presetSelection(intervals: [1, 2, 4, 7, 15], savedPresets: [saved]),
            .classic
        )
        XCTAssertEqual(
            ComposerSchedule.presetSelection(intervals: [1, 3, 7], savedPresets: []),
            .exam
        )
        XCTAssertEqual(
            ComposerSchedule.presetSelection(intervals: [3, 7, 30], savedPresets: []),
            .daily
        )
    }

    func testSavedPresetNameIsShownWhenIntervalsMatchNeitherBuiltin() {
        let other = CustomPreset(name: "其他", intervals: [4, 8])
        let sprint = CustomPreset(name: "冲刺前", intervals: [2, 5, 9])

        XCTAssertEqual(
            ComposerSchedule.presetSelection(intervals: [2, 5, 9], savedPresets: [other, sprint]),
            .custom(name: "冲刺前")
        )
        XCTAssertEqual(
            ComposerSchedule.presetSelection(intervals: [2, 5], savedPresets: [other]),
            .custom(name: nil)
        )
    }
}
