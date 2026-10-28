# 0001 用 SwiftUI 而非 AppKit 构建界面

- **状态**：已采纳
- **日期**：2026-10-20（迁入本目录）；决策本身早于项目首次发版
- **来源**：`openspec/changes/one-click-calendar/design.md` 第 1 节

## 决策

界面用 SwiftUI 构建。

## 背景

项目起步时有两条路可选：SwiftUI 与 AppKit。界面需求本身简单——输入框、日期选择器、按钮、列表。

## 理由

- SwiftUI 是现代 Apple 平台的首选 UI 框架，声明式语法让这类静态表单的代码量远低于 AppKit
- 界面复杂度低，SwiftUI 的能力足够，不需要为个别控件下沉到 AppKit
- 与 EventKit 的异步 API 配合自然：`async/await` + `@MainActor` 是 EventKit 操作的默认执行模型

## 替代方案

**AppKit**：更底层、控制力更强，但代码量大。对这个体量的界面属于过度投入。

## 后续影响

- `AGENTS.md` 的 `@MainActor` 硬约束直接源于这条决策：Swift 6 下 `@MainActor` 类型不能满足 `nonisolated` 协议要求，seam protocol 与其实现者（含测试 fake）因此必须一起标注
- 少数场景仍需要 AppKit 桥接（窗口层级 `NSWindow.Level.floating`、辅助功能），这类下沉被限制在薄 adapter 层
