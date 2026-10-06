# 一键日历 · Windows

C# / WinUI 3 / .NET 8 移植，领域逻辑与 macOS 版对齐；日历层使用 WinRT `Windows.ApplicationModel.Appointments`。

## 解决方案结构

| 项目 | 目标框架 | 说明 |
|---|---|---|
| `YijianRili.Domain` | `net8.0` | 可复用领域：日期、间隔、历史、周末总结、`ICalendarService` |
| `YijianRili.Domain.Tests` | `net8.0` | 单元测试（可在 Linux/macOS/Windows 运行） |
| `YijianRili.Calendar` | `net8.0-windows10.0.19041.0` | WinRT Appointments 适配 |
| `YijianRili.App` | `net8.0-windows10.0.19041.0` | WinUI 3 主程序（MVP） |

## 功能对等（MVP）

- 复习计划 / 单次日程创建（全天事件）
- 间隔预设（经典 / 考试 / 日常）与预览
- 撤销最近创建、再建一个
- 历史记录（本地 JSON，上限 20）
- 昨天 / 今天 / 明天日程列表
- 日历账户选择 + 本地日历警告
- 窗口置顶、固定 400×600、`Ctrl+Enter` 创建
- 首次引导 /「?」：Outlook / Google 同步说明（非 macOS CalDAV）

周末总结领域服务已在 `Domain` 中移植；WinUI 周视图 UI 可后续迭代挂载。

## 构建

### 领域层（任意平台）

```bash
cd windows
dotnet test YijianRili.Domain.Tests/YijianRili.Domain.Tests.csproj
```

### 完整 Windows 应用（需 Windows 10/11 + Windows App SDK）

**必须打 MSIX 包**（`WindowsPackageType=MSIX`）。直接跑未打包 exe 时，WinRT 拿不到系统/Google 日历，界面会只显示「系统默认」且创建失败。

```powershell
cd windows
dotnet restore YijianRili.sln
dotnet build YijianRili.App/YijianRili.App.csproj -c Release -p:Platform=x64
# 输出目录中的 .msix / 用 Visual Studio「部署」安装到本机
```

推荐：用 Visual Studio 2022 打开 `YijianRili.sln`，安装「Windows 应用开发」工作负载，F5 部署打包应用。

未签名 MSIX 旁加载需开启「开发人员模式」。

## 权限与同步

1. 用 **MSIX** 安装（见上）。
2. 首次启动允许日历权限。
3. 在 Windows「设置 → 账户 → 电子邮件和账户」添加 **Outlook** 或 **Google**，并开启**日历同步**（仅浏览器登录 Gmail 无效）。
4. 打开系统「日历」App 确认账户下有日历。
5. 在本 App「写入日历」选择该云日历（勿停在「系统默认」）。
6. 手机使用同一账户即可看到复习日程。

> 说明：WinRT 全天事件的定点 09:00 提醒能力弱于 EventKit；事件备注中会提示建议提醒时间。可靠响铃可后续改为 09:00 定时事件。

## 与 macOS 版差异

| 项 | macOS | Windows |
|---|---|---|
| 日历 API | EventKit | WinRT Appointments |
| 快捷键 | Cmd+Enter | Ctrl+Enter |
| 同步引导 | 163 / 139 CalDAV | Outlook / Google 优先 |
| 触觉反馈 | 有 | 无 |
| 周末总结 UI | 有 | 领域已就绪，UI 待挂载 |
