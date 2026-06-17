## Context

当前项目是一个基于 Swift 6.0 + SwiftUI + EventKit 的 macOS 应用，用于创建基于艾宾浩斯遗忘曲线的复习日程。项目结构遵循 MVVM 架构，包含 App、Models、Views、ViewModels、Services、Utils 等模块。

经过全面代码审查，发现以下关键问题需要解决：
- 多处 `!` 强制解包存在崩溃风险（`ReviewEvent.swift`、`CalendarManager.swift`、`ReviewViewModel.swift`）
- 日期计算逻辑在三个不同文件中重复
- `ReviewEvent` 模型被定义但未在核心逻辑中使用
- NotificationCenter 观察者未正确管理
- 重复检测仅比较标题，不够精确
- 测试无法运行（XCTest 模块缺失）
- 测试注释与断言逻辑矛盾
- 大量硬编码字符串未使用 Localizable.strings
- 视图层 `ContentView` 过于臃肿（102行）
- 缺少撤销功能、历史记录、自定义间隔

## Goals / Non-Goals

**Goals:**
- 消除所有强制解包，确保类型安全
- 统一日期计算逻辑到 `ReviewEvent` 模型
- 修复测试基础设施并扩展覆盖
- 正确管理 NotificationCenter 生命周期
- 改进重复检测逻辑（增加标题+日期匹配）
- 统一使用 `NSLocalizedString` 进行国际化
- 将 `ContentView` 拆分为独立的子视图
- 实现撤销功能（基于最近创建的事件 ID）
- 使用 `@AppStorage` 实现轻量级历史记录
- 支持用户自定义复习间隔
- 增加标题输入验证（长度、空白字符）

**Non-Goals:**
- 不引入外部依赖（如 SwiftData、Core Data）
- 不修改应用的核心业务逻辑（艾宾浩斯间隔）
- 不改变现有的 macOS 14+ 平台要求
- 不增加网络同步功能
- 不增加 iOS/iPadOS 支持

## Decisions

### 1. 统一日期计算到 `ReviewEvent`
**选择**：将 `ReviewEvent` 从简单的结构体升级为包含日期计算能力的模型。
**理由**：消除三处重复代码，让模型成为日期计算的单一真相源。
**替代方案**：创建单独的 `DateCalculator` 工具类。放弃原因：过度抽象，ReviewEvent 已经存在且语义合适。

### 2. 使用 `@AppStorage` 而非 Core Data
**选择**：使用 `@AppStorage` 存储历史记录和自定义间隔。
**理由**：历史记录数据量小（最多保存最近20条），结构简单，不需要复杂查询。Core Data 会增加不必要的复杂度。
**替代方案**：使用 SwiftData。放弃原因：需要引入新的框架，对于少量键值存储过于重量级。

### 3. 视图拆分策略
**选择**：将 `ContentView` 拆分为 `TitleInputSection`、`DatePickerSection`、`ReviewPreviewSection`、`ActionSection` 四个子视图。
**理由**：每个子视图职责单一，便于独立测试和维护。保持简单，不创建过度抽象的组件。

### 4. 撤销功能实现
**选择**：在 `CalendarManager` 中保存最近创建的三个 `EKEvent` 的 `eventIdentifier`，提供 `undoLastCreation()` 方法。
**理由**：EventKit 提供 `event(withIdentifier:)` 方法，可以直接删除。撤销只支持最近一次的创建。

### 5. 重复检测改进
**选择**：将重复检测改为比较标题+日期（精确到天）+ 备注内容。
**理由**：原逻辑只比较标题，会导致误报。新逻辑更精确，减少误报率。

## Risks / Trade-offs

- **视图拆分增加文件数量** → 通过清晰的命名和职责划分缓解，每个子视图不超过50行
- **`@AppStorage` 存储容量有限** → 限制历史记录最多20条，超过时自动删除最旧的
- **撤销功能依赖 eventIdentifier** → 如果用户在系统日历中手动修改或删除事件，撤销可能失效。通过友好的错误提示处理
- **自定义间隔可能与艾宾浩斯理论冲突** → 在 UI 中提供默认推荐值（3/7/30），允许用户修改但不做理论验证

## Migration Plan

- 所有变更都是向后兼容的，无需数据迁移
- 测试需要先修复 XCTest 模块问题
- 建议按 task 文件中的顺序逐步实施

## Open Questions

- 是否需要支持自定义复习次数（当前固定为3次）？
- 历史记录是否需要持久化到文件而非仅 `@AppStorage`？
