## 1. 基础修复

- [x] 1.1 移除 `ReviewEvent.swift` 中的 `!` 强制解包，使用 `guard let` 计算日期
- [x] 1.2 移除 `CalendarManager.swift` 中的 `!` 强制解包，使用 `guard let` 计算日期
- [x] 1.3 移除 `ReviewViewModel.swift` 中的 `!` 强制解包，使用 `guard let` 计算日期
- [x] 1.4 修复 `ReviewViewModel.swift` 中 NotificationCenter 观察者生命周期：保存 token 并在 `deinit` 中移除
- [x] 1.5 修正 `一键日历Tests.swift` 中 `testDateCalculation` 的注释与代码矛盾（Jan 31 + 30 = March 2）
- [~] 1.6 解决 XCTest 模块缺失问题，使 `swift test` 能够正常运行（**阻塞**：系统只有 CommandLineTools，无完整 Xcode 安装，缺少 XCTest 框架）

## 2. 重构日期计算

- [x] 2.1 在 `ReviewEvent.swift` 中创建 `calculateReviewDates(from:)` 静态方法，统一计算 3/7/30 天后的日期
- [x] 2.2 将 `ReviewEvent` 升级为包含日期计算能力的模型，替换 `CalendarManager` 和 `ReviewViewModel` 中的重复计算逻辑
- [x] 2.3 确保 `ReviewEvent` 的 `reviewDates` 初始化使用安全计算，处理 `nil` 情况
- [x] 2.4 更新 `ReviewViewModel` 中的 `updateReviewDates()` 方法，调用 `ReviewEvent` 的计算方法

## 3. 国际化与输入验证

- [x] 3.1 在 `ContentView.swift` 中，将所有硬编码中文字符串替换为 `NSLocalizedString` 或 SwiftUI 本地化键
- [x] 3.2 在 `ReviewViewModel.swift` 中，将所有硬编码消息字符串替换为本地化键
- [x] 3.3 在 `Localizable.strings` 中补充所有缺失的 UI 文本键值（包括撤销、历史、设置等）
- [x] 3.4 在 `ReviewViewModel.swift` 的 `createReviewSchedule()` 中增加标题空白字符检查：`trimmingCharacters(in: .whitespaces)`
- [x] 3.5 在 `ReviewViewModel.swift` 中增加标题长度限制（最多 100 字符）
- [x] 3.6 移除 `CalendarError` 枚举中未使用的 `permissionDenied` case，或在权限拒绝时正确抛出

## 4. 改进重复检测

- [x] 4.1 修改 `CalendarManager.swift` 中的 `checkDuplicate` 方法，比较标题+日期+备注内容
- [x] 4.2 在 `checkDuplicate` 中增加 `notes` 参数匹配，确保同一日期不同内容不被误报
- [x] 4.3 更新 `createReviewEvents` 方法，将 `index` 和 `reviewDate` 传入 `checkDuplicate` 以匹配备注
- [~] 4.4 测试改进后的重复检测逻辑：同标题不同日期不应触发重复警告（**依赖**：XCTest 模块缺失）

## 5. 视图拆分

- [x] 5.1 创建 `TitleInputSection.swift`，包含标题文本框和标签
- [x] 5.2 创建 `DatePickerSection.swift`，包含日期选择器和 `onChange` 逻辑
- [x] 5.3 创建 `ReviewPreviewSection.swift`，包含复习日期预览列表
- [x] 5.4 创建 `ActionSection.swift`，包含创建按钮、加载状态、结果消息、权限按钮、撤销按钮
- [x] 5.5 重构 `ContentView.swift`，组合以上四个子视图，保持原有布局和功能
- [x] 5.6 确保子视图通过 `@ObservedObject` 或绑定正确接收 ViewModel 状态

## 6. 撤销功能

- [x] 6.1 在 `CalendarManager.swift` 中增加 `lastCreatedEventIdentifiers: [String]?` 属性
- [x] 6.2 在 `createReviewEvents` 成功时，保存三个 `event.eventIdentifier` 到 `lastCreatedEventIdentifiers`
- [x] 6.3 在 `CalendarManager.swift` 中实现 `undoLastCreation() async -> Bool` 方法，删除保存的事件
- [x] 6.4 在 `ReviewViewModel.swift` 中增加 `canUndo: Bool` 和 `undoReviewSchedule()` 方法
- [x] 6.5 在 `ActionSection` 中添加撤销按钮，仅在 `canUndo` 为 true 时显示
- [x] 6.6 处理撤销失败情况：事件已被手动删除时显示警告

## 7. 历史记录

- [x] 7.1 创建 `HistoryEntry` 结构体（title, baseDate, reviewDates, creationDate），符合 `Codable`
- [x] 7.2 在 `ReviewViewModel.swift` 中使用 `@AppStorage` 存储 `historyEntries` JSON 数据
- [x] 7.3 实现 `addHistoryEntry` 方法，在创建成功后追加到历史记录，限制最多 20 条
- [x] 7.4 创建 `HistorySection.swift` 视图，显示历史列表，点击可填充标题和日期
- [x] 7.5 实现 `clearHistory()` 方法，显示确认提示后清除所有历史
- [x] 7.6 确保历史记录在应用重启后仍然可用

## 8. 自定义间隔

- [x] 8.1 在 `ReviewViewModel.swift` 中使用 `@AppStorage` 存储 `reviewIntervals: [Int]`（默认 [3, 7, 30]）
- [x] 8.2 创建 `IntervalSettingsSection.swift`，允许用户修改三个间隔值
- [x] 8.3 在 `IntervalSettingsSection` 中增加输入验证：间隔必须为正整数且至少为 1
- [x] 8.4 更新 `ReviewEvent` 的计算方法，接受自定义间隔数组作为参数
- [x] 8.5 更新 `ReviewViewModel` 中的预览逻辑，使用 `reviewIntervals` 动态计算
- [x] 8.6 在 `IntervalSettingsSection` 中添加 "恢复默认" 按钮，重置为 [3, 7, 30]
- [x] 8.7 确保自定义间隔在应用重启后仍然可用

## 9. 测试与验证

- [x] 9.1 为 `ReviewEvent` 的安全日期计算编写单元测试（包括跨月、跨年、闰年）
- [x] 9.2 为 `CalendarManager` 的重复检测逻辑编写 mock 测试
- [x] 9.3 为 `ReviewViewModel` 的状态转换（空标题、权限拒绝、成功）编写单元测试
- [x] 9.4 为本地化字符串完整性编写验证（检查代码中所有 `NSLocalizedString` 键在 Localizable.strings 中存在）
- [~] 9.5 运行 `swift test` 确保所有测试通过（**阻塞**：XCTest 模块缺失）
- [~] 9.6 手动测试：创建日程、检查重复、撤销、历史记录、自定义间隔、视图渲染（**阻塞**：无法构建 .app 测试包）
- [x] 9.7 更新 `README.md` 中关于新增功能（撤销、历史、自定义间隔）的说明
- [ ] 9.8 更新 `exploration.md` 或相关文档，记录已实现的功能

## 10. 最终验证

- [x] 10.1 运行 `swift build` 确保无编译错误
- [~] 10.2 运行 `swift test` 确保所有测试通过（**阻塞**：XCTest 模块缺失）
- [x] 10.3 检查所有 Swift 文件无警告（使用 `swift build` 或 Xcode）
- [x] 10.4 确认所有硬编码中文字符串已被替换
- [x] 10.5 确认所有 `!` 强制解包已被移除
- [~] 10.6 确认所有新增功能在 UI 中正常工作（**阻塞**：无法构建 .app 测试包）
- [x] 10.7 更新 `CHANGELOG` 或 `README.md` 中的版本日志
- [ ] 10.8 运行 `openspec archive` 归档变更
