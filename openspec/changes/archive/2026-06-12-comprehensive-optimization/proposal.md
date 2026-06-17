## Why

基于对项目的全面代码审查，发现项目存在以下问题，需要一次综合优化：

### 必须修复的质量缺陷（Critical）
- **崩溃风险**：`ReviewEvent.swift`、`CalendarManager.swift`、`ReviewViewModel.swift` 三处核心文件存在 `!` 强制解包，任何日期计算异常都可能导致运行时崩溃
- **内存泄漏**：`ReviewViewModel.swift` 中的 NotificationCenter 观察者未保存 token 或移除，在 ViewModel 释放时导致泄漏
- **测试基础设施损坏**：`swift test` 无法运行（XCTest 模块缺失），测试代码自身也存在 `!` 强制解包
- **测试注释与代码矛盾**：`一键日历Tests.swift` 中 `testDateCalculation` 的注释说 Jan 31 + 30 = March 1，但断言期望 March 2，误导维护者

### 需要修复的代码质量问题
- **重复逻辑**：日期计算（+3/+7/+30 天）在 `ReviewEvent`、`CalendarManager`、`ReviewViewModel` 中重复实现，违反 DRY 原则
- **未使用模型**：`ReviewEvent` 结构体定义后未被核心逻辑使用，成了死代码
- **重复检测不精确**：`CalendarManager.checkDuplicate` 仅比较标题，导致同标题不同内容被误报为重复
- **硬编码字符串**：`ContentView` 和 `ReviewViewModel` 中大量使用中文字符串字面量，未使用已有的 `Localizable.strings`
- **未使用错误类型**：`CalendarError` 中 `permissionDenied` case 定义但从未抛出
- **视图臃肿**：`ContentView.swift` 102 行包含所有 UI 元素，难以维护和测试

### 用户体验增强
- **缺少撤销功能**：用户创建日程后无法撤销，发现输错标题需要到系统日历手动删除
- **缺少历史记录**：应用关闭后无法查看之前创建过哪些复习计划
- **缺少自定义间隔**：复习间隔固定为 3/7/30 天，用户无法根据需求调整

## What Changes

### 1. 修复崩溃风险
- 移除 `ReviewEvent.swift`、`CalendarManager.swift`、`ReviewViewModel.swift` 中所有 `!` 强制解包
- 使用 `guard let` 计算日期，若 `Calendar.date(byAdding:)` 返回 `nil`，则记录错误并跳过该事件
- 移除 `一键日历Tests.swift` 中所有 `!` 强制解包，使用 `guard let` 或 `XCTUnwrap`

### 2. 激活并统一 ReviewEvent 模型
- 将 `ReviewEvent` 升级为包含日期计算能力的模型：新增 `calculateReviewDates(from:intervals:)` 静态方法
- 统一 `CalendarManager` 和 `ReviewViewModel` 中的日期计算逻辑，全部调用 `ReviewEvent` 的方法
- 使 `ReviewEvent` 成为日期计算的单一真相源

### 3. 修复测试基础设施
- 修复 `Package.swift` 或构建环境配置，解决 `XCTest` 模块缺失问题
- 修正 `testDateCalculation` 的注释：`Jan 31 + 30 = March 2`（2026 非闰年）

### 4. 修复 NotificationCenter 内存泄漏
- 在 `ReviewViewModel` 中保存 `NotificationCenter.addObserver` 返回的 token
- 在 `deinit` 中调用 `NotificationCenter.removeObserver` 移除该 token

### 5. 改进重复检测
- 修改 `CalendarManager.checkDuplicate`：从仅比较标题改为比较 **标题 + 日期（精确到天）+ 备注内容**
- 确保同标题不同日期、或同标题不同备注的事件不被误报为重复

### 6. 国际化（Localization）
- 将 `ContentView.swift` 和 `ReviewViewModel.swift` 中所有硬编码中文字符串替换为 `NSLocalizedString`
- 在 `Localizable.strings` 中补充所有新增 UI 文本键：撤销按钮、历史记录、设置面板、自定义间隔、输入验证错误等
- 移除 `CalendarError` 中未使用的 `permissionDenied` case，或确保权限拒绝时正确抛出

### 7. 视图拆分
- 将 `ContentView.swift`（102 行）拆分为 4 个独立子视图：
  - `TitleInputSection`：标题输入框和标签
  - `DatePickerSection`：日期选择器和 `onChange` 逻辑
  - `ReviewPreviewSection`：复习日期预览列表
  - `ActionSection`：创建按钮、加载状态、结果消息、权限按钮、撤销按钮

### 8. 撤销功能
- 在 `CalendarManager` 中保存最近一次成功创建的 3 个 `EKEvent` 的 `eventIdentifier`（`lastCreatedEventIdentifiers: [String]?`）
- 实现 `undoLastCreation() async -> Bool` 方法，通过 `eventStore.event(withIdentifier:)` 删除并返回结果
- 在 `ReviewViewModel` 中增加 `canUndo: Bool`，在 `ActionSection` 中显示撤销按钮
- 处理撤销失败：若事件已被手动删除，显示警告并禁用撤销按钮

### 9. 历史记录
- 创建 `HistoryEntry` 结构体（`title`, `baseDate`, `reviewDates`, `creationDate`），符合 `Codable`
- 使用 `@AppStorage` 以 JSON 形式存储历史记录列表，限制最多 20 条
- 创建 `HistorySection` 视图：显示历史列表，点击条目可填充标题和日期到主界面
- 实现 `clearHistory()` 方法，显示确认提示后清除所有历史

### 10. 自定义间隔
- 使用 `@AppStorage` 存储 `reviewIntervals: [Int]`，默认 `[3, 7, 30]`
- 创建 `IntervalSettingsSection` 视图：3 个输入框修改间隔值，支持 "恢复默认" 按钮
- 在 `IntervalSettingsSection` 中增加输入验证：间隔必须为正整数且至少 1 天
- 更新 `ReviewEvent.calculateReviewDates` 接受自定义间隔数组
- 更新 `ReviewViewModel` 预览逻辑，使用 `reviewIntervals` 动态计算

### 11. 输入验证
- 在 `ReviewViewModel.createReviewSchedule()` 中增加标题验证：
  - 非空检查（`trimmingCharacters(in: .whitespaces)` 后仍为空则拒绝）
  - 长度限制（最多 100 字符）

### 12. 确认 onChange 兼容性
- 确认 `ContentView` 中使用的 `onChange(of:initial:_:)` 签名（Swift 6.0 / macOS 14+）在当前平台要求下无兼容性问题

## Capabilities

### New Capabilities
- `undo-review-creation`: 撤销最近创建的复习日程功能（保存 eventIdentifier 并删除）
- `review-history`: 保存和展示最近创建的复习日程历史记录（`@AppStorage` + JSON，最多 20 条）
- `custom-review-intervals`: 允许用户自定义复习间隔天数（默认 3/7/30，可恢复默认值）
- `view-modularization`: 将主视图拆分为独立的子视图组件（4 个职责单一的子视图）

### Modified Capabilities
- `review-calendar-creation`: 现有复习日程创建功能的需求变更：
  - 将日期计算逻辑统一提取到 `ReviewEvent` 模型，使用 `guard let` 安全计算
  - 改进重复检测逻辑：从仅比较标题改为比较标题 + 日期 + 备注
  - 支持国际化：所有 UI 文本和错误消息使用 `NSLocalizedString`
  - 增加输入验证：标题非空检查、空白字符 trim、长度限制 100 字符
  - 修复 NotificationCenter 观察者生命周期管理，防止内存泄漏
  - 修复测试基础设施和测试注释准确性

## Risks / Limitations

- **视图拆分增加文件数量**：从 1 个视图变为 5 个视图文件，但每个子视图职责单一（< 50 行），通过清晰命名缓解
- **`@AppStorage` 存储容量有限**：历史记录限制最多 20 条，超过时自动移除最旧条目；不适合大量数据，但本项目数据量小
- **撤销功能依赖 `eventIdentifier`**：如果用户在系统日历中手动删除或修改事件，撤销会失效。通过友好的错误提示（"部分事件已被删除"）处理
- **自定义间隔可能与艾宾浩斯理论冲突**：UI 中提供默认推荐值（3/7/30），允许用户修改但不做理论验证
- **`onChange` API 版本要求**：使用的 `onChange(of:initial:_:)` 需要 Swift 6.0 / macOS 14+，与项目当前平台要求一致

## Impact

- **Swift 源文件**：`Sources/一键日历/` 下的所有 `.swift` 文件需要修改
- **测试文件**：`Tests/一键日历Tests/一键日历Tests.swift` 需要重构（移除 `!`、修正注释、扩展覆盖）
- **测试基础设施**：`Package.swift` 可能需要调整测试目标配置以修复 XCTest 模块缺失
- **本地化资源**：`Localizable.strings` 需要补充大量新增键值
- **用户界面**：`ContentView` 结构将大幅调整（拆分为 4 个子视图），UI 布局保持不变但内部实现重构
- **App 入口**：`一键日历App.swift` 的命令菜单和通知可能需要适配新视图结构
- **文档**：`README.md` 需要更新以反映新增功能（撤销、历史、自定义间隔）
- **依赖**：无新增外部依赖
- **向后兼容**：功能上非破坏性，但 UI 内部实现大幅重构

## Success Criteria

- `swift build` 无编译错误、无警告
- `swift test` 全部测试通过（包括新增测试）
- 所有 `.swift` 文件中无 `!` 强制解包（除必要的 Optional 操作外）
- 所有硬编码中文字符串已被替换为 `NSLocalizedString`，且所有键在 `Localizable.strings` 中存在
- 所有新增功能在 UI 中正常工作：撤销、历史记录、自定义间隔、视图渲染
- `openspec archive` 可成功归档
