# 06 — 游戏结束界面

Status: ready-for-agent
Type: task
Refs: PRD.md, ADR 014, ADR 015, CONTEXT.md「Game Over / Arena Run / Pause Semantics」

## 描述

玩家 `health <= 0` 时本局结束：冻结游戏 → 显示结算界面（存活波数 / 击杀数 / 累计金币 / 达到等级）→ 提供"重开一局"。取代 `player.gd` 现有的 `reload_current_scene()` **裸**重置（即"无界面、无反馈"地直接 reload）——本 issue 改为"先显示 Game Over 界面，玩家点重开后再 reload"。

## 验收标准

### 死亡触发与冻结
- `Player.health <= 0` 时（issue 01 已改为 `<= 0` 并发 `died` 信号），RunDirector 收到 `player.died` 信号 → `get_tree().paused = true` → 显示 Game Over UI。
- Game Over UI 根节点 `process_mode = PROCESS_MODE_WHEN_PAUSED`（暂停期间可点按钮）。
- 进入时 `Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)`。

### 结算界面内容
- 显示本局 run stats（由 RunDirector 的 `game_over(stats: Dictionary)` 信号传出）：
  - 存活波数（`wave`，当前达到的波号）
  - 击杀数（`kills`）
  - **累计金币**（`gold_earned_total`，本局总赚取，**非**当前余额——花掉的也算，反映本局收益总量）
  - 达到等级（`level`）
- 可选：显示"当前余额"作为辅助信息（`gold`），但主指标是总赚取。

### 重开机制（明确）
- "重开一局"按钮点击 → `get_tree().paused = false` → `get_tree().reload_current_scene()`。
- **`reload_current_scene()` 就是重置机制**——场景重载会天然还原：Player 的 health/shield/弹药/bonus 字段、RunDirector 的 gold/xp/level/wave/kills、场上所有怪物与血包、武器升级。无需 RunDirector 提供 `reset_run()` 手动还原。
- "取代裸 reload"的语义是"取代**无界面的** reload"，而非禁用 reload 本身。ADR 014 的措辞与本 issue 一致。
- 明确**不做**跨局元进度（meta-progression）——重开即全新本局，上一局战绩不保留。

### Game Over UI 实现
- 新建 `scenes/game_over.tscn`（根 `Control`）+ `scripts/game_over.gd`，挂到 `HUD` 下或 `Main` 下作为暂停态 UI。
- 监听 `RunDirector.game_over(stats)` 填充战绩文本。
- "重开一局"按钮 `pressed` 信号 → 调用上述重开流程。

### 暂停互斥
- 死亡时若已在其它暂停（shop/level-up）中，RunDirector 直接接管：强制 `get_tree().paused = true`（已是 true）、隐藏其它暂停 UI（shop/level-up `visible = false`）、显示 Game Over UI。死亡优先级最高。

## 评论

- "累计金币 = 总赚取"让玩家即使把钱花光也能看到本局收益，反馈更正面。
- `reload_current_scene()` 是最可靠的"全状态重置"——手动 reset 容易漏字段（尤其 issue 05 的 bonus_*）。ADR 014 的"取代 reload"应理解为"取代无界面的 reload 体验"，而非技术禁用 reload。
- 若未来要做 meta-progression，需在 reload 前先把要保留的 stats 存到 autoload，再 reload——本 issue 不实现。
