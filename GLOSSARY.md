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
