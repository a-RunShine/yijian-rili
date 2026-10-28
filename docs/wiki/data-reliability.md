# 数据可靠性：静默丢失这一类缺陷

## 2026-10-28：主线定为「用户数据不可静默丢失」

用户损失了两批数据之后（8 条历史 id 被剪空、1 条创建时历史未写入），决定把接下来一段时间的主线放在数据可靠性，而不是功能或 Windows 移植。

理由：这类缺陷的代价不对称。丢一个功能只是不能用，丢一批历史是**永久不可自愈**——`createdEventIdentifiers` 一旦为空，连属性匹配的锚点都没有。

## 这一类缺陷的共同形状

2026-10-28 修的三个 bug 表面无关，形状相同：

| 缺陷 | 错误的推断 |
|---|---|
| 无权限时对账删 id | 「`event(withId:)` 返回 nil」⇒「事件已被用户删除」 |
| 系列身份依赖 `eventIdentifier` | 「id 相同」⇒「是同一个事件」 |
| 成员只从月窗解析 | 「窗口内没找到」⇒「不存在」 |

统称：**把「读不到」当成「不存在」，再基于这个错误推断去写。**

修单个症状不够，因为同形状的代码还在。2026-10-28 的审计点名了至少三处（见下）。

## 已确认同形状的路径（2026-10-28 审计，全部已修）

2026-10-28 之后，下面每一条都有测试锁定，且都先红后绿：

- `HistoryStore.load()` 在 JSON 解码失败时返回 `[]`，`add()` 是 `load()` → `insert` → `save()`。一次解码失败后下一次创建就把只剩 1 条的列表写回，历史全灭。**影响面最大**——一次坏载荷能摧毁全部数据。
- `OccurrenceStatusStore` 以 event id 为 key。`HistorySeriesLookup` 已改属性匹配兜底，状态存储当时未改。
- `HistoryStore.maxEntries = 20` 静默 `prefix(20)`，且被裁掉的条目仍留在周回顾与状态里。
- `ReviewSession.create()` 在 `await` 之后读 `baseDate` / `scheduleMode`，等待期间用户改动会把错值落盘。
- `undo()` 在一条事件都没删掉时仍丢弃历史。
- 迁移完成标记在载荷损坏时被提前写死。

## 约束「不可静默丢失」的含义

一条写入路径只有满足下面全部条件才算合格：

1. **区分「空」与「损坏」。** 解码失败不能等同于「没有数据」。
2. **损坏时降级，不清空。** 保留原始值（原始字符串本身是可恢复的证据），进入只读状态并告知用户，直到用户明确选择处理方式。
3. **写入前确认基线。** 不允许基于「读出来是空」的基线做覆盖写，除非确认存储确实是空的。
4. **容量上限要可感知。** 截断等于删除，必须让用户知道并能导出。

## 落地方式：让写错在类型上不成立

不是逐个补 `try?`，而是把写路径收进一个封装，调用方拿不到「我以为它是空」这个机会：

| 类型 | 用途 |
|---|---|
| `PersistentPayload` | 损坏检测、按元素 salvage、`.damaged` 旁路留证 |
| `PersistentArray<T>` | 数组型存储，写路径只走 `mutate` |
| `PersistentDictionary<T>` | 字典型存储 |
| `PersistentValue<T>` | 单对象存储（如 `WeeklyNotes`） |

每次 `save` 同时写主键与 `.backup` 键。主键损坏时从 backup 恢复**完整**数据，而不是尽力捞碎片——碎片的是残缺数据，比明确失败更危险。

`load()` 返回 `PayloadHealth`（`intact` / `partiallyRecovered` / `restoredFromBackup` / `unreadable`），损坏不再无声无息。

**门禁**：`make lint` 禁止在 `Sources` 下绕过 `PersistentPayload` 直接解码。这条规则上线时立刻抓出了 2 处遗漏（`reviewIntervalsData`、`savedIntervalsSnapshot`）。

## 状态存储的身份

`OccurrenceStatusStore` 的 key 从裸 event id 改为 `series:<历史条目 UUID>:<复习序号>`，id 只作快路径。原因同「系列身份」：`eventIdentifier` 会被 CalDAV 重分配。

解析顺序：能从事件属性算出系列身份时用 `series:` 键；事件已被删时，从历史的 `createdEventIdentifiers` 与复习日的位置关系反推；都不行才退回 `event:` 旧键（并支持迁移）。

## 验证方式：反馈循环优先

2026-10-28 的教训已写进 [verification.md](verification.md)：装应用 → 用户手动点 → 读日志 这个循环一轮几分钟，期间三次归因全错；换成 0.2 秒的测试后，三次修复都在几分钟内完成。

本主线沿用：每个缺陷先写一条会红的测试，再修；修完把防护拿掉确认测试会红。

真机验证攒批进行——只在自动化测试覆盖不到的交互（渲染、点击命中、真实 CalDAV 同步）上请用户出手。

## 相关页面

- [verification.md](verification.md)：三个连环 bug 的完整诊断过程与反馈循环方法论
- [constraints.md](constraints.md)：硬约束如何被机器强制

## 2026-10-28 的审计数字

用 `InMemoryCalendarService` 与 `reassignAllEventIdentifiersForTesting()` 复现，全部结论有可执行测试支撑：

| 项 | 数字 |
|---|---|
| 审计写出的测试 | 26 条 |
| 确认的独立缺陷 | 17 个 |
| 审计时红灯 | 21 个断言 |
| 修完后 | 239 测试全绿（原有 213 条无回归） |

其中 3 条审计测试本身断言自相矛盾（先要求「损坏后读空」又要求「修复后恢复全部」），已按「备份恢复」的语义改正。另有 5 条是「坐实缺陷现状」型——它们断言的是错误行为，修完后必须反过来改，否则等于把 bug 写成规格。

**教训**：写审计测试时「先写测试」还不够，要分清哪些测试是在**描述期望**、哪些是在**记录现状**。后者修复后必须改，否则会变成回归陷阱。

## 观测工具

2026-10-28 加了两个入口，因为在此之前「看不到用户数据状态」本身就是排查的最大障碍，每次都要现写脚本读 plist，还读错过一次（把 Apple 纪元秒当 Unix 时间戳，显示成 1995 年）。

```bash
make inspect-data   # 历史条目、id 是否为空、完成标记有多少条已失联
make backup-data    # 备份到 ~/Library/Application Support/yijian-rili-backups/ 并校验
```

判据写进输出而不是靠人记：

- 历史条目：`createdEventIdentifiers` 是否非空。空的等于失去系列身份，不会自愈
- 完成标记：「标记数 − 能对上历史 id 的数量」不为 0 说明同步重分配 id 时丢过

## 尚未验证

- **真实 CalDAV 侧的重分配触发条件。** 依赖 `reassignAllEventIdentifiersForTesting()` 的建模（全量换 id、属性不变），没有在真机账户上实测是否部分重分配。
- **坏载荷的真实成因。** 验证了「坏载荷 → 丢数据」的因果链，但没有复现生产环境里坏载荷怎么产生的（半截写入？磁盘满？`cfprefsd` 崩溃？）。所有坏载荷都是手工构造的。
- **多窗口并发写。** `HistoryStore` 没有跨实例同步，两个 `ReviewViewModel` 同时 `add()` 会互相覆盖（读-改-写无锁）。没有测试，也没确认 app 是否真会开两个窗口。
- **Windows 移植层同模式。** `windows/YijianRili.Domain/Services/HistoryStore.cs` 是同一个「解码失败当空」的写法，未跑 `dotnet test` 验证，也未修。
