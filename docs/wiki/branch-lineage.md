# 分支谱系

## 2026-10-27：10 条残留分支已删除（对照完成）

本地与远程曾有 10 条分支，代码都已 squash 合入 `master`，但分支本身一直没删。2026-10-27 完成逐提交对照后删除。

删除前建了审计 tag：`archive/dual-canvas-followups-2026-10-27` → `feab70b`。原始提交仍可通过该 tag 找回。

对照基线：`cursor/issue-47-dual-canvas-followups-9115`（HEAD `feab70b`）↔ `master`（`65b89f6`），共同祖先 `c87406d`。

## 对照结论

| 提交 | 主题 | 判定 |
|---|---|---|
| `5c339dc` | 同窗改基准日不重查、翻页只换显示月 | 完全覆盖，master 更完整（`reselectWithinVisibleMonth` + `loadVisibleWindowIfNeeded`） |
| `9161034` | 月历拖拽跟手改基准日（#49） | 完全覆盖，`CalendarShellView.monthDrag` / `day(at:)` 逐字相同 |
| `5e82a31` | 宽画布完成/跳过可点 | 净效果覆盖。`.borderless` + `contentShape` 保留；去 ScrollView 的做法已被 `feab70b` 回滚；`layoutPriority` 已移除 |
| `93b0b5c` | 月格下方固定占位 | 完全覆盖，`MonthPreviewOverflowLine` 逐字相同 |
| `feab70b` | 恢复宽栏滚动、去 layoutPriority | 完全覆盖，`dayListMaxHeight = 220` + `ScrollView` |

### 三处独立复验（不只依赖子代理报告）

| 断言 | 复验命令 | 结果 |
|---|---|---|
| master 无 `layoutPriority` 残留 | `git grep -c layoutPriority master -- Sources` | 零命中 |
| 分支不新增任何文件 | `git diff --diff-filter=A --name-only master <branch>` | 空 |
| 分支测试是 master 的子集 | 三份测试文件比对 `func test*` 名称 | 全为子集（ReviewBoardTests 13 vs 18） |

`cursor/issue-59-scrollable-day-list` 与 master 的 diff 为空（完全一致）；`cursor/issue-47-ticket-52-9115` 的 HEAD 是空提交；`feature/dual-canvas-calendar` 的 ahead 计数为 0。

### 方向性提醒

`git diff master HEAD` 里的 `D`（`MonthCellClickRecord.swift`、`PointingHandOnHover.swift`、`SearchHitDeleteFlow.swift`、`MonthCellClickRecordTests.swift`）表示**只有 master 有**——这是 master 把内联逻辑抽成独立 seam 的重构，不是分支的删除。这个方向极易看反。

## 未验证

- 只做了源码与测试文本层面的等价确认，**未**编译运行验证渲染与点击命中（当时只读分析，未执行构建）
- `layoutPriority` 移除后在极小窗口下的布局压缩表现、`ScrollView` 内点击的手势优先级，属运行时行为，未实测

## 删除方式

当时本机 `git push --delete` 不可用，改用：

```bash
gh api --method DELETE repos/a-RunShine/yijian-rili/git/refs/heads/<branch>
```

`gh api` 这条路当晚生效，且不依赖 git 的网络栈。同日晚间 `git fetch`/`git push` 也恢复了（见 [environment.md](environment.md)）——所以两种方式都可用，`gh api` 作为降级路径保留。

`wip/issue-47-salvage-uncommitted` 从未推到远程，远程删除返回 `422 Reference does not exist`——这是正常结果，不是失败。

删除后远程只剩 `master`，本地只剩 `master` 与当时的工作分支。

跟踪：issue `#72`
