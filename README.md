# 一键日历

> 基于艾宾浩斯遗忘曲线的 macOS 复习提醒工具，支持手机日历同步

输入标题和日期，一键在系统日历中创建复习日程，按科学间隔（默认 3/7/30 天，可自定义）帮助巩固记忆；可选云日历账户，写入即同步到一加 12/iPhone/安卓手机。

## 功能特性

- **一键创建**：输入标题和日期，自动生成复习日程
- **科学间隔**：基于艾宾浩斯遗忘曲线，默认间隔 3/7/30 天，可自定义任意天数
- **间隔预设**：内置「经典艾宾浩斯 / 考试冲刺 / 日常复习」三套预设，一键切换
- **撤销功能**：一键撤销最近创建的复习日程（含标题提示）
- **历史记录**：保存最近 20 条复习计划，支持搜索、快速复用、单条删除
- **今日日程**：主界面直接显示今天的系统日历事件，无需切到日历 App
- **手机同步**：可选写入 iCloud / Google / Outlook / 网易 163 / 移动 139 等云日历账户，事件自动同步到手机
- **日历账户选择**：主界面 Picker 选择写入哪个账户；选「本地」有黄色警告
- **首次启动引导**：未配置云账户时自动弹 3 步配置引导
- **同步帮助**：标题栏「?」按钮随时查看配置步骤
- **全天日程**：自动创建全天事件，自动设置 9:00 提醒
- **重复检测**：自动检测目标日历内的同日同名复习事件，避免重复
- **失效回退**：选中的日历账户被删/注销时自动回退到系统默认并提示
- **快捷键**：Cmd+Enter 快速创建
- **多主题**：浅色 / 深色 / 信纸 / Claude / 跟随系统 五套主题
- **本地化**：默认中文

## 界面预览

```
┌─────────────────────────────┐
│   一键日历          [?] [主题] │
├─────────────────────────────┤
│  今日日程                  │
│  09:00  团队站会            │
│  14:00  代码评审            │
├─────────────────────────────┤
│  标题：[复习英语单词       ] │
│  日期：[2026年06月22日     ] │
│  复习计划：                 │
│    第1次复习  06月25日      │
│    第2次复习  06月29日      │
│    第3次复习  07月22日      │
│  写入日历：[163邮箱 → 日历 ] │
│  [一键创建]   [撤销]        │
└─────────────────────────────┘
```

## 系统要求

- **macOS 14.0** 或更高版本
- **日历访问权限**（首次使用时会请求 Full Access）
- 同步到手机需要 macOS 端配置云日历账户

## 安装与运行

### 方式一：直接下载

下载 `一键日历.app`，拖拽到「应用程序」文件夹即可使用。

### 方式二：从源码构建

```bash
# 克隆仓库
git clone https://github.com/yourusername/一键日历.git
cd 一键日历

# 调试构建
swift build

# 运行
swift run

# 测试
swift test

# Release 构建并打包安装
make install
```

`make install` 会编译 release 版本、复制 Info.plist / 图标 / 资源、ad-hoc 签名、最后安装到 `/Applications/一键日历.app`。

## 使用指南

### 基本流程

1. 打开应用，输入复习内容（如"复习英语单词"）
2. 选择开始日期（默认为今天）
3. 点击「一键创建」或按 **Cmd+Enter**
4. 首次使用时会请求日历权限，点击「允许」

### 📱 同步到手机日历（一加 12 / iPhone / 安卓）

事件默认写入**系统默认日历**。要让手机也能看到，需把 macOS「日历」App 默认账户改成云账户，或在「一键日历」主界面「写入日历」Section 显式选择云账户。

#### 推荐：网易 163 个人邮箱（CalDAV，免费、稳定）

1. **163 邮箱开 CalDAV**
   - 登录 [mail.163.com](https://mail.163.com) → 设置 → 账户 → POP3/IMAP/SMTP/Exchange/CardDAV/**CalDAV 服务** → 开启 → 生成授权码
2. **macOS 加账户**
   - 「日历」App → 菜单「日历 → 添加账户」→ 选「**其他 CalDAV 账户**」→ 手动
   - 用户名：`xxx@163.com`
   - 密码：刚生成的**授权码**（不是登录密码）
   - 服务器：`caldav.163.com`
   - 端口：`443` / SSL 启用
3. **一加 12 加账户**
   - 「日历 → 我的 → 添加日历 → CalDAV 账号」→ 同一套 163 邮箱和授权码，服务器 `caldav.163.com`
4. **在「一键日历」选 163 账户下某个日历**作为写入目标

#### 备选：移动 139 邮箱（手机号即邮箱，零门槛）

服务器：`cal.caiyun.mail.10086.cn:443`，用户名 `手机号@139.com`，密码走授权码（90 天有效）。注意 ColorOS 16 系统日历 CalDAV 只能查看不能编辑，需可编辑请改用 Exchange 协议（`ex.mail.10086.cn`，会顺带同步邮件）。

#### 其他可选 CalDAV 源

| 服务 | 服务器 | 备注 |
|---|---|---|
| 网易 163 | `caldav.163.com:443` | ⭐⭐⭐ 免费稳定 |
| 移动 139 | `cal.caiyun.mail.10086.cn:443` | ⭐⭐⭐ 手机号即邮箱 |
| 阿里云企业邮箱 | `caldav.mxhichina.com` | ⭐⭐ 收费版稳定 |
| iCloud | `https://caldav.icloud.com` | ⭐⭐ 中国大陆区 Apple ID 需代理 |
| Google | 系统自动 | ⭐⭐ 需装 Google Play Services |
| Outlook.com | `s.outlook.com:443` EAS | ⭐⭐ ColorOS 16 需装 Outlook App |
| QQ 邮箱 | ❌ 不支持 | — |

#### 首次启动引导

App 启动 3 秒后若检测到「无云日历 + 未引导过」，自动弹出 3 步配置引导。可在「写入日历」Section 选 163 / 139 两个 provider 切换步骤。

#### 「?」帮助按钮

主界面右上角「?」按钮随时可重看配置步骤（不会标记为已引导）。

> 详细的本地日历 → 云日历迁移指南、AGENTS.md、OpenSpec 规范等请见仓库其他文档。

## 技术栈

- **Swift 6.0** + `StrictConcurrency`
- **SwiftUI** - 声明式 UI
- **EventKit** - 系统日历集成（含 `EKEventStore.calendars(for:)` 选择账户）
- **Swift Package Manager** - 依赖管理
- **本地化** - 默认中文，文本通过 `NSLocalizedString` 管理

## 项目结构

```
一键日历/
├── Sources/一键日历/
│   ├── 一键日历App.swift              # 应用入口
│   ├── Models/
│   │   ├── ReviewEvent.swift          # 复习事件模型
│   │   ├── HistoryEntry.swift         # 历史记录模型
│   │   └── Theme.swift                # 主题枚举
│   ├── Views/
│   │   ├── ContentView.swift          # 主容器（含 9 个 Section 编排）
│   │   ├── TitleInputSection.swift    # 标题输入
│   │   ├── DatePickerSection.swift    # 日期选择
│   │   ├── ReviewPreviewSection.swift # 复习预览
│   │   ├── CalendarPickerSection.swift # 日历账户选择（按 source 分组）
│   │   ├── FirstRunGuideView.swift    # 首次启动引导（163/139 切换）
│   │   ├── ActionSection.swift        # 操作按钮
│   │   ├── HistorySection.swift       # 历史记录弹窗
│   │   ├── IntervalSettingsSection.swift # 间隔设置
│   │   └── TodayEventsSection.swift   # 今日日程卡片
│   ├── ViewModels/
│   │   └── ReviewViewModel.swift      # 业务逻辑 + AppStorage + 日历桥接
│   ├── Services/
│   │   └── CalendarManager.swift      # EventKit 封装（含多日历账户扫描）
│   ├── Utils/
│   │   └── DateFormatter+Extension.swift
│   └── Resources/zh.lproj/
│       └── Localizable.strings        # 中文本地化
├── Tests/一键日历Tests/                # 10 个单元测试
├── Package.swift
├── Info.plist
├── Makefile                            # build/bundle/install 目标
├── AGENTS.md                           # 给 AI 协作的工程规范
└── README.md
```

## 常见问题

**Q: 为什么需要日历权限？**
A: 需要 `Full Access` 权限来读取日历列表、创建日程、检测重复。

**Q: 怎么让手机也能看到复习日程？**
A: 把 macOS「日历」App 的默认账户改成云账户（iCloud / Google / Outlook / 163 / 139），或在「一键日历」主界面「写入日历」Section 选云账户。详见上方「同步到手机日历」章节。

**Q: 选「本地」日历会有什么问题？**
A: 本地日历事件只存在 Mac 本地，不同步到任何云端和手机。App 会在选中时给黄色警告，但允许创建。

**Q: 可以删除已创建的日程吗？**
A: 应用提供一键撤销功能（最近一批）。更早的日程可在 Calendar.app 中手动删除。

**Q: 支持 iOS 或 iPadOS 吗？**
A: 当前版本仅支持 macOS。手机端通过云日历同步看到（iOS 原生支持，Android 需走系统日历 CalDAV）。

**Q: 之前写到本地的复习事件怎么搬到云？**
A: 在 macOS「日历」App 里多选本地事件 → Control 点击 → 日历 → 选云账户下的目标日历。详见 AGENTS.md。

## 许可

本项目采用 [MIT 许可证](LICENSE)。
