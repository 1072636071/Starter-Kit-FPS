# 工单索引（Tracker 根）

本仓库所有 issue / 工单统一存放在 `.scratch/` 下，按功能分目录。本文件是索引，替代原先仓库**根目录**的 `tickets.md`。

> 根目录 `tickets.md` 只是 `jxx-to-tickets` 技能的**默认落点**，并非本仓库约定。详见 `docs/agents/issue-tracker.md`「写作目录」一节。

## 写作目录规则

- 每个功能一个目录：`.scratch/<feature-slug>/`
- PRD：`.scratch/<feature-slug>/PRD.md`
- 实现 issue：`.scratch/<feature-slug>/issues/<NN>-<slug>.md`，从 `01` 编号
- 本 `tickets.md` 仅作索引，实际工单在上面的 `issues/` 目录内

## 功能列表

| 功能 | 目录 |
|------|------|
| 弹药 HUD 系统 | `.scratch/ammo-hud/`（PRD.md + issues/） |
| 城市地图管线 | `.scratch/city-editor/`（issues/） |
| 受击反馈 Hit Flash | `.scratch/hit-feedback/`（issues/） |
| 玩家近战系统 | `.scratch/melee/`（PRD.md + issues/） |
| 近战挥砍过渡动画 | `.scratch/melee-transitions/`（issue.md，单 issue；ADR 019 为设计依据） |
| 小地图系统 | `.scratch/minimap/`（issues/，无 PRD；ADR 007 为设计依据） |
| 竞技场可玩性修复 | `.scratch/arena-fixes/`（PRD.md + issues/） |
| 护盾 HUD 信息展示 | `.scratch/shield-hud/`（PRD.md） |
| 敌人跳跃导航系统 | `.scratch/enemy-jump-navigation/`（PRD.md；ADR 021 为设计依据） |
| Roguelike 竞技场系统 | `.scratch/roguelike-arena/`（PRD.md + 27 issues；ADR 009–022） |
| 按键说明面板（Controls Help） | `.scratch/controls-help/`（PRD.md；ADR 024 为设计依据） |
| UI 现代化设计系统 | `.scratch/ui-modernization/`（PRD.md + 7 issues；ADR 027 为设计依据） |
| 操作手感现代化 | `.scratch/gamefeel-modernization/`（SPEC.md + PRD.md + 11 issues；ADR 028/029 为设计依据） |

按**前沿**推进：任何阻塞者全部完成的工单。Triage 标签见 `docs/agents/triage-labels.md`。
