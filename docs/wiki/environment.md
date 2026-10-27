# 开发环境

## 2026-10-27：`git fetch` 到 github.com 超时，远程查询须走 `gh api`

在本机（macOS，仓库 `/Users/sunshine/workspace/projects/yijian-rili`）实测：

```
$ git fetch -q origin
fatal: unable to access 'https://github.com/a-RunShine/yijian-rili.git/':
       Failed to connect to github.com port 443 after 75010 ms

$ gh api repos/a-RunShine/yijian-rili/branches --jq '.[].name'
# 正常返回 10 条分支名
```

`git` 与 `gh` 走不同链路，所以：

- **远程状态查询用 `gh api`**，不要用 `git fetch` + `git rev-list`
- 本地 `origin/master` 是**旧引用**，基于它的 `git rev-list --left-right --count origin/master...master` 结果不可信
- 删除远程分支用 `gh api --method DELETE`，不要用 `git push --delete`

这是**本机环境事实**，不是仓库契约。未换机器复验前不写进 `AGENTS.md`。

跟踪：issue `#71`

## 2026-10-27：本机工具链现状

| 工具 | 状态 |
|---|---|
| `swift` | 6.4（swiftlang-6.4.0.34.1），arm64-apple-macosx27.0.0 |
| `dotnet` | **未安装**，故 Windows 领域测试只能靠 CI |
| `swiftlint` / `swiftformat` | **未安装**，仓库也未配置 |
| `gh` | 可用，认证正常 |
| `git fetch` / `git push` 到 github.com | **不可用**（见上） |

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
