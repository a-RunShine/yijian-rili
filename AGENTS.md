# AGENTS.md

Agent 操作契约（always-loaded）。发版、CalDAV 同步、Windows 细节见下方指针，不要把手册塞回本文件。

## 项目概述

基于艾宾浩斯遗忘曲线，把复习提醒写入系统日历的桌面应用。

- **macOS（主工程）**：Swift 6 + SwiftUI，macOS 14+，EventKit；入口 `Sources/一键日历/一键日历App.swift`；UI 文案走 `Resources/zh.lproj/Localizable.strings`（`defaultLocalization: "zh"`）
- **Windows（移植）**：`windows/` — 见 [`windows/README.md`](windows/README.md)（C# / WinUI 3；领域层可在 Linux `dotnet test`）

## 硬约束

- **禁止在代码里写注释**——`///`、`//`、`/* */`、`// MARK:` 都不行。意图靠命名与结构；领域规则写进 `GLOSSARY.md` 或 `docs/*/spec.md` / `plan.md`。本文件与 `docs/` 下 Markdown 不受此限。
- **`@MainActor`**：UI / ViewModel，以及 `Services/` 下**承载副作用的 seam**（protocol 与实现，含测试 fake）必须标 `@MainActor`。纯函数模块（`IntervalRules`、`WriteRules`、`MonthGrid` 这类无状态的 enum/struct）不标。Swift 6 下 `@MainActor` 类型不能满足 `nonisolated` 协议要求；EventKit 侧也需要固定线程约定。新增 seam 时实现与 fake 一起标。
- **Issue 与 PR 的标题、描述尽可能用中文。**

## 构建与验证

日常命令与发版步骤：[`docs/agents/release.md`](docs/agents/release.md)。

- 提交前：`make check`（= `make lint` + `make test`）；调试用 `make open`
- **Swift 版本两边不同**：本地通常 6.4，CI 是 6.2.4 / Xcode 26.3 / macOS 15 SDK。本地全绿不等于 CI 绿——遇到过本地永远复现不出的 `@MainActor deinit` 崩溃
- **等 CI 用 `gh pr checks --watch`**，不要 `sleep` 轮询。改动只落在 `docs/**` 时 CI 根本不会触发（触发路径见 workflow 的 `paths`）
- Cloud Linux：见 [`docs/agents/cursor-cloud.md`](docs/agents/cursor-cloud.md)

## 文档指针

| 何时打开 | 文档 |
|---|---|
| 发版、make 目标、dmg/zip | [`docs/agents/release.md`](docs/agents/release.md) |
| 手机 CalDAV / 写入哪个云账户 | [`docs/agents/sync-caldav.md`](docs/agents/sync-caldav.md) |
| Windows 移植 | [`windows/README.md`](windows/README.md) |
| Issues / `gh` | [`docs/agents/issue-tracker.md`](docs/agents/issue-tracker.md) |
| Triage 标签 | [`docs/agents/triage-labels.md`](docs/agents/triage-labels.md) |
| 术语与 ADR | [`docs/agents/domain.md`](docs/agents/domain.md) → `GLOSSARY.md` + [`docs/adr/`](docs/adr/README.md) |
| 跨会话的决策与踩坑 | [`docs/wiki/index.md`](docs/wiki/index.md) |

## Cursor Cloud

见 [`docs/agents/cursor-cloud.md`](docs/agents/cursor-cloud.md)：Ubuntu 上的工具链、Linux smoke 编译清单、以及为什么 `make test` 在那里跑不了。
