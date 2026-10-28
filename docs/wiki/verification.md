# 验证

## 2026-10-27：测试基线

As of `a-RunShine/yijian-rili@65b89f6`（master）：

```
$ make test
Executed 182 tests, with 0 failures (0 unexpected) in 0.404 seconds
```

- 测试文件 13 个，位于 `Tests/一键日历Tests/`
- Swift 6.4，`swiftLanguageModes: [.v6]`
- 另有一组 swift-testing 输出 `0 tests in 0 suites`（未使用该框架）

规模较大的几个：`一键日历Tests.swift`、`InMemoryCalendarServiceTests.swift`、`ReviewBoardTests.swift`、`ReviewSessionTests.swift`。

## 2026-10-27：macOS 主工程没有 CI

`.github/workflows/` 下**只有** `windows-ci.yml`，且只对 `windows/**` 路径触发。macOS 侧（SwiftUI + EventKit，主工程）零自动化验证。

对照：Windows 移植有 `domain-tests`（ubuntu-latest）与 `windows-build`（windows-latest）双 job。主平台反而没有。

**已在 `chore/enforce-constraints` 分支修复**（PR `#73`，未合入 master）：新增 `.github/workflows/macos-ci.yml`，`build-and-test` 在 `macos-15` 上跑 `swift build` + `swift test`，`lint` 在 `ubuntu-latest` 上跑 `make lint`。

### runner 镜像踩过的坑

第一次选了 `macos-14`，理由是「钉住 `Package.swift` 声明的 `.macOS(.v14)` 下限，能最早暴露 API 可用性问题」。CI 在 10 秒就失败：

```
error: 'yijian-rili': package 'yijian-rili' is using Swift tools version
6.0.0 but the installed version is 5.10.0
```

`macos-14` 镜像默认 Xcode 15.4 → Swift 5.10，而 `Package.swift` 要求 `swift-tools-version: 6.0`。那个前提是错的：下限镜像连编译都启动不了。

改用 `macos-15`，并在 `swift build` 前显式选镜像上最新的 Xcode——`macos-15` 同时装了 16.x 到 26.x 多个版本，默认是 16.4：

```bash
LATEST=$(ls -d /Applications/Xcode_*.app 2>/dev/null | sort -V | tail -1)
sudo xcode-select -s "$LATEST/Contents/Developer"
```

**这个错误在本地永远发现不了**——本地是 Swift 6.4。这正是加 CI 的第一份收益。

### 等待时间

macOS runner 可能排队很久（2026-10-27 有一次 15 分钟仍无 runner 分配，`runner_name` 为空即尚未分到机器）。等待时不要因为慢就判定失败，先看 `runner_name`：为空是排队，有值才是真在跑。

跟踪：issue `#67`

## 验证手段的边界

- `swift test` 覆盖领域逻辑，**不覆盖** SwiftUI 手势、布局与 EventKit 真实读写
- 涉及滚动、点击可达、窗口布局的改动必须用 `make open` 人工确认（`docs/agents/release.md` 记录 `make run` 会故意失败，因裸 `swift run` 没有 app bundle 上下文，`Info.plist` 的日历权限与 `LSUIElement` 不生效）
- EventKit 相关改动无法在 CI 中验证，只能靠 in-memory seam 的测试 + 人工

## 2026-10-27：加 CI 立刻抓出一个既有测试缺陷

CI 第一次真正跑起来（Swift 6.2.4 / macOS 15 SDK）时，`build-and-test` 在 `testChoosingHistoryAlignsTheBoardToThatEntryBaseDate` 上以 `signal code 6`（SIGABRT）退出。本地 Swift 6.4 下 202 个测试全绿，同一个测试单独跑也绿。

定位过程与结论：

- 日志时间戳需排序后再看。GitHub 把并行 suite 的输出交错排列，直接搜 `unexpected signal` 会误判崩溃点。按时间戳取「有 started 无 passed」的测试才准确。
- 本地 `swift test --parallel` 能复现成**断言失败**而不是崩溃：`members.count` 期望 3 得到 1，`旧详情` 泄漏进下一个测试。
- 根因：`ReviewViewModel.init` 硬编码 `HistoryStore()` / `WeeklyReviewViewModel()` / `OccurrenceStatusStore()`，三者都默认 `.standard`；`ReviewViewModel` 还有 4 个 `@AppStorage` 与 2 处直读 `.standard`。于是每个测试都在同一个全局域里读写 history、occurrence 状态、周末总结、间隔预设。
- 兄弟类型**已经有** `init(defaults: UserDefaults = .standard)` 这个 seam，只是 `ReviewViewModel` 绕过了它。

`swift test --parallel` 三次结果是 `4 / 4 / 0` 个错误——不是稳定复现，而是取决于执行顺序，这正好符合共享状态污染的签名。

**这是既有缺陷，不是加 CI 引入的**。此前没有任何自动化跑过这套测试，所以它一直没被发现。这正是加 CI 的第一份真实收益：不是防止未来出错，是让一直存在的错误可见。

已在 issue `#74` 立项。修复应该给 `ReviewViewModel` 补上同形状的 `defaults` 注入点，而不是在测试里用 `removePersistentDomain` 清全局域——那样只是把顺序依赖藏得更深。

一个方法论上的提醒：**不要用 CI 当调试循环**。macOS runner 排队可能十几分钟，而本地 `swift test --parallel` 一秒就能暴露同一个根因。先在本地复现，再让 CI 确认。

## 2026-10-28：那个 SIGABRT 的真正根因（不是测试污染）

前一轮把它归因为「测试通过 `UserDefaults.standard` 互相污染」。**这个归因是错的**，或者说不完整：污染是真问题（已修，见下），但不是崩溃的原因。

真正的崩溃栈（`SWIFT_BACKTRACE=enable=yes,threads=all`）：

```
Thread 0 crashed:
  __pthread_kill + 8                              libsystem_kernel.dylib
  swift_task_deinitOnExecutorMainActorBackDeploy  + 456
  ReviewViewModel.__deallocating_deinit           + 124   ReviewViewModel.swift
  ReviewBoardTests.testChoosing...()              + 3176  ReviewBoardTests.swift:248
```

崩溃在**对象释放**时，所有断言都通过了。`@MainActor deinit` 在 Swift 6.2 上需要跳回 MainActor executor 才能析构；XCTest 在非 MainActor 线程释放被测对象，就触发 runtime 断言。Swift 6.4 修掉了这个行为，**所以本地永远复现不出来**——这是「本地全绿、CI 崩溃」的结构性原因，不是环境配置差异。

修法：`deinit` 改 `nonisolated`（里面只做 `NotificationCenter.removeObserver`，本身线程安全，不需要 MainActor），token 标 `nonisolated(unsafe)`。

### 教训：没有栈就不要猜

这轮在拿到栈之前，连续归因过三次，全是错的：

1. 「CI 缺用户偏好域」→ 用干净 HOME 本地跑，202 通过，推翻
2. 「测试并行顺序撞上共享状态」→ 修完后 CI 照旧崩在同一测试
3. 「macOS runner 容量不足」→ 是用户手动取消的

`swift test` 只报退出码，崩溃细节不在 stdout。**第一步就该开 `SWIFT_BACKTRACE`**，而不是从退出码反推。Swift 运行时自带这个开关，零成本。

另外一条：`swift runtime: backtrace-on-crash is not supported for privileged executables.` 这句仍会打印，但栈已经有了——不要被它误导以为没抓到。

### 顺带修掉的真问题

测试隔离确实有缺陷（`ReviewSession` / `ReviewViewModel` 硬编码 `UserDefaults.standard`），已补 `defaults` 注入并清理了全部全局清场。这部分**不是崩溃的成因**，但它让 `swift test --parallel` 从 49/37/60 个错误降到稳定 0，值得单独保留。

判断某次修复是否真的解决了问题时，要问：**修复后 CI 的那个具体测试还崩吗？** 而不是「本地测试变绿了」。前者是证据，后者只是必要条件。

## 2026-10-28：无权限对账会永久删除历史 id

用户报：每次 `make open` / `make install` 之后，之前的复习系列丧失编辑能力，点「完成」「跳过」提示「这条日程缺少系列记录」。

**现象与数据的差距**是这次的关键：用户说「记录都没了」，但实机 plist 里 `historyEntriesData` 有 8 条记录、1781 字符——记录还在，只是每条 `createdEventIdentifiers` 都是 `[]`。日历里的事件也还在。丢的是**关联**，不是内容。

根因链条：

```
ReviewViewModel.init
  pullBrowseState() → rebuildSearchHits() → reconcileRecordedWithCalendar()
      ← 此时授权尚未就绪
      calendar.event(withId:) 无权限，对每个 id 静默返回 nil
      对账把 nil 读作「事件已被删除」
      removeEventsFromRecorded 把这些 id 从 historyEntriesData 永久写回
  if authorizationStatus == .fullAccess { … }   ← 权限检查在这里才到
```

### 为什么只在重装后复发

`make bundle` 会重新 `codesign`。重签名后首次启动 EventKit 授权需要重建，于是又撞进那个窗口。日常反复启动同一个已签名的 app 不触发。

### 为什么测试全绿却没抓到

`InMemoryCalendarService` 默认 `grantAccessByDefault: true`，测试永远走不到无权限分支。而且它的 `event(withId:)` 不看权限——即使把 status 设成 `notDetermined`，事件照样查得到，于是「无权限」测试是**假绿**。必须同时让查询不可读（fake 的 `eventsUnreadable`）才真正进入回归路径。

### 教训

**「查不到」不等于「不存在」。** 这是本次 bug 的全部。任何把「查询返回空」当作删除证据的逻辑，都要先问：这次查询本身可信吗？

修复把这条约束放进了类型：`CalendarLookupAuthority` 私有 init、只能由 full access 构造，所以 `.calendarConfirmedMissing` 这个修剪理由在无授权时**根本写不出来**。比在调用点加 `if authorizationStatus == .fullAccess` 更可靠——后者要靠每个新增调用点记得写。

### 一个操作层面的教训

本轮两次用 `git checkout -- <file>` 想撤销一次临时实验，结果把**未提交的整文件改动**一并丢掉，每次都要从备份恢复。临时验证防护是否生效时，用 `cp file /tmp/x.bak` 备份后改、验完 `cp` 回来，**不要用 `git checkout`**——它回滚到最近一次 commit，不是回滚到「我刚才改动之前」。
