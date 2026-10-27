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

**已在 `Chore/enforce-constraints` 分支修复**（未合入 master）：新增 `.github/workflows/macos-ci.yml`，`build-and-test` 在 `macos-14` 上跑 `swift build` + `swift test`，`lint` 在 `ubuntu-latest` 上跑 `make lint`。钉 `macos-14` 而非 `latest`，因为 `Package.swift` 声明 `.macOS(.v14)`。

跟踪：issue `#67`

## 验证手段的边界

- `swift test` 覆盖领域逻辑，**不覆盖** SwiftUI 手势、布局与 EventKit 真实读写
- 涉及滚动、点击可达、窗口布局的改动必须用 `make open` 人工确认（`docs/agents/release.md` 记录 `make run` 会故意失败，因裸 `swift run` 没有 app bundle 上下文，`Info.plist` 的日历权限与 `LSUIElement` 不生效）
- EventKit 相关改动无法在 CI 中验证，只能靠 in-memory seam 的测试 + 人工
