# 周末总结（周一至周日）Plan

> 基于已批准 `spec.md`。本文档定义"怎么做"，不重复"做什么"。
> 范围：F1–F9；现有创建/撤销/日历权限/窗口设置流程不动。

---

## 1. 架构概览

```
┌─────────────────────────────────────────────────────────────┐
│ ContentView (主窗口)                                          │
│  └─ 新增「周末总结」按钮卡片 → sheet 弹出 WeeklyReviewView   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ WeeklyReviewView (sheet 页)                                  │
│  ├─ WeekNavigator      上一周 / 下一周 / 周范围标题           │
│  ├─ ProgressBar        "已复习 X/Y"                          │
│  ├─ EntryList          ForEach 按 creationDate 分组         │
│  │    └─ EntryRow      勾选框 + 标题 + baseDate + 类型标签    │
│  ├─ NoteEditor         TextEditor，每次改动 onChange 落盘    │
│  └─ EmptyState         "本周还没有学习条目..."               │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ WeeklyReviewViewModel (@MainActor, ObservableObject)         │
│  ├─ currentWeekStart    状态：当前查看的周一                  │
│  ├─ reviewedIds         状态：所有已复习条目 id               │
│  ├─ weeklyEntries       状态：所有条目（不变，按周过滤）      │
│  ├─ noteDraft           状态：当前周笔记编辑草稿              │
│  └─ weeklyNoteStore     状态：所有周的笔记 (持久)            │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ WeekCalculator (Utils, 静态方法)                              │
│  └─ weekStart / weekEnd / weekKey / weekRange              │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 数据源（UserDefaults / @AppStorage JSON）                     │
│  ├─ historyEntriesData   (现有, 上限 20, 不动)               │
│  ├─ weeklyEntriesData    (新增, 无上限)                      │
│  ├─ weeklyReviewStateData(新增, 无上限)                      │
│  └─ weeklyNotesData      (新增, 无上限, 按周 key)            │
└─────────────────────────────────────────────────────────────┘
```

**职责切分：**
- `WeekCalculator` —— 纯函数周次计算，唯一来源。
- `WeeklyReviewViewModel` —— sheet 页所有状态、筛选、勾选、笔记持久化。
- `WeeklyReviewView` —— 只渲染 + 转发用户意图给 VM。
- `ReviewViewModel` —— 在 `addHistoryEntry` 时**额外写入** `weeklyEntriesData`（不破坏现有历史流程）。

---

## 2. 数据结构

### 2.1 新增类型

<!-- review-fix: ISSUE-2 -->
<!-- review-fix: ISSUE-4 -->
```swift
// Models/WeeklyEntry.swift
/// 周末总结中的一条学习条目。独立于 HistoryEntry 的 20 条上限。
struct WeeklyEntry: Identifiable, Codable, Equatable {
    // 复用 HistoryEntry.id：一对一关联，appendWeeklyEntry(from:) 用同一 id，
    // 撤销创建时按 id 反查 weekly entry 同步清理（见 D6 + 技术债）。
    let id: UUID
    let title: String
    let baseDate: Date             // 用户在创建时选的起始日期（首次学习日期）
    // 直接复用 HistoryEntry.ScheduleType，不重复定义 enum，保证语义一致。
    let scheduleType: HistoryEntry.ScheduleType
    let creationDate: Date         // 用于按周归属 + 按日期分组
    /// 周末复习计划双份规则下的"下一周预占位"标记
    /// - false: 本周（创建所在周）真实条目
    /// - true : 下一周周一的预占位副本（仅复习计划；spec F10-F13）
    /// 解码缺省值为 false（spec 旧数据兼容）。
    let isPreOccupiedNextWeek: Bool
}
```

```swift
// ViewModels/WeeklyReviewViewModel.swift
struct WeeklyNotes: Codable, Equatable {
    /// key = weekKey(for: mondayDate)，value = 笔记全文
    var byWeek: [String: String]
}
```

### 2.2 修改 HistoryEntry（向后兼容）

```swift
// Models/HistoryEntry.swift （在现有结构上扩展）
struct HistoryEntry: Identifiable, Codable {
    let id: UUID
    let title: String
    let baseDate: Date
    let reviewDates: [Date]
    let creationDate: Date
    let type: ScheduleType            // ← 新增

    enum ScheduleType: String, Codable {
        case review, single
    }

    init(title: String, baseDate: Date, reviewDates: [Date],
         creationDate: Date, type: ScheduleType = .review) {
        self.id = UUID()
        self.title = title
        self.baseDate = baseDate
        self.reviewDates = reviewDates
        self.creationDate = creationDate
        self.type = type
    }

    // 自定义解码：缺失 type 字段时默认 .review（满足 F9）
    private enum CodingKeys: String, CodingKey {
        case id, title, baseDate, reviewDates, creationDate, type
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        baseDate = try c.decode(Date.self, forKey: .baseDate)
        reviewDates = try c.decode([Date].self, forKey: .reviewDates)
        creationDate = try c.decode(Date.self, forKey: .creationDate)
        type = try c.decodeIfPresent(ScheduleType.self, forKey: .type) ?? .review
    }
}
```

> `ScheduleType` 定义在 `HistoryEntry` 内，避免和 `WeeklyEntry.ScheduleType` 形成循环。`WeeklyEntry.ScheduleType` 直接复用 `HistoryEntry.ScheduleType`（不重复定义）。

### 2.3 UserDefaults Keys

| Key | 类型 | 默认 | 备注 |
|---|---|---|---|
| `weeklyEntriesData` | JSON `[WeeklyEntry]` | `[]` | 无上限 |
| `weeklyReviewStateData` | JSON `[UUID]`（已勾选 id 列表） | `[]` | 用数组持久化 Set |
| `weeklyNotesData` | JSON `WeeklyNotes` | `{"byWeek":{}}` | key = `weekKey` |
| `weeklyEntriesHistoryMigrationDone` | Bool | `false` | 历史记录一次性迁移完成标记 |
| `weeklyEntriesWeekendMigrationDone` | Bool | `false` | 周末预占位条目迁移完成标记（spec F13） |

---

## 3. 关键接口

<!-- review-fix: ISSUE-3 -->
### 3.1 `WeekCalculator`（Utils/WeekCalculator.swift）

**不变式（所有方法共同遵守，写在文件顶部 doc-comment 中）：**
- **本地时区**：统一用 `Calendar.current.timeZone`（用户系统时区），不做 UTC 转换；跨时区飞行/夏令时切换时不重排历史周。
- **周首日 = 周一**：`Calendar.current.firstWeekday = 2`（周一），不跟随系统 locale。
- **周一 / 周日边界**：周一返回当天的 `00:00:00.000`，周日返回当天的 `23:59:59.999`，闭区间 `[weekStart, weekEnd]`。

```swift
enum WeekCalculator {
    /// 返回 date 所在周的周一 00:00:00.000（本地时区，固定周一为周首日）
    static func weekStart(for date: Date) -> Date

    /// 返回 date 所在周的周日 23:59:59.999（同上）
    static func weekEnd(for date: Date) -> Date

    /// 周稳定 key（基于周一日期的 yyyy-MM-dd），用作笔记字典的键
    static func weekKey(for mondayStart: Date) -> String

    /// 返回 (start, end, key) 三元组
    static func weekRange(for date: Date) -> (start: Date, end: Date, key: String)

    /// 周一 ± 7 天，返回新周一的 00:00:00.000
    static func addingWeeks(_ n: Int, to mondayStart: Date) -> Date

    /// 是否是周六或周日（spec F10 周末复习计划双份判定）
    static func isWeekend(_ date: Date) -> Bool

    /// 返回 date 之后**下一个日历周**周一的 00:00:00.000（spec F10）
    /// - 周一 → +7 天；周二至周日 → 跳到下周周一
    static func nextWeekMonday(after date: Date) -> Date
}
```

### 3.2 `WeeklyReviewViewModel`

```swift
@MainActor
final class WeeklyReviewViewModel: ObservableObject {
    // MARK: Published 状态
    @Published var currentWeekStart: Date          // 默认 = 本周周一
    @Published var noteDraft: String              // 当前周笔记（编辑中草稿）

    // MARK: 持久化源（@AppStorage JSON 字符串）
    @AppStorage("weeklyEntriesData")   private var weeklyEntriesJSON: String = "[]"
    @AppStorage("weeklyReviewStateData") private var reviewedJSON: String = "[]"
    @AppStorage("weeklyNotesData")     private var notesJSON: String = "{\"byWeek\":{}}"

    // MARK: 计算属性
    var currentWeekEnd: Date               // 由 currentWeekStart 算出
    var currentWeekKey: String             // weekKey(currentWeekStart)
    var weeklyEntries: [WeeklyEntry]       // 解码 weeklyEntriesJSON
    var reviewedIds: Set<UUID>             // 解码 reviewedJSON
    var currentWeekNote: String            // notes.byWeek[currentWeekKey] ?? ""

    /// 当前周内 + 按 creationDate 分组的条目（spec F4）
    var entriesGroupedByCreationDate: [(date: Date, entries: [WeeklyEntry])]

    /// 当前周条目（不含复习自动生成的重复日期 — F3）
    var entriesInCurrentWeek: [WeeklyEntry]

<!-- review-fix: ISSUE-1 -->
    /// 进度统计（spec F6）
    var reviewedCount: Int
    var totalCount: Int
    /// 严格定义：仅当 currentWeekStart 严格早于"本周周一（实时计算）"时为 true。
    /// View 层据此禁用"下一周"按钮（按钮在 currentWeek === 本周 时禁用），
    /// 防止用户越过当前周进入未来空周（避免未来条目穿透显示）。
    var canGoToNextWeek: Bool {
        currentWeekStart < WeekCalculator.weekStart(for: Date())
    }

    // MARK: 操作
    /// 切换前强制 commitNoteDraft()，再切 currentWeekStart，最后重载新周 draft。
    func goToPreviousWeek()
    /// canGoToNextWeek 为 false 时 no-op（按钮在 View 层 disabled）。
    func goToNextWeek()
    func jumpToCurrentWeek()

    /// 把 noteDraft 强制写回 notes.byWeek[currentWeekKey]，无论是否变更。
    /// 周切换 + viewModel 销毁前都会调用，兜底防丢笔记。
    func commitNoteDraft()

    func toggleReviewed(_ id: UUID)        // 切换后立即持久化
    func isReviewed(_ id: UUID) -> Bool

    func updateNote(_ text: String)        // 每次 onChange 调用，无防抖（spec F7）

    /// 周末复习计划预占位条目迁移（spec F13）。幂等，由独立 migration key 保护。
    func performWeekendMigrationIfNeeded()
}
```

### 3.3 `ReviewViewModel` 扩展点

```swift
// 在 addHistoryEntry 末尾追加：写入 weeklyEntriesData
private func addHistoryEntry(title: String, baseDate: Date,
                             reviewDates: [Date],
                             type: HistoryEntry.ScheduleType) {
    var entries = historyEntries
    let newEntry = HistoryEntry(
        title: title, baseDate: baseDate,
        reviewDates: reviewDates, creationDate: Date(),
        type: type
    )
    entries.insert(newEntry, at: 0)
    if entries.count > 20 { entries = Array(entries.prefix(20)) }
    historyEntries = entries

    appendWeeklyEntry(from: newEntry)    // ← 新增：写入 weeklyEntriesData
    // appendWeeklyEntry 内部已实现 spec F10 周末复习计划双份规则
}
```

`createReviewSchedule()` 的成功分支按 `scheduleMode` 传入 `.review` / `.single`；`undoReviewSchedule()` 不动 weekly 数据（撤销仅删除日历事件，不回滚本地条目 — 保留"曾创建"的记录）。

### 3.4 `WeeklyEntry.appendWeeklyEntry` 周末双份规则（spec F10-F12）

```swift
func appendWeeklyEntry(from historyEntry: HistoryEntry) {
    var entries = weeklyEntries
    // 避免重复（同一 id：可能由迁移或重复触发产生）
    entries.removeAll { $0.id == historyEntry.id }

    let primary = WeeklyEntry(
        id: historyEntry.id, title: historyEntry.title,
        baseDate: historyEntry.baseDate, scheduleType: historyEntry.type,
        creationDate: historyEntry.creationDate,
        isPreOccupiedNextWeek: false
    )
    entries.append(primary)

    // 周末复习计划双份：写入下一周周一的预占位副本
    if historyEntry.type == .review,
       WeekCalculator.isWeekend(historyEntry.creationDate) {
        let nextMonday = WeekCalculator.nextWeekMonday(after: historyEntry.creationDate)
        // 防止同 id + 同 creationDate 出现两条（防御性）
        if !entries.contains(where: { $0.id == historyEntry.id && $0.creationDate == nextMonday }) {
            let placeholder = WeeklyEntry(
                id: historyEntry.id, title: historyEntry.title,
                baseDate: historyEntry.baseDate, scheduleType: historyEntry.type,
                creationDate: nextMonday,
                isPreOccupiedNextWeek: true   // UI 用以显示"下周复习"标签
            )
            entries.append(placeholder)
        }
    }

    persistWeeklyEntries(entries)
    revision &+= 1
}
```

### 3.5 周末预占位迁移（spec F13）

```swift
func performWeekendMigrationIfNeeded() {
    guard !defaults.bool(forKey: WeeklyReviewViewModel.weekendMigrationKey) else { return }

    let entries = weeklyEntries
    guard !entries.isEmpty else {
        defaults.set(true, forKey: WeeklyReviewViewModel.weekendMigrationKey)
        return
    }

    var result = entries
    var changed = false
    for entry in entries where !entry.isPreOccupiedNextWeek {
        guard entry.scheduleType == .review,
              WeekCalculator.isWeekend(entry.creationDate) else { continue }
        let nextMonday = WeekCalculator.nextWeekMonday(after: entry.creationDate)
        let exists = entries.contains(where: {
            $0.id == entry.id && $0.creationDate == nextMonday && $0.isPreOccupiedNextWeek
        })
        if exists { continue }
        result.append(WeeklyEntry(
            id: entry.id, title: entry.title, baseDate: entry.baseDate,
            scheduleType: entry.scheduleType, creationDate: nextMonday,
            isPreOccupiedNextWeek: true
        ))
        changed = true
    }

    if changed {
        persistWeeklyEntries(result)
        revision &+= 1
    }
    defaults.set(true, forKey: WeeklyReviewViewModel.weekendMigrationKey)
}
```

> 触发场景：
> 1. 1.5.1 之前版本已存在的 `WeeklyEntry`（无 `isPreOccupiedNextWeek` 字段），
>    当时创建时间恰好是周六/日但只写了一条。
> 2. 历史记录清理后再次迁移会引入单条，本方法会再补一份预占位。

### 3.6 预占位条目不计 X/Y（spec F14）

`totalCount` / `reviewedCount` 仅基于本周**真实条目**（`isPreOccupiedNextWeek == false`）。

```swift
/// 仅本周真实条目（不含预占位条目）。预占位条目不计 X / Y。
var realEntriesInCurrentWeek: [WeeklyEntry] {
    entriesInCurrentWeek.filter { !$0.isPreOccupiedNextWeek }
}

var reviewedCount: Int {
    let entries = realEntriesInCurrentWeek
    let reviewed = reviewedIds
    return entries.filter { reviewed.contains($0.id) }.count
}

var totalCount: Int {
    realEntriesInCurrentWeek.count
}
```

> 设计要点：
> - `reviewedIds` 仍是全局 `Set<UUID>`：勾选预占位条目仍会写入；真实条目（同 id）在另一周勾选状态自动同步。
> - 但进度条 X / Y 只看 `realEntriesInCurrentWeek` 与 `reviewedIds` 的交集：预占位条目本身的勾选不计入进度。
> - 副标题：预占位条目显示 `创建于 X · Y 所在周开始复习`，其中 X = 预占位条目 `creationDate` 中文格式、Y = 归档周周一（原创建所在周周一 = X - 7 天）；真实条目显示原本的 `baseDate · 类型`。

### 3.7 本地化文案（spec F11 修订）

| Key | 中文 | 用途 |
|---|---|---|
| ~~`weekly_review_next_week_tag`~~ | ~~"下周复习"~~ | **删除**：被 `weekly_review_pre_occupied_tag` 取代 |
| `weekly_review_pre_occupied_tag` | "上周周末创建" | 预占位条目右侧标签（`.secondary` 颜色，`.caption2`） |
| `weekly_review_pre_occupied_subtitle` | "创建于 %@ · %@ 所在周开始复习" | 预占位条目副标题（占位符：X = 创建日期，Y = 归档周周一） |

---

## 4. 模块交互

### 4.1 创建流程（数据同步）

```
用户点创建
  └─ ReviewViewModel.createReviewSchedule()
       ├─ CalendarManager.createReviewEvents / createSingleEvent
       ├─ addHistoryEntry(title, baseDate, dates, type)  // 改签名
       │    ├─ historyEntriesData 写入并截断 20
       │    └─ appendWeeklyEntry(newEntry)              // 新增
       │         └─ weeklyEntriesData 追加（无上限）
       └─ UI 刷新
```

<!-- review-fix: ISSUE-5 -->
### 4.2 周末总结查看流程

```
用户点「周末总结」按钮 (ContentView)
  └─ ContentView.showWeeklyReview = true
       └─ sheet → WeeklyReviewView(viewModel: WeeklyReviewViewModel())
            ├─ onAppear → vm.jumpToCurrentWeek()
            ├─ 周切换：vm.goToPreviousWeek / goToNextWeek
            │    ├─ [强制保存当前周笔记] commitNoteDraft()
            │    │    └─ notesJSON 写入（即使 TextEditor 没触发 onChange 也兜底）
            │    ├─ currentWeekStart 前进/后退 7 天
            │    └─ noteDraft = vm.currentWeekNote（重新加载新周）
            ├─ 勾选条目：EntryRow Checkbox → vm.toggleReviewed(id)
            │    └─ reviewedJSON 立即写入（无需保存按钮）
            └─ 编辑笔记：NoteEditor TextEditor onChange → vm.updateNote(text)
                 └─ notesJSON 立即写入
```

> 强制保存原因：TextEditor 的 `onChange` 在用户直接点"上一周/下一周"按钮时可能漏发
> （焦点丢失/系统事件打断），导致 noteDraft 未落盘就切周。`goToPreviousWeek/goToNextWeek`
> 进入时第一步调用 `commitNoteDraft()`，将当前 draft 强制写回当前 weekKey，再切换
> `currentWeekStart` 并重载新周 draft，避免笔记丢失或串到下一周。

### 4.3 历史记录 → 周末总结数据迁移

- 不做迁移（spec 没要求）。
- 旧的 `historyEntriesData` 缺 `type` → 自定义 `init(from:)` 默认为 `.review`（F9）。
- 旧的 history 条目**不**自动写入 weekly entries（spec F3 明确说"只列本 App 创建且创建时间落在所选周内" — 已删除的历史若未在创建时落库，汇总页不显示；接受此行为，因为旧 history 多数已被 20 上限截断）。

---

## 5. 文件组织

```
Sources/一键日历/
├── Models/
│   ├── HistoryEntry.swift          (✏️ 加 type 字段 + 自定义解码)
│   ├── ReviewEvent.swift           (不改)
│   └── WeeklyEntry.swift           (🆕 新文件)
├── ViewModels/
│   ├── ReviewViewModel.swift       (✏️ addHistoryEntry 加 type 参数 + 调 appendWeeklyEntry)
│   └── WeeklyReviewViewModel.swift (🆕 新文件)
├── Utils/
│   ├── DateFormatter+Extension.swift (不改)
│   └── WeekCalculator.swift        (🆕 新文件)
├── Views/
│   ├── ContentView.swift           (✏️ 加「周末总结」按钮卡片 + sheet)
│   ├── ... (其他 11 个子视图, 不改)
│   └── WeeklyReviewView.swift      (🆕 新文件, sheet 页)
├── Services/CalendarManager.swift  (不改)
└── Resources/zh.lproj/Localizable.strings  (✏️ 加周末总结相关 key)

Tests/一键日历Tests/
└── 一键日历Tests.swift             (✏️ 加 6 个新测试)
```

> 触发按钮卡片放在 `ContentView` 内（与历史记录按钮同样的内联风格），不另开 Section 文件。

---

## 6. 关键决策

| # | 决策点 | 选择 | 理由 | 否决的备选 |
|---|---|---|---|---|
| D1 | 周末总结数据存储 | 独立 JSON key (`weeklyEntriesData`)，与 history 分开 | spec F8 明确要求"独立于 20 条上限"，共用会被截断 | 复用 `historyEntriesData` |
| D2 | HistoryEntry 兼容性 | 自定义 `init(from:)` 默认 type = `.review` | spec F9 零迁移、不丢旧数据；Codable 透明 | 写一次性迁移代码 |
| D3 | 笔记存储粒度 | 一周一条，按 `weekKey` 做 key 的字典 | spec F7 要"按周独立存储"；切换周次时直接 O(1) 读写 | 每条笔记单独 key |
| D4 | 笔记自动保存 | 每次 `onChange` 立即写盘，无防抖 | spec F7 明确"每次编辑立即写入" | 500ms 防抖（仍可能丢数据） |
| D5 | 周首日 | 强制 Monday（`Calendar.firstWeekday = 2`），不跟随系统 locale | spec N2 明确"周一为一周第一天" | 跟随系统 |
| D6 | 撤销对周末总结的影响 | 撤销只删日历事件，不删 weekly entry | 避免反复撤销/重做导致汇总页闪烁；保留"用户曾学习"的轨迹 | 同步删除 weekly entry |
| D7 | 入口形式 | 主窗口新增按钮卡片 → sheet（沿用 HistorySection 模式） | 与现有 UI 风格一致；spec F1 只要求"入口" | 单独 Window / NavigationStack |
| D8 | 勾选状态存储 | `Set<UUID>` 序列化为 JSON 数组 | Set 直接 JSONEncoder 不友好；数组简单 | 自定义 Codable for Set |
| D9 | ScheduleType 定义位置 | 放在 `HistoryEntry` 内，`WeeklyEntry` 复用 | 避免两个独立 enum；保证语义一致 | 各定义一份 |
| D10 | 周范围显示文案 | 复用 `Date.formattedChinese()`：`周一日期~周日日期` | 已有中文格式化器，无新依赖 | 新建 formatter |

<!-- review-fix: tech-debt-supplements -->
### 已知技术债（暂不处理）

- 周切换按钮快速连点时 `noteDraft` 与 `currentWeekNote` 可能短暂不同步 → 当前靠 `commitNoteDraft()` + onChange 双重同步写盘，下次进入页面时以持久值为准，可接受。
- weekly entries 没有"删除条目"入口（spec 不要求）→ 不实现。
- 多窗口/多 sheet 同时打开同一周的笔记 → 不支持，App 只有一个主窗口。
- **撤销与旧数据迁移不一致**：D6 规定 `undoReviewSchedule` 只删日历事件、不删 weekly entry，
  但旧 history 条目从未被写入 `weeklyEntriesData`（spec F3 约束"只列本 App 创建且创建时间落在所选周内"），
  所以会同时出现"history 删了但 weekly 还在"和"history 在但 weekly 缺"两种不对称场景。
  接受当前行为（保留"曾学习"轨迹 + 旧数据零迁移），但日后若加 weekly 删除入口，需补一致化迁移。
- **UserDefaults 体积风险**：三个新 key（`weeklyEntriesData / weeklyReviewStateData / weeklyNotesData`）
  均无上限 + UserDefaults 全量加载到内存；用户长期使用后笔记 + 条目 JSON 可能达到 MB 级，
  启动时解码阻塞主线程。当前不加限流；若实测出现卡顿，需迁移到 SwiftData / 文件存储 + 分页加载。

---

## 7. F → 模块映射

| 需求 | 涉及文件 | 涉及接口/类型 |
|---|---|---|
| **F1** 主界面入口 + 独立页面 | `ContentView.swift`（按钮 + sheet）<br>`Views/WeeklyReviewView.swift` | `@Published var showWeeklyReview`（在 ReviewViewModel） |
| **F2** 周范围展示（周一~周日） | `Utils/WeekCalculator.swift`<br>`Views/WeeklyReviewView.swift`（标题栏） | `WeekCalculator.weekRange(for:)` |
| **F3** 仅本 App 创建 + 单次展示 + 不含复习重复日期 | `Models/WeeklyEntry.swift`（带 creationDate）<br>`ViewModels/WeeklyReviewViewModel.entriesInCurrentWeek` | `creationDate ∈ [weekStart, weekEnd]` 过滤；不展开 reviewDates |
| **F4** 展示字段 + 按创建日期分组 | `Views/WeeklyReviewView.swift`（EntryRow） | `entriesGroupedByCreationDate`（Section 按日期） |
| **F5** 上一周/下一周按钮 + 空状态 | `Views/WeeklyReviewView.swift`<br>`ViewModels/WeeklyReviewViewModel.swift` | `goToPreviousWeek / goToNextWeek / canGoToNextWeek` |
| **F6** 勾选框 + X/Y 进度 | `Views/WeeklyReviewView.swift`（Checkbox + ProgressBar）<br>`ViewModels/WeeklyReviewViewModel.swift` | `toggleReviewed(_:) / reviewedCount / totalCount` |
| **F7** 自动保存笔记 + 按周独立 | `Views/WeeklyReviewView.swift`（TextEditor onChange）<br>`ViewModels/WeeklyReviewViewModel.swift` | `updateNote(_:) → notesJSON`<br>`currentWeekKey` 作字典 key |
| **F8** 永久本地 + 不受 20 上限影响 | `Sources/一键日历/Views/...` 数据写入路径 | `weeklyEntriesData / weeklyReviewStateData / weeklyNotesData` 三 key 都不截断 |
| **F9** 旧 history 兼容读取 | `Models/HistoryEntry.swift`（自定义解码） | `init(from:)` 缺 `type` 字段默认 `.review` |
| **F10** 周末复习计划双份 | `WeeklyReviewViewModel.appendWeeklyEntry` | `WeekCalculator.isWeekend` + `nextWeekMonday` |
| **F11** "上周周末创建"标签 + `.secondary` 颜色 + 副标题 | `Views/WeeklyReviewView.swift`（entryRow） | `entry.isPreOccupiedNextWeek` → 标签；`entry.creationDate` + `WeekCalculator.addingWeeks(-1, to:)` → 副标题 |
| **F12** 单次日程 / 周一至周五不复制 | `WeeklyReviewViewModel.appendWeeklyEntry` | 类型 + 周几判定 |
| **F13** 旧 WeeklyEntry 补预占位迁移 | `WeeklyReviewViewModel.performWeekendMigrationIfNeeded` | `weekendMigrationKey` 幂等保护 |
| **F14** 预占位条目不计 X / Y | `WeeklyReviewViewModel.realEntriesInCurrentWeek` | `totalCount` / `reviewedCount` 仅过滤 `isPreOccupiedNextWeek == false` |

### 非功能需求映射

| 需求 | 落地点 |
|---|---|
| N1 平台/语言/EK/中文 | 沿用现有 `defaultLocalization: "zh"` + `Localizable.strings`；新 key 加中文条目 |
| N2 周首日 + 本地时区 | `WeekCalculator` 内固定 `firstWeekday = 2`，所有计算走 `Calendar.current` |
| N3 无网络 | 纯本地 UserDefaults，无 URLSession/网络调用 |
| N4 现有流程不变 | `createReviewSchedule / undoReviewSchedule / 权限 / 窗口` 路径不修改行为；只在 `addHistoryEntry` 末尾追加 weekly 写入 |

---

## 8. 测试新增（不修改现有 13 个测试）

`Tests/一键日历Tests/一键日历Tests.swift` 追加：

1. `testWeekCalculatorMondayStart` — 给定周三 → 返回本周周一 00:00:00。
2. `testWeekCalculatorAcrossYearBoundary` — 跨年周次正确。
3. `testWeeklyEntryCodable` — 编解码一致。
4. `testHistoryEntryBackwardCompatMissingType` — JSON 不带 type → 解码为 `.review`。
5. `testWeeklyReviewToggleAndPersist` — `toggleReviewed` 改变 reviewedIds；模拟持久化往返。
6. `testWeeklyReviewWeekBoundary` — 当前周切换后 `entriesInCurrentWeek` 过滤正确；不包含其他周的条目。
7. `testWeekendReviewSaturdayAppendsNextWeekEntry` — spec F10：周六创建复习计划 → 双份，第二条 creationDate = 下一周周一 00:00 且 isPreOccupiedNextWeek = true；下周页面可查到同 id 条目。
8. `testWeekendReviewSundayAppendsNextWeekEntry` — spec F10：周日创建复习计划 → 双份，creationDate 同样跳到下一周周一。
9. `testSingleScheduleNotDuplicatedOnWeekend` — spec F12：单次日程不双份；下周页面查不到。
10. `testWeekdayReviewNotDuplicated` — spec F12：周五/周一复习计划不双份。
11. `testWeekendMigrationBackfillsNextWeekEntry` — spec F13：旧 WeeklyEntry（创建时间周六/日 + .review）由一次性迁移补一份预占位；幂等。
12. `testPreOccupiedEntryNotCountedInTotalAndReviewedCount` — spec F14：周六复习计划在创建所在周产生双份；本周 `totalCount == 1`（不含预占位），勾选后 `reviewedCount == 1`。
13. `testPreOccupiedEntryCountedSeparatelyOnNextWeek` — spec F14：跳到"周六所在周的下一周"页面时仅含预占位条目；`totalCount == 0`，勾选不影响 `reviewedCount`。
14. `testMixedRealAndPreOccupiedProgress` — spec F14：本周混合 3 条真实条目 + 1 条预占位时，`totalCount == 3`，勾选预占位不计入 `reviewedCount`。

> ViewModel 测试统一 `@MainActor` 隔离（与现有 `testViewModelValidation` 一致）。

---

## 9. 实施顺序（阶段三）

1. **WeekCalculator** + 单元测试（独立无依赖）
2. **WeeklyEntry** 模型
3. **HistoryEntry** 加 `type` + 自定义解码 + 兼容测试
4. **WeeklyReviewViewModel** + 测试
5. **ReviewViewModel.addHistoryEntry** 扩展（写入 weekly）+ 回归测试
6. **WeeklyReviewView** + **ContentView** 入口按钮 + sheet
7. **Localizable.strings** 中文 key
8. `swift build && swift test` 全绿 → 验收 AC1–AC11
