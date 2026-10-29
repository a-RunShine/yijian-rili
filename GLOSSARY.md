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

**备注详情提取**:
从事件备注原文去掉「第N次复习」首行（如有）与「提醒建议」行后，剩余非空内容即为用户详情（`NotesDetail.extract`）。
_Avoid_: NormalizeNotes（只取首行作备注键）

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
按日日程列表与标题搜索的只读偏 module；不承担删除。
_Avoid_: 塞进复习会话；在浏览层再写一份删除

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

**历史系列查找**:
按日历事件 id 在历史记录中定位对应系列（`createdEventIdentifiers` 包含该 id）；供日程浏览卡片打开系列共享详情。
_Avoid_: 按标题模糊匹配

**历史记录的 id 列表**:
`createdEventIdentifiers` 是一份**缓存**，不是主键。它按槽位与 `reviewDates` 对齐，空串表示该位置已被删除。读取存活标识一律走 `liveEventIdentifiers`。
_Avoid_: 把它的长度当成员数；直接按下标取而不检查是否为空

**历史记录 store**:
最近创建记录的 capped JSON 持久化（默认 20）；与周末总结物理分离。
_Avoid_: 当作周末总结的唯一数据源

**复习间隔 commit**:
接收间隔 draft（字符串列表）→ parse/校验 → 成功则持久化已提交间隔并刷新复习预览；View 只编辑 draft 并映射结构化失败。
_Avoid_: View 内自拼校验后再赋值并手调 updateReviewDates；公开 validateIntervals 当作写入 API

**复习完成态**:
某次复习 occurrence（日历事件 id）上的未标记 / 完成 / 跳过状态；由复习会话写入并持久化，周末总结只消费展示；不得写入或复用创建条目级 `reviewedIds`。
_Avoid_: F6 已复习勾选, WeeklyReviewViewModel.reviewedIds（完成态存储）

**同窗改选**:
在界面 facade 上点选或拖拽换日时，若目标日落在当前显示月份内，则只改基准日并重算复习预览：保持显示月份、不重查月窗日程；跨出显示月份选日才重绑显示月份并在窗口变化时读取新窗。
_Avoid_: 单击一律重绑显示月份；把同窗改选当成第二套翻页语义

**月格单击记账**:
月格的点击时刻记录，只用于区分「第一次单击」与「同格连击开写标题」；它是 UI 手势状态，不是第二份选中日期，选中与否仍由基准日决定。
_Avoid_: 新增 selectedDate；把连击计时当作领域状态

**日历查找可信**:
只有拿到 full access 授权时，日历查询结果才能作为「某事件是否存在」的依据。未授权时查询返回空，那是「不知道」，不是「已删除」。
_Avoid_: 把 nil 当成事件已被删除；无权限时照样对账

**对账修剪理由**:
从历史里移除已创建事件 id 的两种正当理由——日历确认缺失（需持有 `CalendarLookupAuthority`，只能由 full access 构造）与用户主动删除。没有理由不得修剪。
_Avoid_: 因为查不到所以修剪；裸 id 列表直接调用修剪

**对账结果**:
对账的三态返回：跳过（授权未就绪）/ 无变化 / 已修剪 N 个。区分「跳过」与「无变化」，使授权未就绪时可观测而不静默。
_Avoid_: 用一个 Bool 同时表示跳过与无变化

**系列身份**:
识别某个日历事件属于哪个复习批次。优先按 `createdEventIdentifiers` 精确匹配；不命中时退回**事件地址**。`eventIdentifier` 会被日历同步重新分配，不能单独作为身份。
_Avoid_: 用 eventIdentifier 当长期主键；查不到 id 就认定事件已被删除

**事件地址**:
定位一条日历事件的稳定依据——日历日 + 标题 + 复习备注键 + 目标日历。这几个字段正是我们写进日历的东西，日历同步不会改动它们，而 `eventIdentifier` 会。删除按地址定位，`createdEventIdentifiers` 只是**一次性捷径**：先试它，试不着就按地址重查。
_Avoid_: 把 id 当真相来源；地址里丢掉目标日历（会跨日历误删）

**删除结果三态**:
一次删除的三种结果——已删除 / 本来就不在 / 被拒绝（附原因）。「本来就不在」不是失败，应静默接受并清掉记录；「被拒绝」才是失败，原因要能区分无授权、日历只读、地址匹配不唯一。
_Avoid_: 用 Bool 把三种情况压成 true/false

**删除编排**:
删除的唯一执行入口：接收一组删除请求（地址 + id 捷径），逐条交给日历 seam，汇总成三态报告。删除的收尾（剪历史、清完成标记、清周回顾）由同一套逻辑按报告驱动。
_Avoid_: 每个界面入口各写一份删除循环与收尾

**删除槽位**:
`createdEventIdentifiers` 与 `reviewDates` **按位置一一对应**。删掉中间一个成员时该位置留空串占位，不得压缩数组——压缩会让后面的成员串位成前一个的身份，第三次删除就会算错目标。
_Avoid_: 用 filter 剪短数组；用「存活数」当槽位下标

**系列成员**:
某个复习批次展开后的全部事件。成员可能分布在当前月窗之外，解析时要按条目的复习日逐个抓取，不能只看已加载的 42 天窗口。
_Avoid_: 用月窗内事件当全部成员；成员数不足就降级成单次日程
