# Issue 跟踪器：本地 Markdown

此仓库的 issue 和 PRD 以 markdown 文件形式存放在 `.scratch/` 中。

## 写作目录（Tracker 落在哪里）

**所有 tracker 文件都写在 `.scratch/` 下，绝不在仓库根目录。**

- 每个功能一个目录：`.scratch/<feature-slug>/`
- PRD：`.scratch/<feature-slug>/PRD.md`
- 实现 issue：`.scratch/<feature-slug>/issues/<NN>-<slug>.md`，从 `01` 编号
- 跨功能的索引文件：`.scratch/tickets.md`（仅作索引，不承载实际工单内容）

> **重要：避免使用仓库根的 `tickets.md`。** `jxx-to-tickets` 技能在"本地文件"模式下默认把工单写到仓库根的 `tickets.md`。那是技能的通用默认落点，**不是本仓库的约定**。使用 `/jxx-to-tickets` 时，发布阶段必须写到 `.scratch/<feature-slug>/`（issue 文件或按需的 `tickets.md` 索引），不要写（或保留）根目录的 `tickets.md`。

## 约定

- Triage 状态记录为每个 issue 文件顶部附近的 `Status:` 行（角色字符串见 `triage-labels.md`）
- 评论和对话历史追加到文件底部，在 `## 评论` 标题下

## 当技能说"发布到 issue tracker"时

在 `.scratch/<feature-slug>/` 下创建新文件（如需要则创建目录）。不要写到仓库根目录的 `tickets.md`。

## 当技能说"获取相关工单"时

读取引用路径的文件。用户通常会直接传递路径或 issue 编号。

## Wayfinding 操作

由 `/jxx-wayfinder` 使用。**地图**是一个文件，每个工单有一个**子**文件。

- **地图**：`.scratch/<effort>/map.md` — 笔记/已做决策/迷雾正文。
- **子工单**：`.scratch/<effort>/issues/NN-<slug>.md`，从 `01` 编号，问题在正文中。`Type:` 行记录工单类型（`research`/`prototype`/`grilling`/`task`）；`Status:` 行记录 `claimed`/`resolved`。
- **阻塞**：顶部附近的 `Blocked by: NN, NN` 行。当其列出的所有文件都 `resolved` 时，工单解除阻塞。
- **前沿**：扫描 `.scratch/<effort>/issues/` 中开放、未阻塞、未认领的文件；按编号优先，第一个胜出。
- **认领**：设置 `Status: claimed` 并在任何工作前保存。
- **解决**：在 `## 答案` 标题下追加答案，设置 `Status: resolved`，然后将上下文指针（gist + 链接）追加到 `map.md` 中地图的已做决策中。
