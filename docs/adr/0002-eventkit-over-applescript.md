# 0002 用 EventKit 直接写入而非 AppleScript

- **状态**：已采纳
- **日期**：2026-10-20（迁入本目录）
- **来源**：`openspec/changes/one-click-calendar/design.md` 第 2 节

## 决策

通过 EventKit 框架直接操作系统日历数据库，不用 AppleScript 脚本控制 Calendar.app。

## 背景

需要把生成的复习日程批量写入用户日历。macOS 上可用 EventKit，也可用 AppleScript 跨进程操控 Calendar.app。

## 理由

- EventKit 是 Apple 官方推荐的原生 API，与 Calendar.app 使用同一套底层数据
- 直接访问内存对象，不需要跨进程通信，批量写入时性能差距明显
- 支持现代权限模型（macOS 14+ 的 write-only 或 full access），AppleScript 的权限路径更复杂
- AppleScript 对 Calendar 的支持面有限且脆弱，依赖 UI 结构或脚本字典版本

## 替代方案

**AppleScript**：更慢、更不可靠、权限处理复杂。批量创建时每一次写入都是一次跨进程调用。

## 后续影响

- 所有日历读写收敛到「日历 seam」：生产实现是 EventKit adapter（类型名仍为 `CalendarManager`），测试用 in-memory adapter。领域层不直接接触 `EKEventStore`
- `EKEventStore` 不是 `Sendable`，且约定同一实例固定线程访问。这条约束是 issue `#11`（主线程同步 IO 阻塞 UI）的根源：要真正 offload 到后台，需要「专用串行队列 + 独立 `EKEventStore` 实例」，而跨实例在沙盒下的行为需要先验证。在验证之前，把 seam 改成 `nonisolated` 等于用未定义行为换掉卡顿，所以没有做
