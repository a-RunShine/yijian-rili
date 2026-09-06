import Foundation
import SwiftUI

/// 周末总结页面状态容器（spec F1-F9，plan §3.2）。
///
/// 数据独立持久化于三个 UserDefaults JSON key：
/// - `weeklyEntriesData`：所有周条目（无上限）
/// - `weeklyReviewStateData`：已复习条目 id 列表
/// - `weeklyNotesData`：每周笔记字典（key = weekKey）
@MainActor
final class WeeklyReviewViewModel: ObservableObject {

    // MARK: - 持久化键（plan §2.3）

    static let weeklyEntriesKey = "weeklyEntriesData"
    static let weeklyReviewStateKey = "weeklyReviewStateData"
    static let weeklyNotesKey = "weeklyNotesData"
    /// 历史记录一次性迁移完成标记（避免重复执行）
    static let historyMigrationKey = "weeklyEntriesHistoryMigrationDone"
    /// `ReviewViewModel.historyEntriesData` 的存储 key（迁移时读取）
    static let legacyHistoryEntriesKey = "historyEntriesData"

    // MARK: - Published 状态

    /// 当前查看的周一（默认本周周一）
    @Published var currentWeekStart: Date

    /// 当前周笔记草稿（编辑中）
    @Published var noteDraft: String = ""

    /// 用户中心，UI 引用同一 Theme
    let themeProvider: ThemeProvider

    /// 触发 SwiftUI 刷新的 tick（每次持久化后 +1，View 通过计算属性读取）
    @Published private(set) var revision: Int = 0

    // MARK: - 持久化（直接用 UserDefaults，避免 @AppStorage 在类内可能的初始化时序问题）

    private let defaults: UserDefaults
    private var weeklyEntriesJSON: String {
        get { defaults.string(forKey: WeeklyReviewViewModel.weeklyEntriesKey) ?? "[]" }
        set { defaults.set(newValue, forKey: WeeklyReviewViewModel.weeklyEntriesKey) }
    }
    private var reviewedJSON: String {
        get { defaults.string(forKey: WeeklyReviewViewModel.weeklyReviewStateKey) ?? "[]" }
        set { defaults.set(newValue, forKey: WeeklyReviewViewModel.weeklyReviewStateKey) }
    }
    private var notesJSON: String {
        get { defaults.string(forKey: WeeklyReviewViewModel.weeklyNotesKey) ?? "{\"byWeek\":{}}" }
        set { defaults.set(newValue, forKey: WeeklyReviewViewModel.weeklyNotesKey) }
    }

    // MARK: - 构造

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.currentWeekStart = WeekCalculator.weekStart(for: Date())
        self.themeProvider = ThemeProvider()
        // 一次性迁移：把 `historyEntriesData` 里尚未存在于 weeklyEntriesData 的
        // HistoryEntry 转成 WeeklyEntry。幂等，由 migration key 保护。
        performHistoryMigrationIfNeeded()
        // 初始化草稿
        reloadDraftForCurrentWeek()
    }

    // MARK: - 计算属性（每次访问时解码 JSON；UI 引用 revision 触发刷新）

    var currentWeekEnd: Date {
        WeekCalculator.weekEnd(for: currentWeekStart)
    }

    var currentWeekKey: String {
        WeekCalculator.weekKey(for: currentWeekStart)
    }

    var weeklyEntries: [WeeklyEntry] {
        _ = revision
        guard let data = weeklyEntriesJSON.data(using: .utf8),
              let entries = try? JSONDecoder().decode([WeeklyEntry].self, from: data) else {
            return []
        }
        return entries
    }

    var reviewedIds: Set<UUID> {
        _ = revision
        guard let data = reviewedJSON.data(using: .utf8),
              let ids = try? JSONDecoder().decode([UUID].self, from: data) else {
            return []
        }
        return Set(ids)
    }

    var currentWeekNote: String {
        _ = revision
        let notes = decodeNotes()
        return notes.byWeek[currentWeekKey] ?? ""
    }

    /// 当前周条目（spec F3: 仅 creationDate ∈ 当前周，且不重复展开复习日期）
    var entriesInCurrentWeek: [WeeklyEntry] {
        let start = currentWeekStart
        let end = currentWeekEnd
        return weeklyEntries
            .filter { $0.creationDate >= start && $0.creationDate <= end }
            .sorted { $0.creationDate > $1.creationDate }
    }

    /// 按 creationDate 分组（spec F4）
    var entriesGroupedByCreationDate: [(date: Date, entries: [WeeklyEntry])] {
        let entries = entriesInCurrentWeek
        let cal = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry -> Date in
            cal.startOfDay(for: entry.creationDate)
        }
        return grouped
            .map { (date: $0.key, entries: $0.value.sorted { $0.creationDate > $1.creationDate }) }
            .sorted { $0.date > $1.date }
    }

    var reviewedCount: Int {
        let entries = entriesInCurrentWeek
        let reviewed = reviewedIds
        return entries.filter { reviewed.contains($0.id) }.count
    }

    var totalCount: Int {
        entriesInCurrentWeek.count
    }

    /// 仅当 currentWeekStart 严格早于"本周周一（实时计算）"时为 true（spec F5）
    var canGoToNextWeek: Bool {
        let thisMonday = WeekCalculator.weekStart(for: Date())
        return currentWeekStart < thisMonday
    }

    // MARK: - 周切换

    func goToPreviousWeek() {
        commitNoteDraft()
        currentWeekStart = WeekCalculator.addingWeeks(-1, to: currentWeekStart)
        reloadDraftForCurrentWeek()
        revision &+= 1
    }

    func goToNextWeek() {
        guard canGoToNextWeek else { return }
        commitNoteDraft()
        currentWeekStart = WeekCalculator.addingWeeks(1, to: currentWeekStart)
        reloadDraftForCurrentWeek()
        revision &+= 1
    }

    func jumpToCurrentWeek() {
        commitNoteDraft()
        currentWeekStart = WeekCalculator.weekStart(for: Date())
        reloadDraftForCurrentWeek()
        revision &+= 1
    }

    // MARK: - 笔记

    /// 把当前 draft 强制写回 notesJSON（无论是否变化），兜底防丢
    func commitNoteDraft() {
        var notes = decodeNotes()
        let key = currentWeekKey
        let trimmed = noteDraft
        if notes.byWeek[key] != trimmed {
            notes.byWeek[key] = trimmed
            writeNotes(notes)
            revision &+= 1
        }
    }

    /// 每次编辑（spec F7: 立即写入，无防抖）
    func updateNote(_ text: String) {
        noteDraft = text
        var notes = decodeNotes()
        notes.byWeek[currentWeekKey] = text
        writeNotes(notes)
        revision &+= 1
    }

    private func reloadDraftForCurrentWeek() {
        noteDraft = currentWeekNote
    }

    // MARK: - 勾选

    func isReviewed(_ id: UUID) -> Bool {
        reviewedIds.contains(id)
    }

    func toggleReviewed(_ id: UUID) {
        var set = reviewedIds
        if set.contains(id) {
            set.remove(id)
        } else {
            set.insert(id)
        }
        persistReviewed(set)
        revision &+= 1
    }

    private func persistReviewed(_ set: Set<UUID>) {
        let array = Array(set)
        if let data = try? JSONEncoder().encode(array),
           let string = String(data: data, encoding: .utf8) {
            reviewedJSON = string
        }
    }

    // MARK: - 写入 weekly entry（由 ReviewViewModel 在 addHistoryEntry 时调用）

    /// 追加一条 weekly entry，使用 historyEntry.id 作为关联 id
    func appendWeeklyEntry(from historyEntry: HistoryEntry) {
        var entries = weeklyEntries
        // 避免重复（同一 id）
        entries.removeAll { $0.id == historyEntry.id }
        let weekly = WeeklyEntry(
            id: historyEntry.id,
            title: historyEntry.title,
            baseDate: historyEntry.baseDate,
            scheduleType: historyEntry.type,
            creationDate: historyEntry.creationDate
        )
        entries.append(weekly)
        persistWeeklyEntries(entries)
        revision &+= 1
    }

    func persistWeeklyEntries(_ entries: [WeeklyEntry]) {
        if let data = try? JSONEncoder().encode(entries),
           let string = String(data: data, encoding: .utf8) {
            weeklyEntriesJSON = string
        }
    }

    // MARK: - 一次性历史记录迁移

    /// 首次初始化时把 `historyEntriesData` 中尚未存在于 weeklyEntriesData 的
    /// HistoryEntry 转成 WeeklyEntry，保留原 id / title / baseDate / type / creationDate。
    /// 由 `historyMigrationKey` 防止重复执行。
    ///
    /// - 不覆盖：已存在（id 一致）的 weekly entries 保持原样。
    /// - 旧数据兼容：旧 HistoryEntry 缺 `type` 时由现有自定义解码默认 `.review`。
    /// - 幂等：重复调用不会重复迁移，也不会影响已有 entries。
    func performHistoryMigrationIfNeeded() {
        // 已迁移过：直接返回
        guard !defaults.bool(forKey: WeeklyReviewViewModel.historyMigrationKey) else {
            return
        }

        // 读取旧历史记录。缺失 / 损坏 / 空数组都视为无迁移内容。
        let legacyRaw = defaults.string(forKey: WeeklyReviewViewModel.legacyHistoryEntriesKey) ?? ""
        let legacyEntries: [HistoryEntry]
        if legacyRaw.isEmpty {
            legacyEntries = []
        } else if let data = legacyRaw.data(using: .utf8) {
            legacyEntries = (try? JSONDecoder().decode([HistoryEntry].self, from: data)) ?? []
        } else {
            legacyEntries = []
        }

        // 计算待迁移的条目：剔除 id 已存在的
        let existingEntries = weeklyEntries
        let existingIds = Set(existingEntries.map { $0.id })
        let toMigrate = legacyEntries.filter { !existingIds.contains($0.id) }

        if !toMigrate.isEmpty {
            let converted: [WeeklyEntry] = toMigrate.map { history in
                WeeklyEntry(
                    id: history.id,
                    title: history.title,
                    baseDate: history.baseDate,
                    scheduleType: history.type,
                    creationDate: history.creationDate
                )
            }
            let merged = existingEntries + converted
            persistWeeklyEntries(merged)
            revision &+= 1
        }

        // 标记完成，防止重复执行（即便没有可迁移内容也设置，避免每次启动反复扫描）
        defaults.set(true, forKey: WeeklyReviewViewModel.historyMigrationKey)
    }

    // MARK: - Notes 编解码

    private func decodeNotes() -> WeeklyNotes {
        guard let data = notesJSON.data(using: .utf8) else { return WeeklyNotes(byWeek: [:]) }
        return (try? JSONDecoder().decode(WeeklyNotes.self, from: data)) ?? WeeklyNotes(byWeek: [:])
    }

    private func writeNotes(_ notes: WeeklyNotes) {
        if let data = try? JSONEncoder().encode(notes),
           let string = String(data: data, encoding: .utf8) {
            notesJSON = string
        }
    }

    // MARK: - 测试辅助

    /// 测试用：重置所有数据（不持久化主题）
    func resetForTest() {
        weeklyEntriesJSON = "[]"
        reviewedJSON = "[]"
        notesJSON = "{\"byWeek\":{}}"
        noteDraft = ""
        currentWeekStart = WeekCalculator.weekStart(for: Date())
        revision &+= 1
    }
}

/// 笔记结构（plan §2.1）
struct WeeklyNotes: Codable, Equatable {
    /// key = weekKey(for: mondayDate)，value = 笔记全文
    var byWeek: [String: String]

    init(byWeek: [String: String] = [:]) {
        self.byWeek = byWeek
    }
}

/// Theme 桥接（避免 WeeklyReviewView 直接依赖 ReviewViewModel）
@MainActor
final class ThemeProvider: ObservableObject {
    @Published var theme: Theme = {
        let raw = UserDefaults.standard.string(forKey: "themeName") ?? Theme.light.rawValue
        return Theme(rawValue: raw) ?? .light
    }()

    init() {
        // 监听主题切换（仅做一次初始化读取；切换由 ReviewViewModel 集中处理）
    }
}
