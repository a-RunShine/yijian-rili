# 一键日历

> 基于艾宾浩斯遗忘曲线的 macOS 复习提醒工具

输入标题和日期，一键在系统日历中创建 3 个复习日程，按照科学间隔（默认 3 天、7 天、30 天）帮助巩固记忆。

## 功能特性

- **一键创建**：输入标题和日期，自动生成复习日程
- **科学间隔**：基于艾宾浩斯遗忘曲线，默认间隔 3/7/30 天
- **自定义间隔**：支持修改复习间隔天数
- **撤销功能**：一键撤销最近创建的复习日程
- **历史记录**：保存最近 20 条复习计划，点击快速复用
- **全天日程**：自动创建全天事件，无需设置具体时间
- **重复检测**：自动检测重复日程并给出警告提示
- **快捷键**：Cmd+Enter 快速创建
- **深色模式**：自动适配系统浅色/深色模式

## 界面预览

```
┌─────────────────────────────┐
│          一键日历            │
├─────────────────────────────┤
│  标题：复习英语             │
│  日期：2026年06月12日       │
│  复习计划：                 │
│    第1次复习  06月15日      │
│    第2次复习  06月19日      │
│    第3次复习  07月12日      │
│  [一键创建]    [撤销]        │
└─────────────────────────────┘
```

## 系统要求

- **macOS 14.0** 或更高版本
- **日历访问权限**（首次使用时会请求 Full Access）

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

# Release 构建并打包
swift build -c release
mkdir -p 一键日历.app/Contents/MacOS
cp .build/release/一键日历 一键日历.app/Contents/MacOS/
```

## 使用指南

1. 打开应用，输入复习内容（如"复习英语单词"）
2. 选择开始日期（默认为今天）
3. 点击「一键创建」或按 **Cmd+Enter**
4. 首次使用时会请求日历权限，点击「允许」
5. 查看创建结果提示

创建的日程可在系统 **Calendar.app** 中查看。

## 技术栈

- **Swift 6.0** + `StrictConcurrency`
- **SwiftUI** - 声明式 UI
- **EventKit** - 系统日历集成
- **Swift Package Manager** - 依赖管理
- **本地化** - 默认中文，文本通过 `NSLocalizedString` 管理

## 项目结构

```
一键日历/
├── Sources/一键日历/
│   ├── 一键日历App.swift              # 应用入口
│   ├── Models/
│   │   ├── ReviewEvent.swift          # 复习事件模型
│   │   └── HistoryEntry.swift         # 历史记录模型
│   ├── Views/
│   │   ├── ContentView.swift          # 主容器
│   │   ├── TitleInputSection.swift    # 标题输入
│   │   ├── DatePickerSection.swift    # 日期选择
│   │   ├── ReviewPreviewSection.swift # 复习预览
│   │   ├── ActionSection.swift        # 操作按钮
│   │   ├── HistorySection.swift       # 历史记录
│   │   └── IntervalSettingsSection.swift # 间隔设置
│   ├── ViewModels/
│   │   └── ReviewViewModel.swift      # 业务逻辑 + AppStorage
│   ├── Services/
│   │   └── CalendarManager.swift      # EventKit 封装
│   ├── Utils/
│   │   └── DateFormatter+Extension.swift
│   └── Resources/zh.lproj/
│       └── Localizable.strings        # 中文本地化
├── Tests/一键日历Tests/
├── Package.swift
├── Info.plist
└── README.md
```

## 常见问题

**Q: 为什么需要日历权限？**
A: 需要 `Full Access` 权限来创建日程并检测重复。

**Q: 可以删除已创建的日程吗？**
A: 应用提供一键撤销功能。更早的日程可在 Calendar.app 中手动删除。

**Q: 支持 iOS 或 iPadOS 吗？**
A: 当前版本仅支持 macOS。

## 许可

本项目采用 [MIT 许可证](LICENSE)。
