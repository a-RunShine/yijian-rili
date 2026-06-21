# UX 优化计划

共 12 项，分 3 批执行。

## 第一批：高价值（用户最可感知）

| # | 优化点 | 改动文件 | 方案 | 验证 |
|---|---|---|---|---|
| 1 | 结果提示自动消失 | ReviewViewModel | 成功/警告 3-5s 后自动清空 resultMessage | 提示淡出消失 |
| 2 | 标题输入自动聚焦 | TitleInputSection + ReviewViewModel | @FocusState 启动聚焦 | 打开即可输入 |
| 3 | 窗口激活刷新日程 | 一键日历App + ReviewViewModel | 监听 applicationDidBecomeActive 重新 loadTodayEvents | 切回应用日程更新 |
| 4 | 间隔设置可折叠 | IntervalSettingsSection | DisclosureGroup 默认收起 | 收起释放空间 |
| 5 | 预设按钮选中状态 | IntervalSettingsSection | 当前间隔匹配预设时高亮 | 视觉反馈选中 |

## 第二批：中价值（体验打磨）

| # | 优化点 | 改动文件 | 方案 | 验证 |
|---|---|---|---|---|
| 6 | 历史记录显示复习摘要 | HistorySection | 加一行「N 个复习」摘要 | 能看到复习数量 |
| 7 | 标题字符计数 | TitleInputSection | 80+ 字符时显示 X/100 | 接近上限有提示 |
| 8 | 今日日程日历颜色标识 | TodayEventsSection | 事件左侧加小圆点 event.calendar.color | 多日历可区分 |
| 9 | 搜索框清除按钮 | HistorySection | 搜索框末尾加 x 清除 | 一键清除搜索 |

## 第三批：低价值（锦上添花）

| # | 优化点 | 改动文件 | 方案 | 验证 |
|---|---|---|---|---|
| 10 | 过去日期提示 | ReviewPreviewSection | 日期早于今天时显示提示文字 | 选过去日期有提醒 |
| 11 | 撤销提示含标题 | ReviewViewModel + Localizable | 撤销消息加标题 | 撤销时知道撤了什么 |
| 12 | 全天事件视觉区分 | TodayEventsSection | 全天事件加背景色或图标 | 全天/时间事件可区分 |

## 执行顺序

1. 第一批 5 项 → swift build + test → make install
2. 第二批 4 项 → swift build + test → make install
3. 第三批 3 项 → swift build + test → make install
4. commit

## 涉及文件汇总

- ReviewViewModel.swift（#1, #2, #3, #11）
- TitleInputSection.swift（#2, #7）
- 一键日历App.swift（#3）
- IntervalSettingsSection.swift（#4, #5）
- HistorySection.swift（#6, #9）
- TodayEventsSection.swift（#8, #12）
- ReviewPreviewSection.swift（#10）
- Localizable.strings（#11）
