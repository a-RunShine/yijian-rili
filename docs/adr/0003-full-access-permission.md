# 0003 申请 Full Access 日历权限

- **状态**：已采纳
- **日期**：2026-10-20（迁入本目录）
- **来源**：`openspec/changes/one-click-calendar/design.md` 第 3 节

## 决策

申请 `NSCalendarsFullAccessUsageDescription`（完全访问），而非 write-only 权限。请求时机推迟到用户首次点击「创建」时，不在启动时申请。

## 背景

macOS 14 起日历权限分 write-only 与 full access 两级。权限级别决定了应用能做什么。

## 理由

- **需要读取**：重复检测要求读取目标日历内已有的同名同日期日程，才能给出「已存在」警告。write-only 读不到，查重功能无法实现
- **触发时机**：全访问权限允许延后请求。等到用户明确看到功能、点了「创建」再申请，符合最小权限原则，授权率也更高
- 用户已经表达意图之后再弹权限框，比启动即弹更容易被理解

## 替代方案

**Write-Only**：隐私侵扰更小，但无法做重复检测。由于查重是对用户承诺过的功能（见 [0005](0005-allow-duplicate-with-warning.md)），选了 full access。

## 后续影响

- `Info.plist` 必须包含 `NSCalendarsFullAccessUsageDescription`
- 裸 `swift run` 没有 app bundle 上下文，该声明不生效 → `Makefile` 的 `run` 目标刻意失败并提示改用 `make open`
- 权限被拒时的降级路径：界面给出清晰说明与「打开系统设置」入口
