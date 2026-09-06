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
        
        // Test +30 days
        // 2026 is not a leap year, so January 31 + 30 days = March 2
        let date30 = calendar.date(byAdding: .day, value: 30, to: baseDate)!
        XCTAssertEqual(calendar.component(.month, from: date30), 3)
        // January has 31 days, February has 28 days in 2026 (not leap year)
        // Jan 31 + 30 = Feb 28 + 2 = March 2
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
        // 测试环境中 NSLocalizedString 回退为 key，notes 格式为 "review_count"
        let expectedNote = String(format: NSLocalizedString("review_count", comment: ""), "1")
        XCTAssertEqual(event.notes[0], expectedNote)
        XCTAssertEqual(event.notes[1], String(format: NSLocalizedString("review_count", comment: ""), "2"))
        XCTAssertEqual(event.notes[2], String(format: NSLocalizedString("review_count", comment: ""), "3"))
    }
    
    func testReviewEventWithCustomIntervals() throws {
        let baseDate = Date()
        let event = ReviewEvent(title: "Custom", baseDate: baseDate, intervals: [1, 3, 7])
        
        XCTAssertEqual(event.title, "Custom")
        XCTAssertEqual(event.reviewDates.count, 3)
        XCTAssertEqual(event.notes.count, 3)
        XCTAssertEqual(event.notes[0], String(format: NSLocalizedString("review_count", comment: ""), "1"))
        XCTAssertEqual(event.notes[1], String(format: NSLocalizedString("review_count", comment: ""), "2"))
        XCTAssertEqual(event.notes[2], String(format: NSLocalizedString("review_count", comment: ""), "3"))
    }
    
    func testReviewEventSafeDateCalculation() throws {
        let calendar = Calendar.current
        let baseDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 31))!
        
        let dates = ReviewEvent.calculateReviewDates(from: baseDate, intervals: [3, 7, 30])
        
        XCTAssertEqual(dates.count, 3)
        XCTAssertEqual(calendar.component(.day, from: dates[0]), 3)
        XCTAssertEqual(calendar.component(.day, from: dates[1]), 7)
        XCTAssertEqual(calendar.component(.month, from: dates[2]), 3)
        XCTAssertEqual(calendar.component(.day, from: dates[2]), 2)
    }
    
    func testDateFormatter() throws {
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 12))!
        
        let chineseString = date.formattedChinese()
        XCTAssertEqual(chineseString, "2026年06月12日")
        
        let shortString = date.formattedShort()
        XCTAssertEqual(shortString, "06-12")
    }
    
    func testHistoryEntryCoding() throws {
        let entry = HistoryEntry(
            title: "Test",
            baseDate: Date(),
            reviewDates: [Date(), Date()],
            creationDate: Date()
        )
        
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(HistoryEntry.self, from: data)
        
        XCTAssertEqual(entry.title, decoded.title)
    }
    
    @MainActor
    func testViewModelValidation() async {
        let viewModel = ReviewViewModel()
        
        // Test empty title
        viewModel.title = ""
        await viewModel.createReviewSchedule()
        XCTAssertEqual(viewModel.resultType, .error)
        
        // Test whitespace-only title
        viewModel.title = "   "
        await viewModel.createReviewSchedule()
        XCTAssertEqual(viewModel.resultType, .error)
        
        // Test long title
        viewModel.title = String(repeating: "a", count: 101)
        await viewModel.createReviewSchedule()
        XCTAssertEqual(viewModel.resultType, .error)
    }
    
    @MainActor
    func testViewModelIntervalValidation() {
        let viewModel = ReviewViewModel()
        
        XCTAssertTrue(viewModel.validateIntervals([1, 3, 7]))
        XCTAssertTrue(viewModel.validateIntervals([3, 7, 30]))
        XCTAssertFalse(viewModel.validateIntervals([0, 3, 7]))
        XCTAssertFalse(viewModel.validateIntervals([3, -1, 7]))
        // 空数组不合法
        XCTAssertFalse(viewModel.validateIntervals([]))
        // 超过 365 不合法
        XCTAssertFalse(viewModel.validateIntervals([1, 366]))
        // 单个间隔合法
        XCTAssertTrue(viewModel.validateIntervals([7]))
        // 多个间隔合法
        XCTAssertTrue(viewModel.validateIntervals([1, 2, 4, 7, 15]))
        // 非递增序列不合法（时间倒退）
        XCTAssertFalse(viewModel.validateIntervals([30, 7, 3]))
        XCTAssertFalse(viewModel.validateIntervals([7, 7, 30]))
        XCTAssertFalse(viewModel.validateIntervals([10, 5]))
        // 边界：严格递增合法
        XCTAssertTrue(viewModel.validateIntervals([1, 2, 3]))
        XCTAssertTrue(viewModel.validateIntervals([1, 365]))
    }

    @MainActor
    func testMaxIntervalCountExceeded() {
        let viewModel = ReviewViewModel()

        // 10 个间隔（上限）——全部合法
        XCTAssertTrue(viewModel.validateIntervals([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]))

        // 11 个间隔——超过上限，应被拒绝
        XCTAssertFalse(viewModel.validateIntervals([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]))
    }

    @MainActor
    func testDynamicIntervalCount() {
        let viewModel = ReviewViewModel()

        // 设置 1 个间隔
        viewModel.reviewIntervals = [5]
        viewModel.updateReviewDates()
        XCTAssertEqual(viewModel.reviewDates.count, 1)

        // 设置 5 个间隔
        viewModel.reviewIntervals = [1, 2, 4, 7, 15]
        viewModel.updateReviewDates()
        XCTAssertEqual(viewModel.reviewDates.count, 5)

        // 边界: 10 个间隔
        viewModel.reviewIntervals = [1, 2, 3, 5, 7, 10, 14, 21, 30, 60]
        viewModel.updateReviewDates()
        XCTAssertEqual(viewModel.reviewDates.count, 10)
    }

    @MainActor
    func testCustomPresetSaveAndApply() {
        // 先清空再创建 ViewModel
        UserDefaults.standard.set("[]", forKey: "customPresetsData")
        let viewModel = ReviewViewModel()

        // 初始无自定义预设
        XCTAssertEqual(viewModel.customPresets.count, 0)

        // 保存一个自定义预设
        viewModel.reviewIntervals = [1, 3, 7]
        viewModel.saveCustomPreset(name: "我的方案")
        XCTAssertEqual(viewModel.customPresets.count, 1)
        XCTAssertEqual(viewModel.customPresets[0].name, "我的方案")
        XCTAssertEqual(viewModel.customPresets[0].intervals, [1, 3, 7])

        // 应用自定义预设
        viewModel.reviewIntervals = [3, 7, 30]
        viewModel.applyCustomPreset(viewModel.customPresets[0])
        XCTAssertEqual(viewModel.reviewIntervals, [1, 3, 7])

        // 删除自定义预设
        let presetId = viewModel.customPresets[0].id
        viewModel.deleteCustomPreset(id: presetId)
        XCTAssertEqual(viewModel.customPresets.count, 0)

        // 清理
        UserDefaults.standard.set("[]", forKey: "customPresetsData")
    }

    @MainActor
    func testCustomPresetDuplicateName() {
        UserDefaults.standard.set("[]", forKey: "customPresetsData")
        let viewModel = ReviewViewModel()

        viewModel.reviewIntervals = [1, 3, 7]
        viewModel.saveCustomPreset(name: "测试")
        XCTAssertEqual(viewModel.customPresets.count, 1)

        // 重名不会重复添加
        viewModel.reviewIntervals = [2, 5, 10]
        viewModel.saveCustomPreset(name: "测试")
        XCTAssertEqual(viewModel.customPresets.count, 1)
        XCTAssertEqual(viewModel.customPresets[0].intervals, [1, 3, 7]) // 仍是原来的

        XCTAssertTrue(viewModel.hasDuplicatePresetName("测试"))
        XCTAssertFalse(viewModel.hasDuplicatePresetName("其他"))

        // 清理
        UserDefaults.standard.set("[]", forKey: "customPresetsData")
    }

    func testCustomPresetCoding() throws {
        let preset = CustomPreset(name: "考试", intervals: [1, 3, 7])
        let data = try JSONEncoder().encode([preset])
        let decoded = try JSONDecoder().decode([CustomPreset].self, from: data)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].id, preset.id)
        XCTAssertEqual(decoded[0].name, "考试")
        XCTAssertEqual(decoded[0].intervals, [1, 3, 7])
    }
}
