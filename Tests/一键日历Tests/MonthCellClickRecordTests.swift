import XCTest
@testable import 一键日历

final class MonthCellClickRecordTests: XCTestCase {
    private let threshold: TimeInterval = 0.5

    func testFirstClickIsImmediateAndStartsThePairing() throws {
        let day = Date(timeIntervalSince1970: 1_800_000_000)

        let outcome = MonthCellClickRecord.register(
            previous: nil,
            day: day,
            at: day,
            within: threshold
        )

        XCTAssertFalse(outcome.isRepeated)
        XCTAssertEqual(try XCTUnwrap(outcome.next).day, day)
    }

    func testSecondClickOnTheSameDayInsideTheIntervalIsARepeat() throws {
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        let first = MonthCellClickRecord.register(previous: nil, day: day, at: day, within: threshold)

        let second = MonthCellClickRecord.register(
            previous: first.next,
            day: day,
            at: day.addingTimeInterval(0.2),
            within: threshold
        )

        XCTAssertTrue(second.isRepeated)
        XCTAssertNil(second.next)
    }

    func testRepeatConsumesThePairingSoTheNextClickSelectsAgain() throws {
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        let first = MonthCellClickRecord.register(previous: nil, day: day, at: day, within: threshold)
        let second = MonthCellClickRecord.register(
            previous: first.next,
            day: day,
            at: day.addingTimeInterval(0.2),
            within: threshold
        )

        let third = MonthCellClickRecord.register(
            previous: second.next,
            day: day,
            at: day.addingTimeInterval(0.3),
            within: threshold
        )

        XCTAssertFalse(third.isRepeated)
        XCTAssertEqual(try XCTUnwrap(third.next).day, day)
    }

    func testClickOnAnotherDayStartsAFreshPairing() throws {
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        let other = day.addingTimeInterval(86_400)
        let first = MonthCellClickRecord.register(previous: nil, day: day, at: day, within: threshold)

        let second = MonthCellClickRecord.register(
            previous: first.next,
            day: other,
            at: day.addingTimeInterval(0.1),
            within: threshold
        )

        XCTAssertFalse(second.isRepeated)
        XCTAssertEqual(try XCTUnwrap(second.next).day, other)
    }

    func testSameDayClickOutsideTheIntervalIsNotARepeat() throws {
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        let first = MonthCellClickRecord.register(previous: nil, day: day, at: day, within: threshold)

        let second = MonthCellClickRecord.register(
            previous: first.next,
            day: day,
            at: day.addingTimeInterval(threshold + 0.01),
            within: threshold
        )

        XCTAssertFalse(second.isRepeated)
        XCTAssertEqual(try XCTUnwrap(second.next).day, day)
    }
}
