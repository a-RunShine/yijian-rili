# AGENTS.md

## 项目概述

基于艾宾浩斯遗忘曲线创建复习提醒的桌面应用。

### macOS（主工程）

Swift 6.0 + SwiftUI 的 macOS 可执行应用。使用 EventKit 读写系统日历，Swift Package Manager 管理依赖。

- **平台**：macOS 14.0+
- **语言**：Swift 6（启用 `StrictConcurrency` 实验特性）
- **本地化**：默认中文（`defaultLocalization: "zh"`），所有 UI 文本通过 `NSLocalizedString` 走 `Resources/zh.lproj/Localizable.strings`
- **入口**：`Sources/一键日历/一键日历App.swift`（`@main`）

### Windows（移植）

目录：`windows/`（详见 [`windows/README.md`](windows/README.md)）

- **栈**：C# / WinUI 3 / .NET 8 + WinRT `Appointments`
- **领域层**：`YijianRili.Domain`（`net8.0`，可在 Linux 跑 `dotnet test`）
- **日历适配**：`YijianRili.Calendar.WinRtCalendarService` 实现 `ICalendarService`
- **UI**：`YijianRili.App`（需 Windows + Windows App SDK；Linux 无法跑 XamlCompiler）
- **同步引导**：Outlook / Google 优先（非 macOS CalDAV）

## 构建与发布

```bash
make build       # swift build -c release
make bundle      # 打包 .app（+ codesign 自签名）
make install     # bundle + 复制到 /Applications
make test        # swift test
make run         # swift run
```

发布流程（v1.4.0 实测）：

1. 改源码 → `swift build` + `swift test`
2. 更新 `Info.plist` 的 `CFBundleShortVersionString` 和 `CFBundleVersion`
3. `make install`
4. `zip -X -r releases/YijianRili-v<版本>-macOS.app.zip 一键日历.app`
5. 写 `releases/v<版本>.md`
6. `git add -f 一键日历.app/Contents/Info.plist`（`.app` 被 .gitignore 排除，Info.plist 要强推）+ commit + push。**app 二进制不跟踪**——`一键日历.app/` 整个被忽略，发版产物由第 7/9 步的 GitHub Releases（zip + dmg）归档，不要往仓库里塞二进制
7. `gh release create v<版本> <zip> --notes-file releases/v<版本>.md`
8. 制作 dmg：hdiutil UDRW → AppleScript 设 Finder 布局 → hdiutil convert UDZO（详见 `retrospectives/v1.4.0.md`）
9. `gh release upload v<版本> <dmg>`

**dmg 文件名必须用纯 ASCII**（`YijianRili-v<版本>-macOS.dmg`），gh upload 会吞掉中文字符。

## 架构与关键约定

### 线程与并发

- **所有 UI 类和 ViewModel 必须标记 `@MainActor`**，编译器会严格检查（`StrictConcurrency` 已启用）
- **Services/ 下的 seam protocol 及其所有实现者（含测试 fake）统一标 `@MainActor`**：现有的 `CalendarService` / `CalendarEventStore` / `WeeklyEntryAppending` 全部如此。
  原因是 Swift 6 不允许 `@MainActor` 类型满足 `nonisolated` 协议要求（报 `#ConformanceIsolation`）；而这些 seam 的实现在 EventKit 下要摸 `EKEventStore`（非 Sendable，约定固定线程访问），标 `nonisolated` 只会用未定义行为换编译通过。
  **新增 seam 时连同实现类和测试 fake 一起标**，否则同样的编译错误会重演
- `CalendarManager` 是 `@MainActor` 单例（`class CalendarManager: ObservableObject`），内部 `EKEventStore` 操作使用 `async/await`
- `ReviewViewModel` 的测试需要 `@MainActor`，因为 `ReviewViewModel` 是 MainActor 隔离的

### 视图结构

- **主窗口**：固定 400x600，不可调整大小；窗口层级（浮动/普通）由用户通过 `WindowSettingsSection` 的开关控制，默认浮动
- **快捷键**：Cmd+Enter 通过 `NotificationCenter` 触发 `createReviewSchedule`，不是 SwiftUI 原生 `keyboardShortcut`
  - 通知名：`Notification.Name.createReviewSchedule`
  - 发送方：`一键日历App.swift` 中的 `CommandMenu`
  - 接收方：`ReviewViewModel.init()` 中注册的观察者
- **视图拆分**：15 个子视图，主容器是 `ContentView`
  - 输入/预览类：`TitleInputSection` / `DatePickerSection` / `ReviewPreviewSection` / `IntervalSettingsSection`
  - 操作/反馈类：`ActionSection` / `RecreateUndoSection` / `HistorySection`（sheet）
  - 日历/权限类：`CalendarPickerSection` / `FirstRunGuideView`（sheet，3 步配置云日历）
  - 窗口设置类：`WindowSettingsSection`（Toggle 控制 `windowFloating`）
  - 日程展示类：`TodayEventsSection`（昨天/今天/明天三段切换 + 卡片列表）
  - 搜索类：`SearchSheetView` / `SearchResultDetailView`（sheet）
  - 周末总结类：`WeeklyReviewView`（sheet，spec F1-F9）
- **`IntervalSettingsSection` 的 `tempIntervals` 是本地 `@State`**，保存时才写入 `viewModel.reviewIntervals`

### 数据持久化

- **存储方式**：`@AppStorage` 存 JSON 字符串，不是原生 plist
  - `reviewIntervalsData`：默认 `[3, 7, 30]`，可自定义
  - `historyEntriesData`：上限 20 条，超出自动截断
- **`windowFloating`**（`@Published` + `didSet` 写 `UserDefaults`）：窗口是否置顶，默认 `true`；切换后 `ContentView.onChange` 调用 `applyWindowLevel()` 立即生效
- **修改后必须调用 `updateReviewDates()`** 刷新预览
- 历史记录直接存 JSON 到 `UserDefaults`，不是文件系统

### 日历权限

- **需要 `NSCalendarsFullAccessUsageDescription`**（Info.plist 已配置），因为必须读取日历来检测重复
- **重复检测逻辑**：同一天内比较 `title == title && notes == notes`
- 权限状态由 `CalendarManager` 单例管理，首次请求用 `requestFullAccessToEvents()`

### 模型

- **ReviewEvent**：`Identifiable` + `Codable`，日期计算使用 `Calendar.current.date(byAdding:)`，失败时安全跳过（不会 crash）
- **HistoryEntry**：`Codable`，存储标题、基准日期、复习日期和创建时间

### ViewModel 核心逻辑

- **创建流程**：`createReviewSchedule()` → 校验标题（非空、≤100字符）→ 检查权限 → 调用 `CalendarManager.createReviewEvents()` → 处理结果（成功/警告/错误）→ 添加历史记录 → 清空输入
- **撤销流程**：`undoReviewSchedule()` → 调用 `CalendarManager.undoLastCreation()` → 清除 `lastCreatedEventIdentifiers`
- **结果类型**：`ResultType`（`.success` / `.warning` / `.error`）控制提示颜色和图标

## 测试

- **测试包**：`Tests/一键日历Tests/一键日历Tests.swift`
- **覆盖范围**：
  - 日期计算（跨月、跨年、闰年）
  - 模型初始化（`ReviewEvent` 默认和自定义间隔）
  - 格式化器（`formattedChinese()` / `formattedShort()`）
  - ViewModel 校验（空标题、超长标题、间隔验证）
- **注意**：ViewModel 测试需要 `@MainActor`

## 文件结构

```
Sources/一键日历/
├── 一键日历App.swift              # 应用入口 + AppDelegate（窗口浮动层级）
├── Models/
│   ├── ReviewEvent.swift          # 复习事件模型（日期计算 + 备注生成）
│   ├── HistoryEntry.swift         # 历史记录模型（Codable）
│   ├── WeeklyEntry.swift          # 周末总结条目（spec F3/F4）
│   ├── CalendarModels.swift       # 日历权限/账户来源/CalendarInfo/结果类型（对齐 Windows）
│   └── Theme.swift                # 主题与 ThemeProvider
├── ViewModels/
│   ├── ReviewSession.swift        # 无 UI 依赖的创建/撤销/预览核心（对齐 Windows ReviewSession）
│   ├── DayBrowseModel.swift       # 按日列表 + 标题搜索 + 按 id 删除
│   ├── ReviewViewModel.swift      # 界面 facade：观察转发 + 通知 + AppKit + sheet
│   └── WeeklyReviewViewModel.swift # 周末总结状态容器（spec F1-F9，plan §3.2）
├── Services/
│   ├── CalendarService.swift      # 日历 seam interface（@MainActor）
│   ├── CalendarManager.swift      # EventKit adapter（日历 seam 的生产实现）
│   ├── InMemoryCalendarService.swift # 进程内 adapter，对齐 Windows 同名类型
│   ├── CalendarEventStore.swift   # 窄 store seam：查找 + 保存全天事件（@MainActor）
│   ├── CalendarWriteOrchestrator.swift # 写入日历编排：校验→算日→备注键→查重→写入
│   ├── WriteRules.swift           # 间隔校验 / 备注键 / 备注规范化 / 重复判定
│   ├── HistoryStore.swift         # 历史记录 store：capped JSON（默认 20）
│   ├── WeeklyEntryAppending.swift # 周末总结 append seam（@MainActor，macOS 专有）
│   └── CreateSuccessOutcomes.swift # 纯成功后的持久化编排（history + weekly 双写）
├── Utils/
│   ├── DateFormatter+Extension.swift # 日期格式化（中文长格式 + 短格式）
│   ├── WeekCalculator.swift       # 周次计算（weekStart/weekEnd/weekKey）
│   └── Color+Hex.swift            # Color ↔ hex 转换（日历账户色）
├── Views/
│   ├── ContentView.swift          # 主容器（ScrollView + VStack）
│   ├── TitleInputSection.swift    # 标题输入（TextField）
│   ├── DatePickerSection.swift    # 日期选择（DatePicker，onChange 刷新预览）
│   ├── ReviewPreviewSection.swift # 复习预览（ForEach 显示日期列表）
│   ├── CalendarPickerSection.swift # 日历账户选择（Picker 按 source 分组）
│   ├── FirstRunGuideView.swift    # 首次启动引导 sheet（3 步配置云日历）
│   ├── ActionSection.swift        # 操作按钮（创建/撤销/结果提示/权限设置）
│   ├── RecreateUndoSection.swift  # 重新创建 + 撤销区
│   ├── HistorySection.swift       # 历史记录（ScrollView 最大高度 150）
│   ├── IntervalSettingsSection.swift # 间隔设置（3 个 TextField + 校验）
│   ├── WindowSettingsSection.swift   # 窗口置顶开关（Toggle）
│   ├── TodayEventsSection.swift   # 今日日程（昨天/今天/明天 + 卡片列表）
│   ├── SearchSheetView.swift      # 日程搜索 sheet
│   ├── SearchResultDetailView.swift # 搜索结果详情
│   └── WeeklyReviewView.swift     # 周末总结 sheet 页面（spec F1-F9，plan §4.2）
└── Resources/zh.lproj/
    └── Localizable.strings        # 中文本地化源文件

Tests/一键日历Tests/
├── 一键日历Tests.swift             # 原有单元测试（日期/模型/格式化/校验）
├── CalendarWriteOrchestratorTests.swift # 规则层 + 写入编排（FakeCalendarEventStore）
├── InMemoryCalendarServiceTests.swift   # 日历 seam 行为测试
└── ReviewSessionTests.swift       # 创建成功 outcomes / 复习会话 / 日程浏览

Package.swift                      # SPM 配置（swift-tools-version: 6.0）
Info.plist                         # 应用元数据 + 权限声明
```

## 操作注意事项

- **修改 UI 文本必须同步更新 `Localizable.strings`**，否则中文环境下显示 key
- **`NotificationCenter` 观察者需要在 `deinit` 中移除**，避免内存泄漏
- **重复检测是在创建时实时读取日历**，不是创建前批量检测，因此可能部分成功部分警告

## 手机日历同步

App 用 `eventStore.defaultCalendarForNewEvents` 写入事件。`defaultCalendarForNewEvents` = 用户在 macOS「日历」App 设的默认日历所属账户。所以"事件同步到手机"取决于**事件写到了哪个云账户**。

### 推荐配置：网易 163 邮箱（CalDAV）

1. **163 邮箱开 CalDAV**：登录 [mail.163.com](https://mail.163.com) → 设置 → 账户 → CalDAV 服务 → 开启 → 生成授权码
2. **macOS 加账户**：打开「日历」App → 菜单「日历 → 添加账户」→ 选「其他 CalDAV 账户」→ 手动：
   - 用户名：`xxx@163.com`
   - 密码：刚生成的授权码
   - 服务器：`caldav.163.com`
   - 端口：`443` / SSL 启用
3. **一加 12 加账户**：ColorOS 16「日历 → 我的 → 添加日历 → CalDAV 账号」→ 同一套
4. **设为默认**：macOS「日历」App 选中 163 账户下的某个日历 → 右键 → 设为默认

### 备选 CalDAV 源（按推荐度）

| 服务 | 服务器 | 备注 |
|---|---|---|
| 网易 163 个人邮箱 | `caldav.163.com:443` | ⭐⭐⭐ 免费、稳定，需隐藏路径开启 |
| 中国移动 139 邮箱 | `cal.caiyun.mail.10086.cn:443` | ⭐⭐⭐ 手机号即邮箱，零门槛（授权码 90 天有效）|
| 阿里云企业邮箱 | `caldav.mxhichina.com` | ⭐⭐ 收费版稳定 |
| iCloud | `https://caldav.icloud.com` | ⭐⭐ 中国大陆区 Apple ID 需代理 |
| Google Calendar | 系统自动 | ⭐⭐ 一加 12 需装 Google Play Services |
| Outlook.com | `s.outlook.com:443` EAS | ⭐⭐ ColorOS 16 系统入口有 TLS 坑，建议装 Outlook App |
| QQ 邮箱 | ❌ 不支持 | 不支持 CalDAV，桌面 Exchange 同步有 bug |

### App 内的日历选择

- App 主界面有「**写入日历**」Section，可选具体日历账户
- 选中「本地」时黄色警告"本地事件不会同步到手机"，但允许创建
- 首次启动若未配置云日历，3s 后自动弹引导
- 主界面右上角「?」按钮可随时重看引导
- `@AppStorage("selectedCalendarIdentifier")` 持久化用户选择
- 若选中的日历被删/账户注销，App 自动回退到系统默认并提示

## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues (via `gh`). See `docs/agents/issue-tracker.md`.

### Triage labels

Canonical roles map 1:1 to `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: root `GLOSSARY.md` + `docs/adr/`. See `docs/agents/domain.md`.

## Cursor Cloud specific instructions

Cloud Agent 跑在 Ubuntu Linux 上。本仓库是 macOS 14 的 SwiftUI 应用，界面和日历写入依赖 SwiftUI、AppKit、EventKit。这些框架在 Linux 上不存在，`OSLog` 也不存在，所以 `make build`、`make test`、`swift build`、`swift test`、`swift run` 会在对应 `import` 处失败，`一键日历.app` 也无法启动。完整测试仍在 macOS 上执行。

环境提供 Swift 6.4.0：`swift --version`。工具链在 `/opt/swift`。`/usr/local/bin` 上只有 `swift`、`swiftc`、`swift-build`、`swift-test`、`swift-run`、`swift-package`、`sourcekit-lsp`，避免工具链自带的 `clang` 盖住系统编译器。不要执行 `apt install swift`，Ubuntu 上那个包是 OpenStack 对象存储。

Linux 上可以编译并运行复习日期引擎，确认工具链和核心计算。把下面五个源文件和一份本地 `OSLog` 桩一起交给 `swiftc`：

- `Sources/一键日历/Models/ReviewEvent.swift`
- `Sources/一键日历/Models/HistoryEntry.swift`
- `Sources/一键日历/Models/WeeklyEntry.swift`
- `Sources/一键日历/Utils/DateFormatter+Extension.swift`
- `Sources/一键日历/Utils/WeekCalculator.swift`

桩只需要 `Logger.init(subsystem:category:)` 和 `warning(_: String)`。没有应用资源包时，`NSLocalizedString` 会退回 key `review_count`，这和单元测试里的预期一致。用 2026-01-31 作基准、间隔 `[3, 7, 30]` 时，复习日应为 2026-02-03、2026-02-07、2026-03-02。
