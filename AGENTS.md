# AGENTS.md

Agent 操作契约（always-loaded）。发版、CalDAV 同步、Windows 细节见下方指针，不要把手册塞回本文件。

## 项目概述

基于艾宾浩斯遗忘曲线，把复习提醒写入系统日历的桌面应用。

- **macOS（主工程）**：Swift 6 + SwiftUI，macOS 14+，EventKit；入口 `Sources/一键日历/一键日历App.swift`；UI 文案走 `Resources/zh.lproj/Localizable.strings`（`defaultLocalization: "zh"`）
- **Windows（移植）**：`windows/` — 见 [`windows/README.md`](windows/README.md)（C# / WinUI 3；领域层可在 Linux `dotnet test`）

## 硬约束

- **禁止在代码里写注释**——`///`、`//`、`/* */`、`// MARK:` 都不行。意图靠命名与结构；领域规则写进 `GLOSSARY.md` 或 `docs/*/spec.md` / `plan.md`。本文件与 `docs/` 下 Markdown 不受此限。
- **`@MainActor`**：所有 UI / ViewModel，以及 `Services/` 下 seam protocol 与全部实现者（含测试 fake）必须标 `@MainActor`。Swift 6 下 `@MainActor` 类型不能满足 `nonisolated` 协议要求；EventKit 侧也需要固定线程约定。新增 seam 时实现与 fake 一起标。

## 构建与验证

日常命令与发版步骤：[`docs/agents/release.md`](docs/agents/release.md)。

- macOS：`make test` / `make open`（不要用 `make run`）
- Cloud Linux：见下方；完整 SwiftUI/EventKit 构建不可用

## 文档指针

| 何时打开 | 文档 |
|---|---|
| 发版、make 目标、dmg/zip | [`docs/agents/release.md`](docs/agents/release.md) |
| 手机 CalDAV / 写入哪个云账户 | [`docs/agents/sync-caldav.md`](docs/agents/sync-caldav.md) |
| Windows 移植 | [`windows/README.md`](windows/README.md) |
| Issues / `gh` | [`docs/agents/issue-tracker.md`](docs/agents/issue-tracker.md) |
| Triage 标签 | [`docs/agents/triage-labels.md`](docs/agents/triage-labels.md) |
| 术语与 ADR | [`docs/agents/domain.md`](docs/agents/domain.md) → `GLOSSARY.md` + `docs/adr/` |

## Cursor Cloud

跑在 Ubuntu：无 SwiftUI / AppKit / EventKit / OSLog，故 `make build` / `make test` / `swift build` / `swift test` 会在对应 `import` 失败。完整测试在 macOS。

- 工具链：`/opt/swift`（`swift --version` ≈ 6.4）；`/usr/local/bin` 仅暴露 `swift*` / `sourcekit-lsp`，避免盖住系统 clang
- **不要** `apt install swift`（Ubuntu 上是 OpenStack 对象存储）
- Linux smoke：用 `swiftc` 编译下列文件 + 本地 `OSLog` 桩（`Logger.init(subsystem:category:)` 与 `warning(_: String)`）

  - `Sources/一键日历/Models/ReviewEvent.swift`
  - `Sources/一键日历/Models/HistoryEntry.swift`
  - `Sources/一键日历/Models/WeeklyEntry.swift`
  - `Sources/一键日历/Utils/DateFormatter+Extension.swift`
  - `Sources/一键日历/Utils/WeekCalculator.swift`

  无资源包时 `NSLocalizedString` 退回 key `review_count`。基准 `2026-01-31`、间隔 `[3, 7, 30]` → 复习日 `2026-02-03`、`2026-02-07`、`2026-03-02`。
