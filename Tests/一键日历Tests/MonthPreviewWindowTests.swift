import XCTest
@testable import 一键日历

final class MonthPreviewWindowTests: XCTestCase {
    func testOctober2026DailyPreviewLeavesNovember19InTheNextMonth() {
        let overflow = MonthPreviewWindow.overflow(
            reviewDates: [
                day(2026, 10, 23),
                day(2026, 10, 27),
                day(2026, 11, 19),
            ],
            visibleMonth: day(2026, 10, 1)
        )

        XCTAssertEqual(overflow, .nextMonth(1))
    }

    func testPreviewDaysPastTheNextMonthAreOutsideTheWindow() {
        let overflow = MonthPreviewWindow.overflow(
            reviewDates: [
                day(2026, 10, 23),
                day(2026, 11, 19),
                day(2026, 12, 19),
            ],
            visibleMonth: day(2026, 10, 1)
        )

        XCTAssertEqual(overflow, .outsideWindow(2))
    }

    func testPreviewDayBeforeTheNovemberGridIsOutsideTheWindow() {
        let overflow = MonthPreviewWindow.overflow(
            reviewDates: [
                day(2026, 10, 23),
                day(2026, 10, 27),
                day(2026, 11, 19),
            ],
            visibleMonth: day(2026, 11, 1)
        )

        XCTAssertEqual(overflow, .outsideWindow(1))
    }

    func testTwoNovemberDaysPastTheOctoberGridCountAsNextMonth() {
        let overflow = MonthPreviewWindow.overflow(
            reviewDates: [
                day(2026, 11, 19),
                day(2026, 11, 25, hour: 15),
            ],
            visibleMonth: day(2026, 10, 20)
        )

        XCTAssertEqual(overflow, .nextMonth(2))
    }

    func testDuplicatePreviewDayOutsideTheGridCountsOnce() {
        let overflow = MonthPreviewWindow.overflow(
            reviewDates: [
                day(2026, 11, 19),
                day(2026, 11, 19, hour: 18),
            ],
            visibleMonth: day(2026, 10, 1)
        )

        XCTAssertEqual(overflow, .nextMonth(1))
    }

    func testPreviewDaysInsideTheFortyTwoCellsHaveNoOverflow() {
        let overflow = MonthPreviewWindow.overflow(
            reviewDates: [
                day(2026, 10, 23),
                day(2026, 10, 27),
                day(2026, 11, 8),
            ],
            visibleMonth: day(2026, 10, 1)
        )

        XCTAssertEqual(overflow, .none)
    }

    func testJanuaryDayAfterTheDecemberGridIsNextMonth() {
        let overflow = MonthPreviewWindow.overflow(
            reviewDates: [day(2027, 1, 20)],
            visibleMonth: day(2026, 12, 1)
        )

        XCTAssertEqual(overflow, .nextMonth(1))
    }

    func testOrdinalsFollowReviewDateOrderKeyedByStartOfDay() {
        let ordinals = MonthPreviewWindow.ordinals(for: [
            day(2026, 10, 23, hour: 8),
            day(2026, 10, 27),
            day(2026, 11, 19),
        ])

        XCTAssertEqual(ordinals[day(2026, 10, 23)], 1)
        XCTAssertEqual(ordinals[day(2026, 10, 27)], 2)
        XCTAssertEqual(ordinals[day(2026, 11, 19)], 3)
        XCTAssertEqual(ordinals.count, 3)
    }

    func testDuplicateReviewDayKeepsTheEarlierOrdinal() {
        let ordinals = MonthPreviewWindow.ordinals(for: [
            day(2026, 10, 23),
            day(2026, 10, 23, hour: 12),
            day(2026, 10, 27),
        ])

        XCTAssertEqual(ordinals[day(2026, 10, 23)], 1)
        XCTAssertEqual(ordinals[day(2026, 10, 27)], 3)
        XCTAssertEqual(ordinals.count, 2)
    }

    func testPreviewShadeStartsAtFourteenPercentAndCapsAtForty() {
        XCTAssertEqual(MonthPreviewWindow.shadeOpacity(forOrdinal: 1), 0.14, accuracy: 0.001)
        XCTAssertEqual(MonthPreviewWindow.shadeOpacity(forOrdinal: 2), 0.18, accuracy: 0.001)
        XCTAssertEqual(MonthPreviewWindow.shadeOpacity(forOrdinal: 7), 0.38, accuracy: 0.001)
        XCTAssertEqual(MonthPreviewWindow.shadeOpacity(forOrdinal: 8), 0.40, accuracy: 0.001)
        XCTAssertEqual(MonthPreviewWindow.shadeOpacity(forOrdinal: 9), 0.40, accuracy: 0.001)
    }

    private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        WeekCalculator.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
