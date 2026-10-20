import XCTest
@testable import 一键日历

@MainActor
final class CalendarEventGroupingTests: XCTestCase {
    func testSpanningEventAppearsOnEveryCoveredDay() {
        let span = event(
            id: "span",
            title: "跨天",
            start: dateTime(2026, 10, 1, 22, 0),
            end: dateTime(2026, 10, 3, 1, 0),
            isAllDay: false
        )
        let endsAtMidnight = event(
            id: "cut",
            title: "止于零点",
            start: dateTime(2026, 10, 1, 8, 0),
            end: date(2026, 10, 2),
            isAllDay: false
        )

        let grouped = CalendarEventGrouping.byDay([span, endsAtMidnight])

        XCTAssertEqual(
            Set(grouped.keys),
            [date(2026, 10, 1), date(2026, 10, 2), date(2026, 10, 3)]
        )
        XCTAssertEqual(Set(grouped[date(2026, 10, 1)]?.map(\.id) ?? []), ["span", "cut"])
        XCTAssertEqual(grouped[date(2026, 10, 2)]?.map(\.id), ["span"])
        XCTAssertEqual(grouped[date(2026, 10, 3)]?.map(\.id), ["span"])
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        dateTime(y, m, d, 0, 0)
    }

    private func dateTime(_ y: Int, _ m: Int, _ d: Int, _ hour: Int, _ minute: Int) -> Date {
        var components = DateComponents()
        components.year = y
        components.month = m
        components.day = d
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }

    private func event(
        id: String,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool
    ) -> CalendarEventInfo {
        CalendarEventInfo(
            id: id,
            title: title,
            start: start,
            end: end,
            isAllDay: isAllDay,
            notes: nil,
            calendarId: "outlook-default",
            calendarTitle: "日历",
            calendarSourceTitle: "Outlook",
            colorHex: "#0078D4"
        )
    }
}
