import XCTest
@testable import 一键日历

@MainActor
final class DayEventProjectionTests: XCTestCase {
    func testReviewSeriesMemberProjectsAsSeriesWithAllExistingMembers() {
        let day = date(2026, 2, 3)
        let e1 = event(id: "e1", title: "Swift", start: day)
        let e2 = event(id: "e2", title: "Swift", start: date(2026, 2, 7))
        let e3 = event(id: "e3", title: "Swift", start: date(2026, 3, 2))
        let catalog: [String: CalendarEventInfo] = ["e1": e1, "e2": e2, "e3": e3]
        let historyID = UUID()
        let history = [
            HistoryEntry(
                id: historyID,
                title: "Swift",
                baseDate: date(2026, 1, 31),
                reviewDates: [day, date(2026, 2, 7), date(2026, 3, 2)],
                creationDate: Date(),
                type: .review,
                createdEventIdentifiers: ["e1", "e2", "e3"],
                sharedDetail: "要点"
            )
        ]

        let rows = DayEventProjection.project(
            dayEvents: [e1],
            history: history,
            candidates: [],
            eventById: { catalog[$0] }
        )

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].id, "e1")
        XCTAssertTrue(rows[0].isSeries)
        XCTAssertEqual(rows[0].kind, .series(historyEntryID: historyID))
        XCTAssertEqual(rows[0].title, "Swift")
        XCTAssertEqual(rows[0].members.map(\.id), ["e1", "e2", "e3"])
        XCTAssertTrue(rows[0].asksForDeleteScope)
        XCTAssertEqual(rows[0].focusedEvent?.id, "e1")
    }

    func testUnmatchedAndHolidayProjectAsSingle() {
        let holiday = event(id: "holiday-1", title: "国庆节", start: date(2026, 10, 1))
        let rows = DayEventProjection.project(
            dayEvents: [holiday],
            history: [],
            candidates: [],
            eventById: { _ in nil }
        )

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].id, "holiday-1")
        XCTAssertFalse(rows[0].isSeries)
        XCTAssertEqual(rows[0].kind, .single)
        XCTAssertEqual(rows[0].members.map(\.id), ["holiday-1"])
        XCTAssertFalse(rows[0].asksForDeleteScope)
    }

    func testSingleScheduleHistoryDoesNotBecomeSeries() {
        let day = date(2026, 3, 1)
        let single = event(id: "s1", title: "会议", start: day)
        let history = [
            HistoryEntry(
                title: "会议",
                baseDate: day,
                reviewDates: [day],
                creationDate: Date(),
                type: .single,
                createdEventIdentifiers: ["s1"]
            )
        ]

        let rows = DayEventProjection.project(
            dayEvents: [single],
            history: history,
            candidates: [],
            eventById: { $0 == "s1" ? single : nil }
        )

        XCTAssertEqual(rows.count, 1)
        XCTAssertFalse(rows[0].isSeries)
        XCTAssertEqual(rows[0].kind, .single)
    }

    func testSameDayMultipleMembersStayOneRowEach() {
        let day = date(2026, 2, 3)
        let morning = event(id: "m1", title: "Swift", start: day)
        let evening = CalendarEventInfo(
            id: "m2",
            title: "Swift",
            start: Calendar.current.date(byAdding: .hour, value: 8, to: day)!,
            end: Calendar.current.date(byAdding: .hour, value: 9, to: day)!,
            isAllDay: false,
            notes: "第2次复习",
            calendarId: "cal",
            calendarTitle: "日历",
            calendarSourceTitle: "本地",
            colorHex: "#0078D4"
        )
        let later = event(id: "m3", title: "Swift", start: date(2026, 2, 10))
        let catalog: [String: CalendarEventInfo] = ["m1": morning, "m2": evening, "m3": later]
        let historyID = UUID()
        let history = [
            HistoryEntry(
                id: historyID,
                title: "Swift",
                baseDate: date(2026, 1, 31),
                reviewDates: [day, day, date(2026, 2, 10)],
                creationDate: Date(),
                type: .review,
                createdEventIdentifiers: ["m1", "m2", "m3"]
            )
        ]

        let rows = DayEventProjection.project(
            dayEvents: [morning, evening],
            history: history,
            candidates: [],
            eventById: { catalog[$0] }
        )

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows.map(\.id), ["m1", "m2"])
        XCTAssertTrue(rows.allSatisfy(\.isSeries))
        XCTAssertEqual(rows[0].members.map(\.id), ["m1", "m2", "m3"])
        XCTAssertEqual(rows[1].members.map(\.id), ["m1", "m2", "m3"])
        XCTAssertEqual(rows[0].focusedEvent?.id, "m1")
        XCTAssertEqual(rows[1].focusedEvent?.id, "m2")
    }

    func testMissingMemberIdsAreOmittedFromSeriesMembers() {
        let day = date(2026, 2, 3)
        let e1 = event(id: "e1", title: "Swift", start: day)
        let e3 = event(id: "e3", title: "Swift", start: date(2026, 3, 2))
        let catalog: [String: CalendarEventInfo] = ["e1": e1, "e3": e3]
        let history = [
            HistoryEntry(
                title: "Swift",
                baseDate: date(2026, 1, 31),
                reviewDates: [day, date(2026, 2, 7), date(2026, 3, 2)],
                creationDate: Date(),
                type: .review,
                createdEventIdentifiers: ["e1", "e2", "e3"]
            )
        ]

        let rows = DayEventProjection.project(
            dayEvents: [e1],
            history: history,
            candidates: [],
            eventById: { catalog[$0] }
        )

        XCTAssertEqual(rows[0].members.map(\.id), ["e1", "e3"])
        XCTAssertTrue(rows[0].asksForDeleteScope)
    }

    private func event(id: String, title: String, start: Date) -> CalendarEventInfo {
        CalendarEventInfo(
            id: id,
            title: title,
            start: start,
            end: start,
            isAllDay: true,
            notes: nil,
            calendarId: "cal",
            calendarTitle: "日历",
            calendarSourceTitle: "本地",
            colorHex: "#0078D4"
        )
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.year = y
        c.month = m
        c.day = d
        return Calendar.current.date(from: c)!
    }
}
