# Wiki 索引

本目录是长期记忆：跨会话保留的决策、踩坑与子系统认知。

**写法约定**：这是历史记录，不描述「现在」。每条涉及代码的断言都带日期与 commit，例如「As of `a-RunShine/yijian-rili@65b89f6`」。事实变化时新增一条带日期的断言并标注旧条目被取代，不改写旧条目。

## 条目

### 决策与流程

| 页面 | 摘要 |
|---|---|
| [issue-hygiene.md](issue-hygiene.md) | 发 issue 前必须先查 open issue；2026-10-27 因未查重而重复创建了整套 6 条 |

### 环境与工具

| 页面 | 摘要 |
|---|---|
| [environment.md](environment.md) | 工具链现状（无 dotnet / 无 SwiftLint）；`git fetch` 曾超时但当晚恢复，勿据旧结论绕道 |

### 验证与约束

| 页面 | 摘要 |
|---|---|
| [verification.md](verification.md) | `make test` 182 测试全绿；macOS 主工程此前无 CI |
| [constraints.md](constraints.md) | AGENTS.md 的「禁注释」硬约束现状：Sources 零违规，Tests/windows 共 218 处 |
| [branch-lineage.md](branch-lineage.md) | 10 条残留分支与 master 的关系；完整行为对照尚未完成，不得删除 |

### 交接

| 页面 | 摘要 |
|---|---|
| [handoff-2026-10-27.md](handoff-2026-10-27.md) | 环境加固的交接：已完成项、唯一红灯（#74）、明天从哪开始 |

## 相关但不在 wiki 的文档

- `AGENTS.md` — agent 操作契约（always-loaded）
- `GLOSSARY.md` — 领域术语
- `docs/agents/` — 发版、CalDAV、issue tracker、triage 标签
- `openspec/` — spec 与 change
