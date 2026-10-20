import XCTest
@testable import 一键日历

final class MonthGeometryTests: XCTestCase {
    func testOctober2026HasFortyTwoCellsFromSeptember28ThroughNovember8() {
        let cells = MonthGrid.cells(in: day(2026, 10, 1), today: day(2000, 1, 1))

        XCTAssertEqual(cells.map(iso), [
            "2026-09-28",
            "2026-09-29",
            "2026-09-30",
            "2026-10-01",
            "2026-10-02",
            "2026-10-03",
            "2026-10-04",
            "2026-10-05",
            "2026-10-06",
            "2026-10-07",
            "2026-10-08",
            "2026-10-09",
            "2026-10-10",
            "2026-10-11",
            "2026-10-12",
            "2026-10-13",
            "2026-10-14",
            "2026-10-15",
            "2026-10-16",
            "2026-10-17",
            "2026-10-18",
            "2026-10-19",
            "2026-10-20",
            "2026-10-21",
            "2026-10-22",
            "2026-10-23",
            "2026-10-24",
            "2026-10-25",
            "2026-10-26",
            "2026-10-27",
            "2026-10-28",
            "2026-10-29",
            "2026-10-30",
            "2026-10-31",
            "2026-11-01",
            "2026-11-02",
            "2026-11-03",
            "2026-11-04",
            "2026-11-05",
            "2026-11-06",
            "2026-11-07",
            "2026-11-08",
        ])
    }

    func testLeapFebruary2024HasFortyTwoMondayFirstCells() {
        let cells = MonthGrid.cells(in: day(2024, 2, 1), today: day(2000, 1, 1))

        XCTAssertEqual(cells.map(iso), [
            "2024-01-29",
            "2024-01-30",
            "2024-01-31",
            "2024-02-01",
            "2024-02-02",
            "2024-02-03",
            "2024-02-04",
            "2024-02-05",
            "2024-02-06",
            "2024-02-07",
            "2024-02-08",
            "2024-02-09",
            "2024-02-10",
            "2024-02-11",
            "2024-02-12",
            "2024-02-13",
            "2024-02-14",
            "2024-02-15",
            "2024-02-16",
            "2024-02-17",
            "2024-02-18",
            "2024-02-19",
            "2024-02-20",
            "2024-02-21",
            "2024-02-22",
            "2024-02-23",
            "2024-02-24",
            "2024-02-25",
            "2024-02-26",
            "2024-02-27",
            "2024-02-28",
            "2024-02-29",
            "2024-03-01",
            "2024-03-02",
            "2024-03-03",
            "2024-03-04",
            "2024-03-05",
            "2024-03-06",
            "2024-03-07",
            "2024-03-08",
            "2024-03-09",
            "2024-03-10",
        ])
        XCTAssertEqual(cells.count, 42)
        for index in stride(from: 0, to: cells.count, by: 7) {
            XCTAssertEqual(WeekCalculator.calendar.component(.weekday, from: cells[index].date), 2)
        }
    }

    func testJuly2026HasFortyTwoMondayFirstCells() {
        let cells = MonthGrid.cells(in: day(2026, 7, 1), today: day(2000, 1, 1))

        XCTAssertEqual(cells.map(iso), [
            "2026-06-29",
            "2026-06-30",
            "2026-07-01",
            "2026-07-02",
            "2026-07-03",
            "2026-07-04",
            "2026-07-05",
            "2026-07-06",
            "2026-07-07",
            "2026-07-08",
            "2026-07-09",
            "2026-07-10",
            "2026-07-11",
            "2026-07-12",
            "2026-07-13",
            "2026-07-14",
            "2026-07-15",
            "2026-07-16",
            "2026-07-17",
            "2026-07-18",
            "2026-07-19",
            "2026-07-20",
            "2026-07-21",
            "2026-07-22",
            "2026-07-23",
            "2026-07-24",
            "2026-07-25",
            "2026-07-26",
            "2026-07-27",
            "2026-07-28",
            "2026-07-29",
            "2026-07-30",
            "2026-07-31",
            "2026-08-01",
            "2026-08-02",
            "2026-08-03",
            "2026-08-04",
            "2026-08-05",
            "2026-08-06",
            "2026-08-07",
            "2026-08-08",
            "2026-08-09",
        ])
        for index in stride(from: 0, to: cells.count, by: 7) {
            XCTAssertEqual(WeekCalculator.calendar.component(.weekday, from: cells[index].date), 2)
        }
    }

    func testDecember2026CrossesIntoJanuaryWithMondayFirstColumn() {
        let cells = MonthGrid.cells(in: day(2026, 12, 1), today: day(2000, 1, 1))

        XCTAssertEqual(cells.map(iso), [
            "2026-11-30",
            "2026-12-01",
            "2026-12-02",
            "2026-12-03",
            "2026-12-04",
            "2026-12-05",
            "2026-12-06",
            "2026-12-07",
            "2026-12-08",
            "2026-12-09",
            "2026-12-10",
            "2026-12-11",
            "2026-12-12",
            "2026-12-13",
            "2026-12-14",
            "2026-12-15",
            "2026-12-16",
            "2026-12-17",
            "2026-12-18",
            "2026-12-19",
            "2026-12-20",
            "2026-12-21",
            "2026-12-22",
            "2026-12-23",
            "2026-12-24",
            "2026-12-25",
            "2026-12-26",
            "2026-12-27",
            "2026-12-28",
            "2026-12-29",
            "2026-12-30",
            "2026-12-31",
            "2027-01-01",
            "2027-01-02",
            "2027-01-03",
            "2027-01-04",
            "2027-01-05",
            "2027-01-06",
            "2027-01-07",
            "2027-01-08",
            "2027-01-09",
            "2027-01-10",
        ])
        for index in stride(from: 0, to: cells.count, by: 7) {
            XCTAssertEqual(WeekCalculator.calendar.component(.weekday, from: cells[index].date), 2)
        }
    }

    func testOctoberCellsMarkDaysInsideAndOutsideTheDisplayedMonth() {
        let cells = MonthGrid.cells(in: day(2026, 10, 20), today: day(2000, 1, 1))

        XCTAssertEqual(iso(cells[0]), "2026-09-28")
        XCTAssertFalse(cells[0].isInDisplayedMonth)
        XCTAssertFalse(cells[2].isInDisplayedMonth)
        XCTAssertTrue(cells[3].isInDisplayedMonth)
        XCTAssertTrue(cells[33].isInDisplayedMonth)
        XCTAssertFalse(cells[34].isInDisplayedMonth)
        XCTAssertFalse(cells[41].isInDisplayedMonth)
        XCTAssertEqual(cells.filter(\.isInDisplayedMonth).count, 31)
    }

    func testLeapFebruaryMarksTwentyNineDaysInTheDisplayedMonth() {
        let cells = MonthGrid.cells(in: day(2024, 2, 15), today: day(2000, 1, 1))

        XCTAssertEqual(iso(cells[31]), "2024-02-29")
        XCTAssertTrue(cells[31].isInDisplayedMonth)
        XCTAssertFalse(cells[2].isInDisplayedMonth)
        XCTAssertFalse(cells[32].isInDisplayedMonth)
        XCTAssertEqual(cells.filter(\.isInDisplayedMonth).count, 29)
    }

    func testOnlyTheGivenCalendarDayIsToday() {
        let cells = MonthGrid.cells(in: day(2026, 10, 1), today: day(2026, 10, 20, hour: 23))

        XCTAssertEqual(iso(cells[22]), "2026-10-20")
        XCTAssertTrue(cells[22].isToday)
        XCTAssertFalse(cells[21].isToday)
        XCTAssertFalse(cells[23].isToday)
        XCTAssertEqual(cells.filter(\.isToday).count, 1)
    }

    func testNoCellIsTodayWhenThatDayIsOutsideTheGrid() {
        let cells = MonthGrid.cells(in: day(2026, 10, 1), today: day(2026, 11, 9))

        XCTAssertEqual(cells.filter(\.isToday).count, 0)
    }

    func testOutOfMonthCellCanStillBeToday() {
        let cells = MonthGrid.cells(in: day(2026, 10, 1), today: day(2026, 9, 28))

        XCTAssertEqual(iso(cells[0]), "2026-09-28")
        XCTAssertTrue(cells[0].isToday)
        XCTAssertFalse(cells[0].isInDisplayedMonth)
        XCTAssertEqual(cells.filter(\.isToday).count, 1)
    }

    func testSaturdayAndSundayCellsAreWeekends() {
        let cells = MonthGrid.cells(in: day(2026, 10, 1), today: day(2000, 1, 1))

        XCTAssertFalse(cells[0].isWeekend)
        XCTAssertFalse(cells[4].isWeekend)
        XCTAssertTrue(cells[5].isWeekend)
        XCTAssertTrue(cells[6].isWeekend)
        XCTAssertTrue(cells[41].isWeekend)
        XCTAssertEqual(cells.filter(\.isWeekend).count, 12)
    }

    func testWidthBelow1024IsCompactAnd1024IsWide() {
        XCTAssertEqual(CanvasBreakpoint.mode(forWidth: 1023), .compact)
        XCTAssertEqual(CanvasBreakpoint.mode(forWidth: 1024), .wide)
    }

    func testDecemberCellsKeepNextJanuaryOutOfTheDisplayedMonth() {
        let cells = MonthGrid.cells(in: day(2026, 12, 1), today: day(2000, 1, 1))

        XCTAssertEqual(iso(cells[0]), "2026-11-30")
        XCTAssertFalse(cells[0].isInDisplayedMonth)
        XCTAssertTrue(cells[1].isInDisplayedMonth)
        XCTAssertEqual(iso(cells[32]), "2027-01-01")
        XCTAssertFalse(cells[32].isInDisplayedMonth)
        XCTAssertEqual(cells.filter(\.isInDisplayedMonth).count, 31)
    }

    private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        WeekCalculator.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func iso(_ cell: MonthCell) -> String {
        let formatter = DateFormatter()
        formatter.calendar = WeekCalculator.calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = WeekCalculator.calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: cell.date)
    }
}
