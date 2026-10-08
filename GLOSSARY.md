# 一键日历

基于艾宾浩斯遗忘曲线，把复习提醒写入系统日历的桌面应用。

## Language

**复习日程**:
按复习间隔从基准日算出的一组全天提醒（默认间隔 3/7/30 天）。
_Avoid_: 复习事件包, spaced-repetition events

**写入日历**:
把复习日程或单次日程保存到用户选定的目标日历账户。
_Avoid_: 同步到手机, EventKit write

**云日历**:
可在设备间同步的日历账户（非本地）。
_Avoid_: CalDAV, iCloud 账户（实现细节）

**本地日历**:
仅本机、不会同步到手机的日历。
_Avoid_: On My Mac only（可作为 UI 文案）

**日历 seam**:
可替换的系统日历读写位置；生产为 EventKit adapter，测试为 in-memory adapter。
_Avoid_: CalendarManager 服务, EventKit boundary, calendar API

**EventKit adapter**:
日历 seam 的 macOS 生产实现，封装 EventKit（类型名可仍为 CalendarManager）。
_Avoid_: 把「CalendarManager」当作领域概念

**复习备注键**:
用于重复检测的稳定备注身份；复习为「第N次复习」，单次为空字符串。
_Avoid_: EventKit notes 原文, Details 全文

**重复检测**:
同一目标日历内，按标题 + 日历日 + 规范化后的复习备注键判断是否已存在写入。
_Avoid_: 仅比标题

**写入日历编排**:
深 module：校验间隔、计算复习日、生成备注键、重复检测、经 store 写入并汇总结果。
_Avoid_: CalendarManager 里的 create 循环（实现细节）

**复习会话**:
无 UI 依赖的创建/撤销/预览与间隔状态核心，对齐 Windows ReviewSession。
_Avoid_: 把 ReviewViewModel 当作会话本身

**日程浏览**:
按日日程列表与标题搜索（含按 id 删除）的只读偏 module。
_Avoid_: 塞进复习会话

**界面 facade**:
SwiftUI 观察、系统通知与 AppKit 副作用的薄 adapter；过渡期类型名可仍为 ReviewViewModel。
_Avoid_: 业务决策中心

**创建成功 outcomes**:
接收「日历写入纯成功」后的持久化编排：历史 cap-20 append + 周末总结 append（含预占位）；清/删历史与 undo 不触达周末总结。
_Avoid_: ReviewViewModel.commitHistoryEntry, pendingHistoryEntry 通道

**周末总结 append seam**:
创建成功 outcomes 追加 weekly entry 的窄 interface（`WeeklyEntryAppending`）；当前唯一实现是 `WeeklyReviewViewModel`。
macOS 侧专有——Windows 侧无对应 interface，直接 concrete 持有 `WeeklyReviewService`。
_Avoid_: 在 outcomes 里直接拼 WeeklyEntry

**历史记录 store**:
最近创建记录的 capped JSON 持久化（默认 20）；与周末总结物理分离。
_Avoid_: 当作周末总结的唯一数据源
