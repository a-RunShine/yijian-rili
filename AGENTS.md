# AGENTS.md

## 项目概述

Swift 6.0 + SwiftUI 的 macOS 可执行应用，基于艾宾浩斯遗忘曲线创建复习提醒。使用 EventKit 读写系统日历，Swift Package Manager 管理依赖。

- **平台**：macOS 14.0+
- **语言**：Swift 6（启用 `StrictConcurrency` 实验特性）
- **本地化**：默认中文（`defaultLocalization: "zh"`），所有 UI 文本通过 `NSLocalizedString` 走 `Resources/zh.lproj/Localizable.strings`
- **入口**：`Sources/一键日历/一键日历App.swift`（`@main`）

## 构建命令

```bash
swift build              # debug
swift build -c release   # release 二进制 -> .build/release/一键日历
swift run                # 直接运行
swift test               # 运行 XCTest 测试
```

手动打包为 `.app`（根目录已有一份预构建的）：

```bash
mkdir -p 一键日历.app/Contents/MacOS
cp .build/release/一键日历 一键日历.app/Contents/MacOS/
```

修改代码后需重新 build 并手动替换根目录的 `.app`。

## 架构与关键约定

### 线程与并发

- **所有 UI 类和 ViewModel 必须标记 `@MainActor`**，编译器会严格检查（`StrictConcurrency` 已启用）
- `CalendarManager` 是 `@MainActor` 单例（`class CalendarManager: ObservableObject`），内部 `EKEventStore` 操作使用 `async/await`
- `ReviewViewModel` 的测试需要 `@MainActor`，因为 `ReviewViewModel` 是 MainActor 隔离的

### 视图结构

- **主窗口**：固定 400x600，浮动层级（`window.level = .floating`），不可调整大小
- **快捷键**：Cmd+Enter 通过 `NotificationCenter` 触发 `createReviewSchedule`，不是 SwiftUI 原生 `keyboardShortcut`
  - 通知名：`Notification.Name.createReviewSchedule`
  - 发送方：`一键日历App.swift` 中的 `CommandMenu`
  - 接收方：`ReviewViewModel.init()` 中注册的观察者
- **视图拆分**：6 个子视图（`Title/Date/ReviewPreview/Action/History/IntervalSettings`），主容器是 `ContentView`

### 数据持久化

- **存储方式**：`@AppStorage` 存 JSON 字符串，不是原生 plist
  - `reviewIntervalsData`：默认 `[3, 7, 30]`，可自定义
  - `historyEntriesData`：上限 20 条，超出自动截断
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
│   └── HistoryEntry.swift         # 历史记录模型（Codable）
├── Views/
│   ├── ContentView.swift          # 主容器（ScrollView + VStack）
│   ├── TitleInputSection.swift    # 标题输入（TextField）
│   ├── DatePickerSection.swift    # 日期选择（DatePicker，onChange 刷新预览）
│   ├── ReviewPreviewSection.swift # 复习预览（ForEach 显示日期列表）
│   ├── ActionSection.swift        # 操作按钮（创建/撤销/结果提示/权限设置）
│   ├── HistorySection.swift       # 历史记录（ScrollView 最大高度 150）
│   └── IntervalSettingsSection.swift # 间隔设置（3 个 TextField + 校验）
├── ViewModels/
│   └── ReviewViewModel.swift      # 业务逻辑 + AppStorage 读写 + 通知监听
├── Services/
│   └── CalendarManager.swift      # EventKit 单例封装（创建/撤销/重复检测）
├── Utils/
│   └── DateFormatter+Extension.swift  # 日期格式化（中文长格式 + 短格式）
└── Resources/zh.lproj/
    └── Localizable.strings        # 中文本地化源文件

Tests/一键日历Tests/
└── 一键日历Tests.swift            # 单元测试

Package.swift                      # SPM 配置（swift-tools-version: 6.0）
Info.plist                         # 应用元数据 + 权限声明
```

## 操作注意事项

- **修改 UI 文本必须同步更新 `Localizable.strings`**，否则中文环境下显示 key
- **不要引入 `!` 强制解包**（项目已清理），日期计算用 `if let` 安全处理
- **`NotificationCenter` 观察者需要在 `deinit` 中移除**，避免内存泄漏
- **`IntervalSettingsSection` 的 `tempIntervals` 是本地 `@State`**，保存时才写入 `viewModel.reviewIntervals`
- **重复检测是在创建时实时读取日历**，不是创建前批量检测，因此可能部分成功部分警告
- **根目录的 `一键日历.app` 是预构建产物**，修改代码后需重新 build 并手动替换
