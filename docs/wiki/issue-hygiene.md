# Issue 卫生

## 2026-10-27：发 issue 前必须先查 open issue

在一次会话里，agent 准备发 6 条加固 issue 时**没有先列出已开 issue**，直接批量创建，得到 `#67`–`#72`。

事后发现同一天 11:20 已有另一次同名会话建过内容几乎逐字相同的 `#61`–`#66`。仓库里因此出现 6 对重复 issue。

**处置**：用户拍板保留本轮 `#67`–`#72`，把 `#61`–`#66` 以 `not planned` 关闭，并在每条上写明对应关系。

### 教训

`docs/agents/issue-tracker.md` 里已经写了「List issues」的命令，但在「create an issue」之前没有人强制先跑一次。发 issue 属于**写外部状态**，和改代码一样需要先取证。

发之前的检查顺序：

1. `gh issue list --state open --json number,title` ——看是否已有同主题
2. 若有，改为在该 issue 下评论补证据，而不是新建
3. 确实需要新建时，在正文里用 `Refs #<n>` 指向相关旧条目

### 相关的另一个问题

同一次会话的 checkpoint 声称「`docs/wiki/` 五个页面已建」「两个子代理在后台并行」，但 2026-10-27 22:15 实测：

- `ls docs/wiki` → 无此目录
- 全盘 `find` 无相关目录
- `git log --all -- docs/wiki` → 零结果
- 没有 `chore/enforce-constraints` 分支
- `git log --since=2026-10-27` → 无任何新提交

**声称完成 ≠ 完成。** 目标计划里标 `completed` 的条目必须以磁盘上的可验证证据为凭，否则就是在给下一次会话留陷阱。本页的存在本身就是这条教训的产物：第一次说建了 wiki，文件并不存在。

## 引用

- 重复 issue：`#61`–`#66`（已关）→ `#67`–`#72`
- 发 issue 的命令规范：`docs/agents/issue-tracker.md`
