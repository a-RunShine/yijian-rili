# 开发环境

## 2026-10-27 晚：`git fetch` 恢复正常（取代下方 22:15 的断言）

同一天晚间复测，`git fetch origin` 与 `git push` 均**正常成功**：

```
$ git fetch origin          # exit 0
$ git push -u origin chore/enforce-constraints
 * [new branch]  chore/enforce-constraints -> chore/enforce-constraints
$ git rev-list --left-right --count origin/master...master
0	0
```

**结论修正**：22:15 观察到的超时是**临时网络故障**，不是稳定特征。下方那段记录保留作历史，但不要再据此认为 `git fetch` 不可用。

仍然成立的教训：**当 `git fetch` 失败时，`gh api` 通常还能用**，因为两者走不同链路。这个降级路径值得记住，但不应升级成常规做法。

tracking issue `#71` 可以关闭——问题已不复现。

## 2026-10-27 22:15：`git fetch` 到 github.com 超时（已失效）

在本机（macOS，仓库 `/Users/sunshine/workspace/projects/yijian-rili`）实测：

```
$ git fetch -q origin
fatal: unable to access 'https://github.com/a-RunShine/yijian-rili.git/':
       Failed to connect to github.com port 443 after 75010 ms
```

当时的判断：远程状态查询用 `gh api`，删除远程分支用 `gh api --method DELETE`。

这条判断在同一天晚间已被上面的复测取代。`gh api --method DELETE` 这个写法本身仍然可用，只是不再是唯一选择。

## 2026-10-27：本机工具链现状

| 工具 | 状态 |
|---|---|
| `swift` | 6.4（swiftlang-6.4.0.34.1），arm64-apple-macosx27.0.0 |
| `dotnet` | **未安装**，故 Windows 领域测试只能靠 CI |
| `swiftlint` / `swiftformat` | **未安装**，仓库也未配置 |
| `gh` | 可用，认证正常 |
| `git fetch` / `git push` 到 github.com | 晚间复测**可用**（见上文修正） |

`make test` 在 macOS 上可用（需 `import SwiftUI`/`EventKit`，Cloud Linux 跑不了）。

## 2026-10-27：工作区与 HEAD 可能不同步

一次 `git checkout master` 之后 `git log` 显示 HEAD 已在 `master`（`65b89f6`），但 `git status` 显示 13 个文件仍是旧分支内容——那次 checkout 只挪了 HEAD 没更新工作区。

判断工作区到底等于哪个提交：

```bash
GIT_INDEX_FILE=/tmp/tmpidx git read-tree HEAD
GIT_INDEX_FILE=/tmp/tmpidx git add -A
GIT_INDEX_FILE=/tmp/tmpidx git write-tree
```

拿到的 tree hash 与 `git rev-parse <commit>^{tree}` 比对。当时工作区 tree 等于 `feab70b`，确认是旧分支内容，随后用 `git restore --source=HEAD --staged --worktree .` 恢复。

**教训**：看到「HEAD 在 master 但文件对不上」时不要猜，用 tree hash 比对定位，再决定 `restore` 还是 `stash`。
