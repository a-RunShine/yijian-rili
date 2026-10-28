# Wiki 索引

本目录是长期记忆：跨会话保留的决策、踩坑与子系统认知。

**写法约定**：这是历史记录，不描述「现在」。每条涉及代码的断言都带日期与 commit，例如「As of `a-RunShine/yijian-rili@65b89f6`」。事实变化时新增一条带日期的断言并标注旧条目被取代，不改写旧条目。

**下表的一行摘要是「这一页讲什么」，不是当前状态。** 状态在页面里，且带日期。看到摘要与页面正文冲突时，以页面正文为准。

## 条目

### 决策与流程

| 页面 | 摘要 |
|---|---|
| [issue-hygiene.md](issue-hygiene.md) | 发 issue 前必须先查 open issue。2026-10-27 因未查重，同一批 6 条 issue 被创建了两遍 |

### 环境与工具

| 页面 | 摘要 |
|---|---|
| [environment.md](environment.md) | 工具链现状；`git fetch` 超时那次是临时故障；从错误基线建分支会丢未合并提交 |

### 验证与约束

| 页面 | 摘要 |
|---|---|
| [verification.md](verification.md) | 测试与 CI 的演变，以及四个真实 bug 的诊断过程（含「没有栈就不要猜」与反馈循环先行） |
| [data-reliability.md](data-reliability.md) | 「用户数据不可静默丢失」这条主线：缺陷的共同形状、合格写入路径的四条判据、待验证的候选路径 |
| [constraints.md](constraints.md) | AGENTS.md 硬约束的落地状态与机器强制方式 |
| [branch-lineage.md](branch-lineage.md) | 双画布那批残留分支的对照结论与删除记录 |

### 交接

| 页面 | 摘要 |
|---|---|
| [handoff-2026-10-27.md](handoff-2026-10-27.md) | 环境加固的交接（已完成 / 待办 / 未验证） |

## 相关但不在 wiki 的文档

- `AGENTS.md` — agent 操作契约（always-loaded）
- `GLOSSARY.md` — 领域术语
- `docs/agents/` — 发版、CalDAV、issue tracker、triage 标签、Cursor Cloud
- `docs/adr/` — 架构决策
- `openspec/` — spec 与已归档的 change
