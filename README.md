# 一键日历

> 基于艾宾浩斯遗忘曲线的复习提醒工具

一个极简的 macOS 应用，帮助您快速创建复习提醒日程。输入标题和日期，一键在系统日历中创建3个复习提醒，按照科学的间隔帮助您巩固记忆。

---

## 功能特性

- **一键创建**：输入标题和日期，自动生成3个复习日程
- **科学间隔**：基于艾宾浩斯遗忘曲线，默认间隔为 3天、7天、30天
- **自定义间隔**：支持修改复习间隔天数，满足个性化需求
- **撤销功能**：一键撤销最近创建的复习日程
- **历史记录**：保存最近创建的复习计划，点击即可快速复用
- **全天日程**：自动创建全天日程，无需设置具体时间
- **复习标记**：每个日程备注自动标注"第1次复习"、"第2次复习"、"第3次复习"
- **重复检测**：自动检测重复日程并给出警告提示
- **权限控制**：首次使用时请求日历权限，保护隐私
- **键盘快捷键**：支持 Cmd+Enter 快速创建
- **深色模式**：自动适配系统浅色/深色模式

---

## 界面预览

```
┌─────────────────────────────┐
│          一键日历            │
├─────────────────────────────┤
│                             │
│  标题                       │
│  ┌─────────────────────┐   │
│  │ 复习英语             │   │
│  └─────────────────────┘   │
│                             │
│  日期                       │
│  2026年06月12日      ▼      │
│                             │
│  复习计划                    │
│  第1次复习        06月15日  │
│  第2次复习        06月19日  │
│  第3次复习        07月12日  │
│                             │
│  历史记录                    │
│  复习英语        06月12日  │
│  复习数学        06月11日  │
│                             │
│  复习间隔                    │
│  第1次: 3天  第2次: 7天  │
│  第3次: 30天                │
│                             │
│  [一键创建]    [撤销]        │
│                             │
│  ✅ 成功创建3个复习日程       │
│                             │
└─────────────────────────────┘
```

---

## 系统要求

- **macOS 14.0** 或更高版本
- **Apple Silicon** 或 Intel 处理器
- **日历访问权限**（首次使用时会请求）

---

## 安装方式

### 方式一：直接下载（推荐）

1. 下载最新版本的 `一键日历.app`
2. 将应用拖拽到 `应用程序` 文件夹
3. 双击打开即可使用

### 方式二：从源码构建

```bash
# 克隆仓库
git clone https://github.com/yourusername/一键日历.git
cd 一键日历

# 构建 Release 版本
swift build -c release

# 运行应用
open .build/release/一键日历
```

---

## 使用指南

### 创建复习计划

1. 打开应用
2. 在"标题"输入框输入复习内容（如"复习英语单词"）
3. 选择开始日期（默认为今天）
4. 点击"一键创建"按钮或按 **Cmd+Enter**
5. 首次使用时会弹出日历权限请求，点击**允许**
6. 查看创建结果提示

### 查看复习日程

打开系统自带的 **Calendar.app**（日历），您可以在选择的日期看到3个复习提醒：
- 开始日期 + 3天
- 开始日期 + 7天
- 开始日期 + 30天

### 快捷键

| 快捷键 | 功能 |
|--------|------|
| **Cmd + Enter** | 一键创建复习日程 |
| **Tab** | 在标题和日期之间切换焦点 |

---

## 技术架构

### 技术栈

- **Swift 6.0** - 现代 Swift 语言特性
- **SwiftUI** - 声明式 UI 框架
- **EventKit** - Apple 原生日历框架
- **Swift Package Manager** - 依赖管理

### 项目结构

```
一键日历/
├── Sources/一键日历/
│   ├── 一键日历App.swift              # 应用入口
│   ├── Models/
│   │   ├── ReviewEvent.swift          # 复习事件数据模型
│   │   └── HistoryEntry.swift         # 历史记录数据模型
│   ├── Views/
│   │   ├── ContentView.swift          # 主界面容器视图
│   │   ├── TitleInputSection.swift    # 标题输入子视图
│   │   ├── DatePickerSection.swift    # 日期选择子视图
│   │   ├── ReviewPreviewSection.swift # 复习预览子视图
│   │   ├── ActionSection.swift        # 操作按钮子视图
│   │   ├── HistorySection.swift       # 历史记录子视图
│   │   └── IntervalSettingsSection.swift # 间隔设置子视图
│   ├── ViewModels/
│   │   └── ReviewViewModel.swift      # 业务逻辑和状态管理
│   ├── Services/
│   │   └── CalendarManager.swift      # EventKit 日历服务封装
│   ├── Utils/
│   │   └── DateFormatter+Extension.swift  # 日期格式化工具
│   └── Resources/
│       └── zh.lproj/
│           └── Localizable.strings    # 本地化资源
├── Tests/
├── Package.swift                      # SPM 配置
├── Info.plist                         # 应用配置
└── README.md                          # 项目说明
```

### 核心逻辑

```
用户输入（标题 + 日期）
    ↓
日期计算（+3天 / +7天 / +30天）
    ↓
权限检查（首次请求 Full Access）
    ↓
重复检测（读取日历比对标题）
    ↓
创建日程（3个全天事件）
    ↓
结果反馈（成功 / 警告 / 错误）
    ↓
清空输入（准备下一次创建）
```

---

## 开发指南

### 环境要求

- macOS 14.0+
- Xcode 15.0+ 或 Swift 6.0+
- Swift Package Manager

### 构建和运行

```bash
# 调试构建
swift build

# 运行
swift run

# 测试
swift test

# Release 构建
swift build -c release

# 打包为 .app
mkdir -p 一键日历.app/Contents/MacOS
cp .build/release/一键日历 一键日历.app/Contents/MacOS/
```

### 开发注意事项

- 使用 `@MainActor` 确保 UI 更新在主线程执行
- EventKit 操作需要异步处理（async/await）
- 日历权限使用 `NSCalendarsFullAccessUsageDescription`（需要读取权限检测重复）
- 所有 UI 文本通过 `Localizable.strings` 管理，支持国际化扩展

---

## 常见问题

### Q: 为什么需要日历权限？

A: 应用需要访问您的日历以创建复习提醒日程。我们使用 `Full Access` 权限，以便检测重复日程并给出警告。

### Q: 创建的日程在哪里查看？

A: 打开 macOS 自带的 **Calendar.app**（日历应用），在对应的日期可以看到创建的复习提醒。

### Q: 可以删除已创建的日程吗？

A: 应用提供一键撤销功能，可以撤销最近创建的复习日程。如果需要删除更早的日程，可以在 Calendar.app 中手动删除。

### Q: 可以自定义复习间隔吗？

A: 是的！在应用界面中可以直接修改三个复习间隔的天数，默认值为 3天、7天、30天。修改后点击"保存"即可生效。

### Q: 支持 iOS 或 iPadOS 吗？

A: 当前版本仅支持 macOS。如果需要 iOS 版本，请提交 Issue 或 PR。

### Q: 为什么显示"无法打开应用"？

A: 如果 macOS 提示"无法打开，因为无法验证开发者"，请前往 **系统设置 → 隐私与安全性** 中点击"仍要打开"。

---

## 更新日志

### v1.1.0 (2026-06-12)

- 新增撤销功能：一键撤销最近创建的复习日程
- 新增历史记录：保存最近创建的复习计划，支持快速复用
- 新增自定义间隔：支持修改复习间隔天数
- 新增视图模块化：将主视图拆分为6个独立子视图
- 修复崩溃风险：移除所有 `!` 强制解包，使用安全日期计算
- 修复内存泄漏：正确管理 NotificationCenter 观察者生命周期
- 改进重复检测：从仅比较标题改为比较标题+日期+备注
- 国际化：所有 UI 文本使用 `NSLocalizedString`
- 输入验证：增加标题空白字符和长度限制

### v1.0.0 (2026-06-12)

- 初始版本发布
- 支持创建3个复习日程（3天、7天、30天）
- 支持重复检测和警告
- 支持深色模式
- 支持键盘快捷键

---

## 贡献

欢迎提交 Issue 和 Pull Request！

### 提交 Issue

- 描述问题的重现步骤
- 提供系统版本和错误信息
- 如果可能，提供截图或录屏

### 提交代码

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

---

## 许可

本项目采用 **MIT 许可证**。

```
MIT License

Copyright (c) 2026 一键日历

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 致谢

- 基于 **艾宾浩斯遗忘曲线** 理论设计复习间隔
- 使用 **Apple EventKit** 框架与系统日历集成
- 使用 **SwiftUI** 构建现代化用户界面

---

<p align="center">
  用 ❤️ 和 📚 构建
</p>
