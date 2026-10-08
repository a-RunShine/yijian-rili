# 手机日历同步（macOS CalDAV）

事件写到哪个云账户，就会同步到绑定了同一账户的手机。「同步到手机」取决于**写入日历**选中的账户，不是 App 另开通道。

生产写入走 EventKit；目标日历由用户在 App 内选择（`selectedCalendarIdentifier`），缺省/回退与系统默认日历相关。选「本地」可创建，但不会同步到手机（UI 有警告）。

## 推荐配置：网易 163 邮箱（CalDAV）

1. **163 邮箱开 CalDAV**：登录 [mail.163.com](https://mail.163.com) → 设置 → 账户 → CalDAV 服务 → 开启 → 生成授权码
2. **macOS 加账户**：打开「日历」App → 菜单「日历 → 添加账户」→ 选「其他 CalDAV 账户」→ 手动：
   - 用户名：`xxx@163.com`
   - 密码：刚生成的授权码
   - 服务器：`caldav.163.com`
   - 端口：`443` / SSL 启用
3. **手机加账户**（例：一加 ColorOS「日历 → 我的 → 添加日历 → CalDAV 账号」）→ 同一套
4. **设为默认（可选）**：macOS「日历」里选中 163 下某日历 → 右键 → 设为默认；App 内也可直接选该日历作为写入目标

## 备选 CalDAV / 同步源

| 服务 | 服务器 | 备注 |
|---|---|---|
| 网易 163 个人邮箱 | `caldav.163.com:443` | 免费、稳定，需隐藏路径开启 |
| 中国移动 139 邮箱 | `cal.caiyun.mail.10086.cn:443` | 手机号即邮箱（授权码 90 天有效） |
| 阿里云企业邮箱 | `caldav.mxhichina.com` | 收费版较稳 |
| iCloud | `https://caldav.icloud.com` | 中国大陆区 Apple ID 常需代理 |
| Google Calendar | 系统自动 | 部分 Android 需 Google Play Services |
| Outlook.com | `s.outlook.com:443` EAS | ColorOS 系统入口可能有 TLS 坑，可改用 Outlook App |
| QQ 邮箱 | — | 不支持 CalDAV |

## App 内行为（agent 相关）

- 主界面「写入日历」可选账户；本地账户允许写入但提示不同步
- 首次启动若未配置云日历，约 3s 后可弹引导；右上角「?」可重看
- `@AppStorage("selectedCalendarIdentifier")` 持久化选择；日历被删/账户注销时回退系统默认并提示

Windows 移植的同步引导是 Outlook / Google 优先，见 `windows/README.md`，不要把本页 CalDAV 步骤套到 Windows。
