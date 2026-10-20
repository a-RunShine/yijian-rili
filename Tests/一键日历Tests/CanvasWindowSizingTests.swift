import XCTest
@testable import 一键日历

final class CanvasWindowSizingTests: XCTestCase {
    func testWideContentSizeKeepsTheWindowTopLeftWhenTheScreenFits() {
        let current = CGRect(x: 100, y: 300, width: 510, height: 700)
        let visible = CGRect(x: 0, y: 0, width: 1920, height: 1200)

        let result = CanvasWindowSizing.resize(
            windowFrame: current,
            titlebarHeight: 28,
            visibleFrame: visible,
            to: .wide
        )

        XCTAssertEqual(result.targetContentSize, CGSize(width: 1180, height: 760))
        XCTAssertEqual(result.contentSize, CGSize(width: 1180, height: 760))
        XCTAssertEqual(result.windowFrame, CGRect(x: 100, y: 212, width: 1180, height: 788))
        XCTAssertEqual(result.windowFrame.minX, current.minX)
        XCTAssertEqual(result.windowFrame.maxY, current.maxY)
        XCTAssertFalse(result.showsScreenTooNarrowHint)
    }

    func testCompactContentSizeKeepsTheWindowTopLeftWhenTheScreenFits() {
        let current = CGRect(x: 40, y: 200, width: 1180, height: 788)
        let visible = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        let result = CanvasWindowSizing.resize(
            windowFrame: current,
            titlebarHeight: 28,
            visibleFrame: visible,
            to: .compact
        )

        XCTAssertEqual(result.targetContentSize, CGSize(width: 420, height: 620))
        XCTAssertEqual(result.contentSize, CGSize(width: 420, height: 620))
        XCTAssertEqual(result.windowFrame, CGRect(x: 40, y: 340, width: 420, height: 648))
        XCTAssertEqual(result.windowFrame.minX, current.minX)
        XCTAssertEqual(result.windowFrame.maxY, current.maxY)
        XCTAssertFalse(result.showsScreenTooNarrowHint)
    }

    func testWideFrameShiftsLeftToStayInsideTheVisibleFrame() {
        let current = CGRect(x: 800, y: 200, width: 420, height: 648)
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 1000)

        let result = CanvasWindowSizing.resize(
            windowFrame: current,
            titlebarHeight: 28,
            visibleFrame: visible,
            to: .wide
        )

        XCTAssertEqual(result.targetContentSize, CGSize(width: 1180, height: 760))
        XCTAssertEqual(result.contentSize, CGSize(width: 1180, height: 760))
        XCTAssertEqual(result.windowFrame, CGRect(x: 260, y: 60, width: 1180, height: 788))
        XCTAssertEqual(result.windowFrame.maxY, current.maxY)
        XCTAssertFalse(result.showsScreenTooNarrowHint)
    }

    func testWideFrameShiftsUpWhenTheTallerWindowWouldLeaveTheScreen() {
        let current = CGRect(x: 50, y: 20, width: 420, height: 648)
        let visible = CGRect(x: 0, y: 0, width: 1600, height: 820)

        let result = CanvasWindowSizing.resize(
            windowFrame: current,
            titlebarHeight: 28,
            visibleFrame: visible,
            to: .wide
        )

        XCTAssertEqual(result.targetContentSize, CGSize(width: 1180, height: 760))
        XCTAssertEqual(result.contentSize, CGSize(width: 1180, height: 760))
        XCTAssertEqual(result.windowFrame, CGRect(x: 50, y: 0, width: 1180, height: 788))
        XCTAssertFalse(result.showsScreenTooNarrowHint)
    }

    func testWideFrameShrinksToTheVisibleHeightWhenTheScreenIsShorter() {
        let current = CGRect(x: 10, y: 20, width: 420, height: 648)
        let visible = CGRect(x: 0, y: 0, width: 1600, height: 700)

        let result = CanvasWindowSizing.resize(
            windowFrame: current,
            titlebarHeight: 28,
            visibleFrame: visible,
            to: .wide
        )

        XCTAssertEqual(result.targetContentSize, CGSize(width: 1180, height: 760))
        XCTAssertEqual(result.contentSize, CGSize(width: 1180, height: 672))
        XCTAssertEqual(result.windowFrame, CGRect(x: 10, y: 0, width: 1180, height: 700))
        XCTAssertFalse(result.showsScreenTooNarrowHint)
    }

    func testScreenExactly1024WideStillOpensTheWideCanvasClampedToTheScreen() {
        let current = CGRect(x: 0, y: 200, width: 420, height: 648)
        let visible = CGRect(x: 0, y: 0, width: 1024, height: 900)

        let result = CanvasWindowSizing.resize(
            windowFrame: current,
            titlebarHeight: 28,
            visibleFrame: visible,
            to: .wide
        )

        XCTAssertEqual(result.targetContentSize, CGSize(width: 1180, height: 760))
        XCTAssertEqual(result.contentSize, CGSize(width: 1024, height: 760))
        XCTAssertEqual(result.windowFrame, CGRect(x: 0, y: 60, width: 1024, height: 788))
        XCTAssertFalse(result.showsScreenTooNarrowHint)
    }

    func testScreenNarrowerThan1024KeepsTheCurrentFrameAndAsksForAHint() {
        let current = CGRect(x: 120, y: 200, width: 500, height: 700)
        let visible = CGRect(x: 0, y: 0, width: 1023, height: 800)

        let result = CanvasWindowSizing.resize(
            windowFrame: current,
            titlebarHeight: 28,
            visibleFrame: visible,
            to: .wide
        )

        XCTAssertTrue(result.showsScreenTooNarrowHint)
        XCTAssertEqual(result.windowFrame, current)
        XCTAssertEqual(result.contentSize, CGSize(width: 500, height: 672))
        XCTAssertEqual(result.targetContentSize, CGSize(width: 500, height: 672))
    }

    func testWideFrameMovesInsideAVisibleFrameThatDoesNotStartAtTheOrigin() {
        let current = CGRect(x: 80, y: 300, width: 420, height: 648)
        let visible = CGRect(x: 200, y: 40, width: 1500, height: 1000)

        let result = CanvasWindowSizing.resize(
            windowFrame: current,
            titlebarHeight: 28,
            visibleFrame: visible,
            to: .wide
        )

        XCTAssertEqual(result.windowFrame, CGRect(x: 200, y: 160, width: 1180, height: 788))
        XCTAssertEqual(result.contentSize, CGSize(width: 1180, height: 760))
        XCTAssertFalse(result.showsScreenTooNarrowHint)
    }

    func testWideFramePullsDownWhenTheCurrentTopSitsAboveTheVisibleFrame() {
        let current = CGRect(x: 100, y: 400, width: 420, height: 648)
        let visible = CGRect(x: 0, y: 0, width: 1920, height: 1000)

        let result = CanvasWindowSizing.resize(
            windowFrame: current,
            titlebarHeight: 28,
            visibleFrame: visible,
            to: .wide
        )

        XCTAssertEqual(result.windowFrame, CGRect(x: 100, y: 212, width: 1180, height: 788))
        XCTAssertEqual(result.windowFrame.maxY, visible.maxY)
        XCTAssertFalse(result.showsScreenTooNarrowHint)
    }

    func testCompactResizeStillRunsWhenTheScreenCannotFitTheWideCanvas() {
        let current = CGRect(x: 120, y: 200, width: 800, height: 700)
        let visible = CGRect(x: 0, y: 0, width: 900, height: 1000)

        let result = CanvasWindowSizing.resize(
            windowFrame: current,
            titlebarHeight: 28,
            visibleFrame: visible,
            to: .compact
        )

        XCTAssertEqual(result.targetContentSize, CGSize(width: 420, height: 620))
        XCTAssertEqual(result.contentSize, CGSize(width: 420, height: 620))
        XCTAssertEqual(result.windowFrame, CGRect(x: 120, y: 252, width: 420, height: 648))
        XCTAssertFalse(result.showsScreenTooNarrowHint)
    }
}
