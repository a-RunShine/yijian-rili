# 周末总结功能 复盘

## 背景

为了让用户按周回顾“通过本 App 添加的学习内容”，并在周末进行总结与复习标记，新增“周末总结”栏目。从 1.4.0 升级到 1.5.1 后并入本功能。

主要诉求：

- 按周查看本 App 新增的学习内容，不重复展示自动复习日期；
- 提供复习计划与单次日程区分；
- 支持复习勾选与每周总结笔记；
- 永久本地保存，独立于现有 20 条历史记录限制。

## 增量迭代：周末复习计划双份（1.5.1 → 1.5.2）

在 1.5.1 基础上追加新需求：当用户**周六/周日**通过本 App 创建复习计划时，在周末总结中需要**双份显示**——本周 + 下一周周一 00:00，并由 UI 加“下周复习”标签区分预占位条目。单次日程以及周一至周五创建的复习计划不复制；已存在但未补预占位的旧 `WeeklyEntry` 由一次性迁移补齐。

### 关键决策

- **`WeeklyEntry.isPreOccupiedNextWeek`**：在 `WeeklyEntry` 上加一个 `Bool` 字段（默认 `false`，自定义解码兼容旧 JSON）。比起从 `creationDate` 推断，字段更显式、可读，且便于 UI 区分。
- **预占位 `creationDate = 下一周周一 00:00`**：使用 `WeekCalculator.nextWeekMonday(after:)` 统一计算（基于当前周首日 + 7 天），保证与周计算口径一致。
- **`appendWeeklyEntry` 同步写入双份**：直接在 ViewModel 内分支，单次日程 / 工作日复习直接走原路径，周末复习追加预占位副本（同一 `id`，`isPreOccupiedNextWeek = true`）。
- **独立迁移 key `weeklyEntriesWeekendMigrationDone`**：避免与历史记录迁移 `weeklyEntriesHistoryMigrationDone` 互相干扰；幂等可重入。
- **不放开 `canGoToNextWeek`**：保留 spec F5 “当前周时下一周按钮禁用”的规则；预占位条目对用户而言仍位于下一周，UI 通过“下周复习”标签显式标注，避免规则反复漂移。
- **UI 标签用 `.secondary` 颜色 + 半透明背景**：与现有“日程类型”色块区分，避免视觉权重过高；`isPreOccupiedNextWeek = true` 时只在标题右侧显示，不影响勾选 / 笔记行为。
- **测试隔离**：所有 5 个新测试都使用 `UserDefaults(suiteName:)` + `defer` 清理，确保不污染 `.standard`，也避免跨用例状态泄漏。

## 关键决策（1.5.1 基础版）

- **数据独立存储**：使用三个独立的 `UserDefaults` JSON 键：
  - `weeklyEntriesData`（无上限）
  - `weeklyReviewStateData`（已复习 id 集合）
  - `weeklyNotesData`（按周 key 字典）
  - 满足 spec “独立于 20 条历史上限，永久保存”。
- **向后兼容旧历史记录**：`HistoryEntry` 新增 `type` 字段，自定义 `init(from:)` 缺字段时默认 `.review`，避免旧 JSON 解析失败。
- **一次性数据迁移**：首次启动新版本时自动把 `historyEntriesData` 中现存条目复制为 `WeeklyEntry`（按原 `creationDate` 归档），写入完成后打上 migration key 防止重复。
- **周首日固定周一**：`WeekCalculator` 强制 `Calendar.firstWeekday = 2`，不跟随系统 locale，避免历史周划分变动。
- **笔记自动保存**：`TextEditor.onChange` → `updateNote` 立即写盘；周切换入口先 `commitNoteDraft` 兜底，防止 SwiftUI 焦点切换丢字。
- **未来周禁用**：通过 `canGoToNextWeek` 计算属性严格控制，防止“下一周”按钮让用户进入未来空周。
- **撤销不动周总结数据**：`undoReviewSchedule` 只删除日历事件，保留“曾创建”的轨迹，简化 DTO 状态。
- **入口放在主界面顶部**：紧跟“今日日程”下方，使用频率与“今日”相同，放底部容易因 ScrollView 滚到深处被忽略。

## 踩坑

### 1. `make install` 不会让“周总结”自动出现旧数据

**症状**：用户安装新版本后，发现本周已经在 App 里添加的日程在“周末总结”里看不到。

**原因**：旧数据保存在 `historyEntriesData`（最多 20 条且不分周），新功能的 `weeklyEntriesData` 初始为空；首次实现没有一次性迁移逻辑。

**修复**：在 `WeeklyReviewViewModel.init` 中新增 `performHistoryMigrationIfNeeded()`，仅在 `weeklyEntriesHistoryMigrationDone` 未置位时执行。完成后写回合并后的 weekly entries 并设置幂等保护。补 2 个测试覆盖：常规迁移 + 空/损坏 JSON 边界。

**教训**：

- 任何新功能如果引入“独立于旧数据”的存储，必须明确**迁移策略**（自动迁移、一次性回填、或者文档明示用户需重新操作）。
- 此类迁移应**默认开启**而不是依赖用户手动触发。

### 2. `WeeklyReviewViewModel` 测试时不应污染 `.standard`

**症状**：第一次写迁移测试时直接使用 `UserDefaults.standard`，导致单测运行时在 `~/Library/Preferences/com.yijianrili.app.plist` 中残留测试 key。

**修复**：迁移测试改用 `UserDefaults(suiteName: "test-weekly-migration-<UUID>")` 隔离，并在 `defer` 中清理 suite 与持久化域。增加 `.standard.dictionaryRepresentation()` 前后差异断言。

**教训**：在 `@MainActor` VM 测试中要始终明确 `defaults` 注入点；推荐 `init(defaults: UserDefaults = .standard)` 让测试可注入 suite。

### 3. JSON 日期策略在测试中容易踩坑

**症状**：写测试 fixture 时使用 `2001-01-01T00:00:00Z` 之类的日期字符串，迁移测试运行后时间字段全部对不上。

**原因**：生产代码 `JSONEncoder/JSONDecoder` 使用默认的 `dateEncodingStrategy`，输出的是 reference date（2001-01-01 0:00 UTC）以来的 `TimeInterval`。

**修复**：测试 fixture 改用 `Date(timeIntervalSinceReferenceDate: ...)` 构造，匹配生产实际格式。

**教训**：

- 涉及日期字段的 Codable 测试，优先用 `Date` 常量构造而非字符串。
- 如果未来要支持 ISO8601，应在 `JSONEncoder` 上显式 `dateEncodingStrategy = .iso8601` 并加测试守护。

### 4. 子代理实现 / 验证轮次较长

**症状**：在自动续期目标中，子代理实现周末总结功能时多次停留在分析阶段，工作区迟迟未落地。

**教训**：

- 在多目标轮次的场景下，子代理必须**“先落地最小可用，再迭代”**；分析阶段应严格限定时间。
- 实施代理应在第一轮交出可运行产物（即便不完整），后续轮次做加固和优化。

### 5. 测试依赖真实 `Date()` 容易踩坑（1.5.2）

**症状**：写 `testWeeklyReviewWeekBoundary` 时直接使用 `Date()` 作为 `creationDate`，CI 上刚好碰到周末时，`appendWeeklyEntry` 触发了周末双份规则，`canGoToNextWeek` 行为随之变化，原断言失败。

**修复**：测试用例改用 `thisMonday + 2 天`（周三）作为 `creationDate`，显式落在工作日；只有真正测试周末双份规则的 5 个新测试才用周六/日。

**教训**：

- 涉及 `Date()` 的测试尽量用确定日期构造，避免依赖运行时是周几。
- “周末双份规则”类的功能天然依赖日历，测试时要把日期固定到目标周几上。

### 6. "下一周"按钮禁用规则 vs 预占位条目可见性的权衡（1.5.2）

**症状**：周末复习计划产生下一周周一的预占位条目，但 `canGoToNextWeek` 在当前周时禁用，导致用户看不到下一周预占位。

**解决**：保留 `canGoToNextWeek` 规则不变（spec F5 明确"位于当前周时下一周按钮禁用"），仅在 UI 上加“下周复习”标签；用户可以通过其他方式（如点击历史周、再向前一周）看到预占位，或者未来再加一个“跳到有预占位的下一周”快捷按钮（暂不实现）。

**教训**：

- 不要因为新功能而修改既有规则；规则变更要明确反馈到 spec。
- 当新功能与既有规则冲突时，优先用 UI 显式标注（"下周复习"标签）弥补可见性，而不是破坏规则。

## 流程改进

- `WeeklyReviewViewModel` 引入 `defaults` 注入点，所有持久化通过 `UserDefaults` 实例完成，避免 `@AppStorage` 在非 View 类的初始化时序坑。
- 迁移幂等保护使用 `Bool` 单一 key 而非版本号，便于未来回退不重复执行。
- 总结页 UI 入口位置在 `ContentView` 的 `TodayEventsSection` 之后，与“今日”信息密度一致。
- 历史记录按钮位置不变，避免同时调整两个常驻入口导致用户找不到原位置。
- 周末预占位条目用独立 `isPreOccupiedNextWeek` 标记而非从日期推断，让 UI 与数据迁移逻辑都更简单明确。

## 已知技术债

- **撤销与旧数据迁移不对称**：撤销只删日历事件、不删 weekly entry；旧 history 条目从未被自动迁移到 weekly，导致“history 在但 weekly 缺”与“history 删了但 weekly 还在”两种不对称。暂不处理；若用户反馈明显，加 `isRevoked` 软标记。
- **UserDefaults 体积风险**：三个新 key 均无上限 + 全量加载主线程解码；长期使用后可能膨胀。暂不处理；未来若 weeklyEntries > 1000 条需评估迁移到 SwiftData / 文件存储 + 分页加载。
- **多窗口/多 sheet 同时打开同一周的笔记**：不支持，App 只有一个主窗口。
- **周切换按钮快速连点**：`noteDraft` 与 `currentWeekNote` 可能短暂不同步，靠 `commitNoteDraft()` + onChange 双重写盘兜底。
- **预占位条目可见性**：周末双份规则产生的下一周周一预占位条目，`canGoToNextWeek` 在当前周时禁用，用户只能通过“下一周”按钮或直接跳转查看。考虑未来加一个“跳到有预占位的下一周”快捷入口。
- **未做 GUI 手动回归**：本版本主要靠单元测试覆盖数据/计算正确性，UI 交互尚未做正式的手动验收清单。
