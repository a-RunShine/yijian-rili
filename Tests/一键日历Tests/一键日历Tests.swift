import XCTest
@testable import 一键日历

final class 一键日历Tests: XCTestCase {
    func testDateCalculation() throws {
        let calendar = Calendar.current
        let baseDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 31))!
        
        // Test +3 days
        let date3 = calendar.date(byAdding: .day, value: 3, to: baseDate)!
        XCTAssertEqual(calendar.component(.month, from: date3), 2)
        XCTAssertEqual(calendar.component(.day, from: date3), 3)
        
        // Test +7 days
        let date7 = calendar.date(byAdding: .day, value: 7, to: baseDate)!
        XCTAssertEqual(calendar.component(.month, from: date7), 2)
        XCTAssertEqual(calendar.component(.day, from: date7), 7)
        
        // Test +30 days (January 31 + 30 = March 1 or March 2 in leap year)
        let date30 = calendar.date(byAdding: .day, value: 30, to: baseDate)!
        XCTAssertEqual(calendar.component(.month, from: date30), 3)
        // February has 28 days in 2026 (not leap year), so Jan 31 + 30 = March 1
        XCTAssertEqual(calendar.component(.day, from: date30), 2)
    }
    
    func testDateCalculationAcrossYear() throws {
        let calendar = Calendar.current
        let baseDate = calendar.date(from: DateComponents(year: 2026, month: 12, day: 31))!
        
        let date3 = calendar.date(byAdding: .day, value: 3, to: baseDate)!
        XCTAssertEqual(calendar.component(.year, from: date3), 2027)
        XCTAssertEqual(calendar.component(.month, from: date3), 1)
        XCTAssertEqual(calendar.component(.day, from: date3), 3)
    }
    
    func testDateCalculationLeapYear() throws {
        let calendar = Calendar.current
        let baseDate = calendar.date(from: DateComponents(year: 2024, month: 2, day: 28))!
        
        let date3 = calendar.date(byAdding: .day, value: 3, to: baseDate)!
        XCTAssertEqual(calendar.component(.month, from: date3), 3)
        XCTAssertEqual(calendar.component(.day, from: date3), 2)
    }
    
    func testReviewEventCreation() throws {
        let baseDate = Date()
        let event = ReviewEvent(title: "Test", baseDate: baseDate)
        
        XCTAssertEqual(event.title, "Test")
        XCTAssertEqual(event.reviewDates.count, 3)
        XCTAssertEqual(event.notes.count, 3)
        XCTAssertEqual(event.notes[0], "第1次复习")
        XCTAssertEqual(event.notes[1], "第2次复习")
        XCTAssertEqual(event.notes[2], "第3次复习")
    }
    
    func testDateFormatter() throws {
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 12))!
        
        let chineseString = date.formattedChinese()
        XCTAssertEqual(chineseString, "2026年06月12日")
        
        let shortString = date.formattedShort()
        XCTAssertEqual(shortString, "06-12")
    }
}
