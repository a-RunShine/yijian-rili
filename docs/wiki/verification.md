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
