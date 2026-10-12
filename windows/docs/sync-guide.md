# Windows 云日历同步引导

一键日历 **不直接连接** CalDAV / Graph；它通过 WinRT 写入**系统日历**，由账户同步到手机。

## 重要：必须用 MSIX 安装

WinRT 读写系统日历需要 **package identity** + `appointments` 能力。

- 正确：安装生成的 `.msix`（或 Visual Studio 部署的打包应用）
- 错误：直接运行未打包的 `.exe`（`WindowsPackageType=None`）→「写入日历」只有「系统默认」、创建失败

首次安装未签名 MSIX 时，请开启 Windows「开发人员模式」或「允许应用安装 / 旁加载」。

## 重要：浏览器登录 ≠ Windows 日历账户

仅在 Chrome / Edge 登录 Gmail **不够**。必须：

1. 打开 **设置 → 账户 → 电子邮件和账户**
2. **添加账户** → Google（或 Outlook）
3. 勾选 / 开启 **日历** 同步
4. 打开系统 **日历** App，确认左侧能看到 Google 日历
5. 回到一键日历，在「写入日历」中选择该 Google 日历（不要停在「系统默认」）

## 推荐：Outlook.com / Microsoft 365

1. 「设置 → 账户」添加 Microsoft 账户  
2. 系统日历可见后，在一键日历中选择 Outlook 日历  
3. 手机使用同一 Microsoft 账户  

深度链接：`ms-settings:emailandaccounts` · 打开日历：`outlookcal:`

## 备选：Google 日历

同上「Windows 账户」步骤；手机使用同一 Google 账户打开日历。

## 与 macOS 版差异

| | macOS | Windows |
|---|---|---|
| 打包 | `.app` + Info.plist 权限 | **MSIX** + appointments 能力 |
| 引导优先 | 163 / 139 CalDAV | Outlook / Google（系统账户） |
| 本地日历 | 可写，黄警告 | 可写，黄警告 |
| 163/139 | 系统日历支持较好 | 系统支持弱，不作为默认引导 |
