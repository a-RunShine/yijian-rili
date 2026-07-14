# 自定义复习间隔功能 — 工程实施文档

## 概述

在现有「复习间隔」Section（固定 3 个 TextField + 3 个内置预设）基础上，实现：
1. **动态增减间隔数量** — 用户可自由添加/删除间隔字段（上限 10 个）
2. **自定义预设管理** — 保存/命名/应用/删除自定义间隔方案
3. **「已保存」快照恢复** — 切换预设后可一键恢复到上次手动保存的间隔

PR: https://github.com/a-RunShine/yijian-rili/pull/1

## 实施时间线

| 阶段 | 内容 | 耗时 |
|------|------|------|
| 需求确认 | 与用户确认：动态增减 vs 固定 3 个、是否需要自定义预设 | ~5 min |
| 方案设计 | 制定 6 个 Task 的实施计划 | ~3 min |
| 第一轮实现 | Task 1-6 全部编码 | ~15 min |
| Bug 修复 | 发现并修复 `@AppStorage` 计算属性不触发 SwiftUI 刷新的根因 | ~10 min |
| UX 修复 | 根据用户反馈修复 3 个交互问题 | ~10 min |
| 审查循环 | 3 轮 Agent 审查（73 → 84 → 95 分），修复 10+ 个问题 | ~20 min |

## 架构决策

### 1. `@Published` + `didSet` 替代 `@AppStorage` 计算属性

**问题**：最初将 `reviewIntervals` 实现为基于 `@AppStorage("reviewIntervalsData")` 的计算属性（get/set）。但 `@AppStorage` 是 SwiftUI 的 `DynamicProperty`，只在 `View` 内部触发刷新。在 `ObservableObject`（ViewModel）中，setter 写入 `@AppStorage` 后 **不会触发 `objectWillChange`**，导致视图不刷新，用户看到的仍是旧值。

**方案**：改为 `@Published var reviewIntervals: [Int]`，通过 `didSet` 手动同步 `UserDefaults`。

```swift
// Before (broken):
@AppStorage("reviewIntervalsData") private var reviewIntervalsData: String = "[3,7,30]"
var reviewIntervals: [Int] {
    get { /* decode from reviewIntervalsData */ }
    set { /* encode to reviewIntervalsData — no SwiftUI refresh! */ }
}

// After (fixed):
@Published var reviewIntervals: [Int] = { /* read from UserDefaults on init */ }() {
    didSet {
        // write to UserDefaults — @Published triggers SwiftUI refresh
        UserDefaults.standard.set(jsonString, forKey: "reviewIntervalsData")
    }
}
```

**影响范围**：`reviewIntervals` 和 `customPresets` 两个属性均做了同样的改造。

### 2. `savedSnapshot` 持久化方案

**问题**：用户保存自定义间隔后切换预设，期望能恢复之前的值。最初用 `@State private var savedSnapshot: [Int]` 存储快照，但每次 View 重建时 `onAppear` 会用当前 `reviewIntervals` 覆盖快照，导致「已保存」按钮永远无效。

**方案**：改用 `@AppStorage("savedIntervalsSnapshot")` 存储 JSON 字符串，只在 `saveIntervals()` 成功时更新。`onAppear` 仅在快照为空时初始化。

### 3. 预设高亮优先级

**问题**：当自定义预设的间隔与某个内置预设相同时（如都等于 `[1,3,7]`），`activePreset` 匹配到内置预设，导致内置按钮高亮而自定义按钮不高亮——视觉上两个预设"绑定"在一起。

**方案**：自定义预设优先检查。`activePreset` 在 `activeCustomPreset != nil` 时返回 `nil`，确保只有自定义预设高亮。

## 变更文件清单

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `ViewModels/ReviewViewModel.swift` | 修改 | 新增 `CustomPreset` 模型、`customPresets` 属性、预设 CRUD 方法；`reviewIntervals` 改 `@Published`；`validateIntervals` 加上限 |
| `Views/IntervalSettingsSection.swift` | 重写 | 动态间隔列表、自定义预设行、「已保存」恢复按钮、删除确认弹窗 |
| `Models/ReviewEvent.swift` | 修改 | `"第N次复习"` 改用 `NSLocalizedString("review_count")` |
| `Services/CalendarManager.swift` | 修改 | 同上 |
| `Resources/zh.lproj/Localizable.strings` | 修改 | 新增 15 个 key，清理 8 行重复 |
| `Tests/一键日历Tests/一键日历Tests.swift` | 修改 | 新增 5 个测试（动态间隔、预设 CRUD、重名、上限、编解码） |

## 新增本地化 Key

| Key | 值 | 用途 |
|-----|---|------|
| `add_interval` | 添加间隔 | 添加按钮文案 |
| `remove_interval` | 删除 | 删除按钮文案 |
| `restore_saved` | 已保存 | 恢复快照按钮 |
| `interval_unit_day` | 天 | 间隔单位 |
| `interval_min_error` | 至少需要一个间隔 | 空数组校验 |
| `interval_max_error` | 最多支持10个间隔 | 上限校验 |
| `save_as_preset` | 保存为预设 | + 按钮 tooltip |
| `preset_name_placeholder` | 预设名称 | alert 输入框 |
| `preset_name_title` | 保存预设 | alert 标题 |
| `preset_name_message` | 为当前间隔方案输入名称 | alert 副标题 |
| `preset_save` | 保存 | alert 确认按钮 |
| `preset_cancel` | 取消 | alert 取消按钮 |
| `preset_delete` | 删除预设 | contextMenu 删除 |
| `preset_delete_confirm_title` | 删除预设 | 确认弹窗标题 |
| `preset_delete_confirm_message` | 确定要删除「%@」吗？ | 确认弹窗消息 |
| `custom_presets_label` | 自定义 | 自定义预设行标签 |
| `custom_presets_empty` | 点击 + 保存方案 | 无预设时提示 |
| `preset_name_empty` | 预设名称不能为空 | 空名校验 |
| `preset_name_duplicate` | 预设名称已存在 | 重名校验 |

## 测试覆盖

15 个测试全部通过（原 10 个 + 新增 5 个）：

| 测试 | 覆盖点 |
|------|--------|
| `testDynamicIntervalCount` | 1/5/10 个间隔的 reviewDates 计算 |
| `testCustomPresetSaveAndApply` | 预设保存 → 应用 → 删除完整流程 |
| `testCustomPresetDuplicateName` | 重名防护 + `hasDuplicatePresetName` |
| `testMaxIntervalCountExceeded` | 10 个合法、11 个被拒绝 |
| `testCustomPresetCoding` | `CustomPreset` JSON 编解码往返 |

## 审查循环记录

采用 Agent 审查循环（审查 → 打分 → 修复 → 再审查），直到分数 ≥ 90：

| 轮次 | 分数 | 关键修复 |
|------|------|---------|
| R1 审查 | 73/100 | 发现 `savedSnapshot` 不持久化（P0）、Localizable 重复 key（P0）、硬编码中文（P1）、无上限（P1）、无确认弹窗（P1） |
| R1 修复 → R2 审查 | 84/100 | 修复 P0/P1 全部；遗留 ReviewEvent 硬编码、测试缺口 |
| R2 修复 → R3 终审 | **95/100** | `review_count` 本地化、`validateIntervals` 上限检查、死代码清理 |

### R1 发现的核心 Bug

**`@AppStorage` 计算属性不触发 SwiftUI 刷新**

这是整个功能最大的技术坑。`@AppStorage` 在 `View` 中作为 `DynamicProperty` 工作正常，但在 `ObservableObject` 中作为计算属性的 backing storage 时，setter 写入 `@AppStorage` 不会触发 `objectWillChange.send()`，导致：
- 数据已写入 UserDefaults（持久化 OK）
- 但 SwiftUI 视图不刷新（UI 显示旧值）
- 用户感知为「保存无效」

根因：`@AppStorage` 的变更通知走的是 SwiftUI 的 `DynamicProperty` 通道，不经过 `ObservableObject` 的 `objectWillChange`。两者是独立的观察机制。

## Git 提交记录

```
6e9cdaa feat: 自定义复习间隔 - 动态增减间隔数量 + 自定义预设管理
f63ad9f fix: 修复审查发现的问题 - 自定义复习间隔功能完善
```

分支：`feat/custom-review-intervals` → `master`
