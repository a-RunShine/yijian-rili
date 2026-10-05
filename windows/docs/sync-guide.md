# Windows 云日历同步引导

一键日历 **不直接连接** CalDAV / Graph；它写入系统日历，由账户同步到手机。

## 推荐：Outlook.com / Microsoft 365

1. 打开 **设置 → 账户 → 电子邮件和账户**，添加 Microsoft 账户。
2. 打开系统 **日历** 应用，确认该账户下的日历可见且可写入。
3. 在一键日历「写入日历」中选择 Outlook 日历（不要选本地）。
4. 手机使用同一 Microsoft 账户（Outlook App 或系统日历）。

深度链接：`ms-settings:emailandaccounts` · 打开日历：`outlookcal:`

## 备选：Google 日历

1. 在 Windows「设置 → 账户」添加 Google 账户并开启日历同步。
2. 系统日历中确认 Google 日历可见。
3. 在一键日历中选择该日历后创建。
4. 手机使用同一 Google 账户打开日历。

## 与 macOS 版差异

| | macOS | Windows |
|---|---|---|
| 引导优先 | 163 / 139 CalDAV | Outlook / Google |
| 本地日历 | 可写，黄警告 | 可写，黄警告 |
| 163/139 | 系统日历支持较好 | 系统支持弱，不作为默认引导 |

App 内「?」按钮与首次无云账户时的自动弹窗均使用上述内容（见 `Views/SyncGuideDialog.xaml`）。
