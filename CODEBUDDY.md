# AGENTS.md

工程技能（Matt Pocock 风格）的配置与约定。

## Agent skills

### Issue tracker

Issue 以 markdown 文件存放在仓库的 `.scratch/<feature>/` 下；不使用任何外部 PR 作为 triage 渠道。参见 `docs/agents/issue-tracker.md`。

### triage 标签

五个标准 triage 角色直接使用同名标签字符串（`needs-triage`、`needs-info`、`ready-for-agent`、`ready-for-human`、`wontfix`）。参见 `docs/agents/triage-labels.md`。

### 领域文档

单一上下文：根目录 `CONTEXT.md` + `docs/adr/`；这些文件若缺失，技能将静默继续。参见 `docs/agents/domain.md`。
