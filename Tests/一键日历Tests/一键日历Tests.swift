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

    // MARK: - Weekly Review (周末总结)

    func testWeekCalculatorMondayStart() throws {
        // 2026-06-10 是周三
        let calendar = Calendar(identifier: .gregorian)
        let wednesday = calendar.date(from: DateComponents(year: 2026, month: 6, day: 10))!

        let monday = WeekCalculator.weekStart(for: wednesday)
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: monday)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 6)
        XCTAssertEqual(comps.day, 8) // 周一 = 6/8
        XCTAssertEqual(comps.hour, 0)
        XCTAssertEqual(comps.minute, 0)
        XCTAssertEqual(comps.second, 0)

        // 验证周日边界
        let sunday = WeekCalculator.weekEnd(for: wednesday)
        let sundayComps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: sunday)
        XCTAssertEqual(sundayComps.year, 2026)
        XCTAssertEqual(sundayComps.month, 6)
        XCTAssertEqual(sundayComps.day, 14) // 周日 = 6/14
        XCTAssertEqual(sundayComps.hour, 23)
        XCTAssertEqual(sundayComps.minute, 59)
        XCTAssertEqual(sundayComps.second, 59)
    }

    func testWeekCalculatorAcrossYearBoundary() throws {
        let calendar = Calendar(identifier: .gregorian)
        // 2027-01-03 是周日
        let sunday = calendar.date(from: DateComponents(year: 2027, month: 1, day: 3))!

        let monday = WeekCalculator.weekStart(for: sunday)
        let comps = calendar.dateComponents([.year, .month, .day], from: monday)
        // 该周周一 = 2026-12-28
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 12)
        XCTAssertEqual(comps.day, 28)
    }

    func testWeeklyEntryCodable() throws {
        let entry = WeeklyEntry(
            id: UUID(),
            title: "Swift 学习",
            baseDate: Date(),
            scheduleType: .review,
            creationDate: Date()
        )
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(WeeklyEntry.self, from: data)
        XCTAssertEqual(decoded.id, entry.id)
        XCTAssertEqual(decoded.title, entry.title)
        XCTAssertEqual(decoded.scheduleType, entry.scheduleType)
        XCTAssertEqual(decoded.creationDate.timeIntervalSince1970,
                       entry.creationDate.timeIntervalSince1970, accuracy: 0.001)
    }

    func testHistoryEntryBackwardCompatMissingType() throws {
        // 旧 JSON 没有 type 字段 → 默认 .review
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "title": "Old Entry",
          "baseDate": 700000000,
          "reviewDates": [700000000],
          "creationDate": 700000000
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(HistoryEntry.self, from: data)
        XCTAssertEqual(decoded.type, .review)

        // 新 JSON 带 type=single → 正确解析
        let newJson = """
        {
          "id": "22222222-2222-2222-2222-222222222222",
          "title": "New Entry",
          "baseDate": 700000000,
          "reviewDates": [],
          "creationDate": 700000000,
          "type": "single"
        }
        """
        let newData = newJson.data(using: .utf8)!
        let newDecoded = try JSONDecoder().decode(HistoryEntry.self, from: newData)
        XCTAssertEqual(newDecoded.type, .single)
    }

    @MainActor
    func testWeeklyReviewToggleAndPersist() {
        let vm = WeeklyReviewViewModel()
        vm.resetForTest()

        let historyEntry = HistoryEntry(
            title: "Test Title",
            baseDate: Date(),
            reviewDates: [Date()],
            creationDate: Date(),
            type: .review
        )
        vm.appendWeeklyEntry(from: historyEntry)

        // 切换为已复习
        XCTAssertFalse(vm.isReviewed(historyEntry.id))
        vm.toggleReviewed(historyEntry.id)
        XCTAssertTrue(vm.isReviewed(historyEntry.id))

        // 持久化往返：重建 VM，应仍能读到
        let vm2 = WeeklyReviewViewModel()
        XCTAssertTrue(vm2.isReviewed(historyEntry.id))

        // 再次切换取消
        vm2.toggleReviewed(historyEntry.id)
        XCTAssertFalse(vm2.isReviewed(historyEntry.id))

        // 清理
        vm.resetForTest()
    }

    @MainActor
    func testWeeklyReviewWeekBoundary() {
        let vm = WeeklyReviewViewModel()
        vm.resetForTest()

        let cal = Calendar.current
        // 当前周的一条
        let thisWeek = HistoryEntry(
            title: "This Week",
            baseDate: Date(),
            reviewDates: [],
            creationDate: Date(),
            type: .review
        )
        vm.appendWeeklyEntry(from: thisWeek)

        // 上一周的一条：使用上一周的周三（当前周一 - 4 天），确保落在上周 [周一, 周日] 区间
        let thisMonday = vm.currentWeekStart
        let lastWeekWednesday = cal.date(byAdding: .day, value: -4, to: thisMonday)!
        let lastWeekEntry = HistoryEntry(
            title: "Last Week",
            baseDate: lastWeekWednesday,
            reviewDates: [],
            creationDate: lastWeekWednesday,
            type: .single
        )
        vm.appendWeeklyEntry(from: lastWeekEntry)

        // 默认当前周：只看到 thisWeek
        XCTAssertEqual(vm.entriesInCurrentWeek.count, 1)
        XCTAssertEqual(vm.entriesInCurrentWeek.first?.title, "This Week")

        // 切到上一周：只看到 lastWeekEntry
        vm.goToPreviousWeek()
        XCTAssertEqual(vm.entriesInCurrentWeek.count, 1)
        XCTAssertEqual(vm.entriesInCurrentWeek.first?.title, "Last Week")

        // canGoToNextWeek 应为 true（当前位于上周）
        XCTAssertTrue(vm.canGoToNextWeek)

        // 切回本周
        vm.jumpToCurrentWeek()
        XCTAssertEqual(vm.entriesInCurrentWeek.count, 1)
        XCTAssertEqual(vm.entriesInCurrentWeek.first?.title, "This Week")

        // 在本周时不应允许再去下一周
        XCTAssertFalse(vm.canGoToNextWeek)

        vm.resetForTest()
    }

    @MainActor
    func testWeeklyReviewNotePersistence() {
        let vm = WeeklyReviewViewModel()
        vm.resetForTest()

        let key = vm.currentWeekKey
        XCTAssertEqual(vm.noteDraft, "")

        vm.updateNote("本周学习心得")
        XCTAssertEqual(vm.noteDraft, "本周学习心得")

        // 重建 VM 验证持久化
        let vm2 = WeeklyReviewViewModel()
        XCTAssertEqual(vm2.currentWeekNote, "本周学习心得")

        // 切换周再切回来，笔记仍存在
        vm2.goToPreviousWeek()
        vm2.goToNextWeek()
        XCTAssertEqual(vm2.currentWeekNote, "本周学习心得")

        // 清理
        vm.resetForTest()
        _ = key
    }

    // MARK: - 历史记录一次性迁移

    @MainActor
    func testWeeklyReviewHistoryMigration() {
        // 使用独立 UserDefaults suite，避免污染 .standard
        let suiteName = "test-weekly-migration-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("无法创建独立 UserDefaults suite")
            return
        }
        // 快照标准 defaults 在本测试开始前的状态
        let standardKeysBefore = Set(UserDefaults.standard.dictionaryRepresentation().keys)
        defer {
            // 清理：清空 suite 内容并销毁实例，避免遗留
            for key in defaults.dictionaryRepresentation().keys {
                defaults.removeObject(forKey: key)
            }
            defaults.removePersistentDomain(forName: suiteName)
        }

        // 1. 准备旧 historyEntriesData：3 条
        //    - 第一条带 type="review"
        //    - 第二条带 type="single"
        //    - 第三条缺 type（旧数据，依赖 HistoryEntry 自定义解码默认 .review）
        //
        // JSONEncoder/JSONDecoder 默认 date 策略为 reference date（2001-01-01 UTC），
        // 与 Unix 纪元相差 978_307_200 秒，因此 JSON 中用 reference-date 数值
        // 才能与生产数据格式一致。
        let idA = UUID()
        let idB = UUID()
        let idC = UUID()
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let creationDate = Date(timeIntervalSince1970: 1_700_001_000)
        let baseDateRef = baseDate.timeIntervalSinceReferenceDate
        let creationDateRef = creationDate.timeIntervalSinceReferenceDate
        let legacyJSON = """
        [
          {
            "id": "\(idA.uuidString)",
            "title": "复习 A",
            "baseDate": \(baseDateRef),
            "reviewDates": [\(baseDateRef)],
            "creationDate": \(creationDateRef),
            "type": "review"
          },
          {
            "id": "\(idB.uuidString)",
            "title": "单次 B",
            "baseDate": \(baseDateRef),
            "reviewDates": [],
            "creationDate": \(creationDateRef),
            "type": "single"
          },
          {
            "id": "\(idC.uuidString)",
            "title": "旧数据 C（缺 type）",
            "baseDate": \(baseDateRef),
            "reviewDates": [],
            "creationDate": \(creationDateRef)
          }
        ]
        """
        defaults.set(legacyJSON, forKey: WeeklyReviewViewModel.legacyHistoryEntriesKey)

        // 2. 预置一条 weekly entry（A 同 id）→ 验证不会被覆盖
        let existingWeekly = WeeklyEntry(
            id: idA,
            title: "已被用户改名的 A",
            baseDate: baseDate,
            scheduleType: .review,
            creationDate: creationDate
        )
        let existingData = try! JSONEncoder().encode([existingWeekly])
        defaults.set(String(data: existingData, encoding: .utf8), forKey: WeeklyReviewViewModel.weeklyEntriesKey)

        // 3. 首次构造 VM → 触发迁移
        let vm = WeeklyReviewViewModel(defaults: defaults)
        let migrated = vm.weeklyEntries

        // 4. 断言：迁移后应有 3 条（A 原有 + B + C 新增）
        XCTAssertEqual(migrated.count, 3)

        // 5. 断言：id=A 的条目**未被覆盖**（标题仍为 "已被用户改名的 A"）
        let migratedA = migrated.first(where: { $0.id == idA })
        XCTAssertNotNil(migratedA)
        XCTAssertEqual(migratedA?.title, "已被用户改名的 A", "已存在的 weekly entry 不应被迁移覆盖")
        XCTAssertEqual(migratedA?.scheduleType, .review)
        XCTAssertEqual(migratedA?.baseDate.timeIntervalSince1970 ?? 0,
                       baseDate.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(migratedA?.creationDate.timeIntervalSince1970 ?? 0,
                       creationDate.timeIntervalSince1970, accuracy: 0.001)

        // 6. 断言：id=B 的条目（type=single）正确迁移
        let migratedB = migrated.first(where: { $0.id == idB })
        XCTAssertNotNil(migratedB)
        XCTAssertEqual(migratedB?.title, "单次 B")
        XCTAssertEqual(migratedB?.scheduleType, .single)
        XCTAssertEqual(migratedB?.baseDate.timeIntervalSince1970 ?? 0,
                       baseDate.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(migratedB?.creationDate.timeIntervalSince1970 ?? 0,
                       creationDate.timeIntervalSince1970, accuracy: 0.001)

        // 7. 断言：id=C 的旧数据（缺 type）迁移后默认为 .review
        let migratedC = migrated.first(where: { $0.id == idC })
        XCTAssertNotNil(migratedC)
        XCTAssertEqual(migratedC?.title, "旧数据 C（缺 type）")
        XCTAssertEqual(migratedC?.scheduleType, .review, "缺 type 的旧数据应默认 .review")
        XCTAssertEqual(migratedC?.id, idC, "id 必须保留原值")

        // 8. 断言：migration key 已设置
        XCTAssertTrue(defaults.bool(forKey: WeeklyReviewViewModel.historyMigrationKey))

        // 9. 断言：幂等性 — 再次构造 VM，不会重复迁移，也不会丢数据
        let vm2 = WeeklyReviewViewModel(defaults: defaults)
        let afterSecondInit = vm2.weeklyEntries
        XCTAssertEqual(afterSecondInit.count, 3, "幂等：再次构造不应重复迁移")
        // 内容完全一致
        XCTAssertEqual(
            Set(afterSecondInit.map { $0.id }),
            Set(migrated.map { $0.id })
        )

        // 10. 显式再调用一次迁移方法，验证完全幂等
        vm2.performHistoryMigrationIfNeeded()
        XCTAssertEqual(vm2.weeklyEntries.count, 3)

        // 11. 断言：迁移代码不应触碰 .standard
        //     对比本测试开始前的 key 集合，迁移代码未新增任何 key。
        //     （.standard 上的 historyMigrationKey 可能已被其他使用默认 UserDefaults
        //     的测试设置过，那是它们的合法行为，不是本测试的污染。）
        let standardKeysAfter = Set(UserDefaults.standard.dictionaryRepresentation().keys)
        let newStandardKeys = standardKeysAfter.subtracting(standardKeysBefore)
        XCTAssertTrue(newStandardKeys.isEmpty,
                      "迁移代码不应在 .standard 上新增任何 key，新增: \(newStandardKeys)")
    }

    @MainActor
    func testWeeklyReviewHistoryMigrationEmptyAndCorrupted() {
        // 边界：historyEntriesData 为空 / 缺失 / 损坏时不应崩溃
        let suiteName = "test-weekly-migration-empty-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("无法创建独立 UserDefaults suite")
            return
        }
        defer {
            for key in defaults.dictionaryRepresentation().keys {
                defaults.removeObject(forKey: key)
            }
            defaults.removePersistentDomain(forName: suiteName)
        }

        // 1. 完全空的 defaults → 不应崩溃
        let vm = WeeklyReviewViewModel(defaults: defaults)
        XCTAssertEqual(vm.weeklyEntries.count, 0)
        XCTAssertTrue(defaults.bool(forKey: WeeklyReviewViewModel.historyMigrationKey),
                      "即便没有可迁移内容也应设置标记，避免反复扫描")

        // 2. 损坏的 JSON → 应安全降级为空，迁移标记仍设置
        defaults.set("not-a-valid-json", forKey: WeeklyReviewViewModel.legacyHistoryEntriesKey)
        defaults.set(false, forKey: WeeklyReviewViewModel.historyMigrationKey)
        let vm2 = WeeklyReviewViewModel(defaults: defaults)
        XCTAssertEqual(vm2.weeklyEntries.count, 0)
        XCTAssertTrue(defaults.bool(forKey: WeeklyReviewViewModel.historyMigrationKey))
    }
}
