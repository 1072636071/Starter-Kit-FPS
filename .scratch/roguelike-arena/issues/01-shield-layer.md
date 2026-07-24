# 01 — 护盾吸收层 + 延时自动恢复

Status: resolved
Type: task
Refs: PRD.md, ADR 010, ADR 015, CONTEXT.md「Shield / Health」

## 描述

修改 `Player` 的伤害管线，引入护盾作为血量前的可再生吸收层。当前 `player.gd` 的 `damage(amount)` 直接扣 `health` 且无护盾；本 issue 将其改为先减 `shield`、溢出再减 `health`，并加入护盾延时自动恢复。

## 验收标准

- `Player` 新增 `shield`、`shield_max = 50`、`shield_regen_delay = 3.0`、`shield_regen_rate = 10.0`（均 `@export`）。
- `damage(amount: float)`：先减 `shield`，仅当 `shield` 不足以覆盖时才溢出扣 `health`；护盾可为 0 不致死。
- 最后一次受击后启动 `shield_regen_delay` 倒计时；到点每帧按 `shield_regen_rate` 回盾（不超过 `shield_max`）；再次受击重置倒计时（战斗中亦可恢复）。
- 死亡判定改为 `health <= 0`（**注意**：现 [player.gd:588](file:///g:/work/Starter-Kit-FPS/objects/player.gd#L588-L589) 是 `health < 0`，须改为 `<= 0`，否则 0 血不死）。
- 死亡分支**不再直接 `reload_current_scene()`**——改为发射 `died` 信号（或调用 RunDirector 钩子），由 issue 06 的 Game Over 流程接管。本 issue 只负责"不发 reload、改发信号"，Game Over UI 由 issue 06 实现。
- 新增 `shield_updated` 信号（参数含当前 shield / shield_max），供 HUD（issue 07）绘制护盾条。
- 新增 `died` 信号（无参数），在 `health <= 0` 时发射一次（带 `_dead` 守卫防重复）。
- 护盾初值满（`shield = shield_max`）。
- 护盾 regen 在暂停期间冻结（Player 为 `PROCESS_MODE_PAUSABLE`，见 ADR 015）。

## 答案

已实现于 [player.gd](file:///g:/work/Starter-Kit-FPS/objects/player.gd)，TDD 测试 [test_arena_shield.gd](file:///g:/work/Starter-Kit-FPS/tests/test_arena_shield.gd) 全绿。

实现要点：
- `@export` 字段：`max_health=100` / `shield_max=50` / `shield_regen_delay=3.0` / `shield_regen_rate=10.0`（[player.gd:11-19](file:///g:/work/Starter-Kit-FPS/objects/player.gd#L11-L19)）。
- 护盾状态：`shield: float` / `_shield_regen_timer: float` / `_dead: bool`（[player.gd:68-74](file:///g:/work/Starter-Kit-FPS/objects/player.gd#L68-L74)）。
- `damage(amount: float)`（[player.gd:621-638](file:///g:/work/Starter-Kit-FPS/objects/player.gd#L621-L638)）：先减 `shield`，溢出才减 `health`（int 取整）；重置 `_shield_regen_timer`；`health <= 0` 发 `died` 信号（`_dead` 守卫防重复）；不再裸 `reload_current_scene()`，由 issue 06 接管。
- `_step_shield_regen(delta)`（[player.gd:642-651](file:///g:/work/Starter-Kit-FPS/objects/player.gd#L642-L651)）：`_process` 中调用，过 delay 后每帧按 rate 回盾；Player 为 `PROCESS_MODE_PAUSABLE`，暂停期间自然冻结（符合 ADR 015）。
- `heal(amount: int)`（[player.gd:654-658](file:///g:/work/Starter-Kit-FPS/objects/player.gd#L654-L658)）：加血不超过 `max_health`，不影响护盾，`_dead` 时 no-op（供 issue 03 血包调用）。
- 信号：`shield_updated(shield, shield_max)`、`died`、`health_updated`（[player.gd:91-95](file:///g:/work/Starter-Kit-FPS/objects/player.gd#L91-L95)）。
- 护盾初值满（`_ready` 中 `shield = shield_max`）。
- 顺带修复 `change_weapon()` 中 `crosshair` 可能为 null 的崩溃（加防御，[player.gd:468-469](file:///g:/work/Starter-Kit-FPS/objects/player.gd#L468-L469)）。

测试：`godot --headless res://tests/test_arena_shield.tscn --quit-after 600` → `[TEST] PASS`（24 项断言全过）。

## 评论

（无）
