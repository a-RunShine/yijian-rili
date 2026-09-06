# 周末总结功能 复盘

## 背景

为了让用户按周回顾“通过本 App 添加的学习内容”，并在周末进行总结与复习标记，新增“周末总结”栏目。从 1.4.0 升级到 1.5.1 后并入本功能。

主要诉求：

- 按周查看本 App 新增的学习内容，不重复展示自动复习日期；
- 提供复习计划与单次日程区分；
- 支持复习勾选与每周总结笔记；
- 永久本地保存，独立于现有 20 条历史记录限制。

## 关键决策

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

## 流程改进

- `WeeklyReviewViewModel` 引入 `defaults` 注入点，所有持久化通过 `UserDefaults` 实例完成，避免 `@AppStorage` 在非 View 类的初始化时序坑。
- 迁移幂等保护使用 `Bool` 单一 key 而非版本号，便于未来回退不重复执行。
- 总结页 UI 入口位置在 `ContentView` 的 `TodayEventsSection` 之后，与“今日”信息密度一致。
- 历史记录按钮位置不变，避免同时调整两个常驻入口导致用户找不到原位置。

## 已知技术债

- **撤销与旧数据迁移不对称**：撤销只删日历事件、不删 weekly entry；旧 history 条目从未被自动迁移到 weekly，导致“history 在但 weekly 缺”与“history 删了但 weekly 还在”两种不对称。暂不处理；若用户反馈明显，加 `isRevoked` 软标记。
- **UserDefaults 体积风险**：三个新 key 均无上限 + 全量加载主线程解码；长期使用后可能膨胀。暂不处理；未来若 weeklyEntries > 1000 条需评估迁移到 SwiftData / 文件存储 + 分页加载。
- **多窗口/多 sheet 同时打开同一周的笔记**：不支持，App 只有一个主窗口。
- **周切换按钮快速连点**：`noteDraft` 与 `currentWeekNote` 可能短暂不同步，靠 `commitNoteDraft()` + onChange 双重写盘兜底。
- **未做 GUI 手动回归**：本版本主要靠单元测试覆盖数据/计算正确性，UI 交互尚未做正式的手动验收清单。
