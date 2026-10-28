# Cursor Cloud

跑在 Ubuntu：无 SwiftUI / AppKit / EventKit / OSLog，故 `make build` / `make test` / `swift build` / `swift test` 会在对应 `import` 失败。完整测试在 macOS。

## 工具链

- `/opt/swift`（`swift --version` ≈ 6.4）
- `/usr/local/bin` 仅暴露 `swift*` / `sourcekit-lsp`，避免盖住系统 clang
- **不要** `apt install swift`——Ubuntu 上那是 OpenStack 对象存储，不是编译器

## Linux smoke

用 `swiftc` 编译下列文件，并配一个本地 `OSLog` 桩（`Logger.init(subsystem:category:)` 与 `warning(_: String)`）：

- `Sources/一键日历/Models/ReviewEvent.swift`
- `Sources/一键日历/Models/HistoryEntry.swift`
- `Sources/一键日历/Models/WeeklyEntry.swift`
- `Sources/一键日历/Utils/DateFormatter+Extension.swift`
- `Sources/一键日历/Utils/WeekCalculator.swift`

无资源包时 `NSLocalizedString` 退回 key `review_count`。基准 `2026-01-31`、间隔 `[3, 7, 30]` → 复习日 `2026-02-03`、`2026-02-07`、`2026-03-02`。

## 为什么 `make test` 在这里不能用

`make test` 跑完整 `swift test`，测试目标会 `import SwiftUI` 与 EventKit，两者在 Ubuntu 上不存在。smoke 编译只是语法与纯逻辑的兜底，不替代测试。
