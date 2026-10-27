# 分支谱系

## 2026-10-27：10 条残留分支与 master 的关系

本地与远程各 10 条分支，代码都已 squash 合入 `master`，但分支本身未删。`gh api repos/a-RunShine/yijian-rili/pulls?state=open` → **零个 open PR**，全部已合并。

| 分支 | 状态 |
|---|---|
| `cursor/issue-47-dual-canvas-followups-9115` | 11 提交未入 master 历史，行为已由 `#47`/`#53`、`#54`/`#58`、`#59`/`#60` 三次 squash 覆盖 |
| `cursor/issue-47-ticket-48..52-9115`（5 条） | 逐条 squash 进 `f152a24` |
| `cursor/issue-54-canvas-clicks-9115` | squash 进 `7f8d9f1` |
| `cursor/issue-59-scrollable-day-list` | squash 进 `65b89f6` |
| `feature/dual-canvas-calendar` | 已由 PR `#46` 合入 |
| `wip/issue-47-salvage-uncommitted` | 单提交 `e8f0217` 保全，内容已被上述覆盖 |

merge-base 是 `c87406d`（PR `#46` 的 merge commit）。master 侧从它往后只有 3 个提交：

```
65b89f6 fix: 宽画布右侧日程列表恢复滚动并限制高度 (#59) (#60)
7f8d9f1 双画布跟进：单击跟手、侧栏编辑热区与删除 (#54) (#58)
f152a24 双画布跟进：拖拽、完成跳过、翻页基准日、切换占位、回到今天 (#47) (#53)
```

## 已 spot-check 的三处行为等价

| 行为 | master 对应实现 |
|---|---|
| 同窗改基准日不重查 | `ReviewViewModel.reselectWithinVisibleMonth`，`selectDay` 里按 `monthStart(for:) == visibleMonth` 分流 |
| 宽栏日程可滚动 | `MonthAgenda` 的 `ScrollView` + `.frame(maxHeight: 220)` |
| 完成/跳过可点 | `MonthAgenda` 中 `statusButton` 三处调用 |

注意方向：`git diff master HEAD` 里的 `D`（`MonthCellClickRecord.swift`、`PointingHandOnHover.swift`、`SearchHitDeleteFlow.swift`）表示**只有 master 有**，当前分支从来不曾拥有——这是 master 侧的新重构，不是当前分支的删除。

## 尚未完成：完整行为对照

**只 spot-check 了 3 处，没有做完整的「当前分支 5 个提交 vs master 3 个 squash」逐行为对照。**

待对照的 5 个提交：

- `5c339dc` 同窗改基准日不重查，翻页只换显示月并保留基准日
- `9161034` 月历拖拽跟手改基准日（`#49`）
- `5e82a31` 宽画布完成与跳过点击可达现有复习完成态
- `93b0b5c` 月格下方固定预留溢出说明占位，切换模式时不再挤动月格
- `feab70b` 恢复宽栏日程滚动并去掉周末卡抢优先，完成跳过仍可点中

**对照未完成前不得删除任何分支。** 用户已拍板：先做完整对照再删。

跟踪：issue `#72`

## 删除方式

本机 `git push --delete` 不可用（见 [environment.md](environment.md)），须用：

```bash
gh api --method DELETE repos/a-RunShine/yijian-rili/git/refs/heads/<branch>
```
