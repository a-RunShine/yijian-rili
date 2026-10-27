# 硬约束现状

`AGENTS.md` 定义的硬约束与仓库实际状态的差距，按 2026-10-27 的扫描记录。

## 禁止注释

`AGENTS.md` 原文：

> **禁止在代码里写注释**——`///`、`//`、`/* */`、`// MARK:` 都不行。意图靠命名与结构；领域规则写进 `GLOSSARY.md` 或 `docs/*/spec.md` / `plan.md`。本文件与 `docs/` 下 Markdown 不受此限。

2026-10-27 扫描结果：

| 范围 | 违规行数 | 分布 |
|---|---|---|
| `Sources/` | **0** | 干净 |
| `Tests/` | **143** | `一键日历Tests.swift` 142、`InMemoryCalendarServiceTests.swift` 1 |
| `windows/` | **75** | `WinRtCalendarService.cs` 9、`WeekCalculator.cs` 8、`ReviewEvent.cs` 6 等 |

`Sources/` 零违规说明这条约束**本身是可执行的**，问题只在没人检查。当前无 SwiftLint、无 SwiftFormat、无 pre-commit hook、无 `.editorconfig`。

跟踪：issue `#68`

## `@MainActor` 约定

`AGENTS.md` 要求：所有 UI / ViewModel、以及 `Services/` 下 seam protocol 与全部实现者（含测试 fake）必须标 `@MainActor`。原因写在契约里——Swift 6 下 `@MainActor` 类型不能满足 `nonisolated` 协议要求；EventKit 侧也需要固定线程约定。

2026-10-27 未做全量核查。已知相关遗留问题：issue `#11`（主线程 EventKit 同步 IO 导致创建时 UI 阻塞，标 `needs-info`，明确写着「需要人定方案，不适合 agent 自动实施」）。

## 为什么约束需要机器强制

这两条约束的共同点：违反它们**不会让编译失败、不会让测试变红**。靠 review 时人肉数行不现实——143 行注释分散在一个测试文件里，没有任何 reviewer 会逐行检查。

「pit of success」要求约束极简、默认可用、违反即失败。目前这三条都不满足，所以 `make lint` + macOS CI 是这条约束链缺的第一环。
