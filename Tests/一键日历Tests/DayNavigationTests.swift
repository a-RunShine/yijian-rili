import XCTest
@testable import 一键日历

final class DayNavigationTests: XCTestCase {
    func testArrowLeftFromOctober20LandsOnOctober19() {
        let landed = DayNavigation.day(from: day(2026, 10, 20), step: .previousDay)

        XCTAssertEqual(iso(landed), "2026-10-19")
    }

    func testArrowRightFromOctober20LandsOnOctober21() {
        let landed = DayNavigation.day(from: day(2026, 10, 20), step: .nextDay)

        XCTAssertEqual(iso(landed), "2026-10-21")
    }

    func testArrowUpFromOctober20LandsOnOctober13() {
        let landed = DayNavigation.day(from: day(2026, 10, 20), step: .previousWeek)

        XCTAssertEqual(iso(landed), "2026-10-13")
    }

    func testArrowDownFromOctober20LandsOnOctober27() {
        let landed = DayNavigation.day(from: day(2026, 10, 20), step: .nextWeek)

        XCTAssertEqual(iso(landed), "2026-10-27")
    }

    func testArrowLeftFromOctober1LandsOnSeptember30() {
        let landed = DayNavigation.day(from: day(2026, 10, 1), step: .previousDay)

        XCTAssertEqual(iso(landed), "2026-09-30")
    }

    func testArrowRightFromOctober31LandsOnNovember1() {
        let landed = DayNavigation.day(from: day(2026, 10, 31), step: .nextDay)

        XCTAssertEqual(iso(landed), "2026-11-01")
    }

    func testArrowUpFromJanuary3LandsOnDecember27() {
        let landed = DayNavigation.day(from: day(2026, 1, 3), step: .previousWeek)

        XCTAssertEqual(iso(landed), "2025-12-27")
    }

    func testArrowDownFromDecember28LandsOnJanuary4() {
        let landed = DayNavigation.day(from: day(2025, 12, 28), step: .nextWeek)

        XCTAssertEqual(iso(landed), "2026-01-04")
    }

    func testArrowRightFromAnAfternoonLandsOnTheNextCalendarDay() {
        let landed = DayNavigation.day(from: day(2026, 10, 20, hour: 15), step: .nextDay)

        XCTAssertEqual(iso(landed), "2026-10-21")
        XCTAssertEqual(landed, day(2026, 10, 21))
    }

    private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        WeekCalculator.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func iso(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = WeekCalculator.calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = WeekCalculator.calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
