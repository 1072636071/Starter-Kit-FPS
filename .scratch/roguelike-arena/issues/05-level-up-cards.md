# 05 — 升级三选一卡

Status: resolved
Type: task
Refs: PRD.md, ADR 011, ADR 015, CONTEXT.md「Level Up / Upgrade Pool / Upgrade Card / XP / Upgrade Stacking」, Q5, Q10

## 描述

经验跨阈值触发 Level Up：即时暂停，从升级池随机抽 3 不重复增益，玩家选 1 即时生效（本局内永久）。由 `RunDirector`（issue 02）的 `xp_changed` 驱动。

## 验收标准

### 阈值与触发
- 升级阈值随等级递增：第 1 级需 20 XP，之后每级 ×1.3（20→26→34→44…）。
- XP 跨阈值**即时暂停**游戏并弹三选一卡（非延迟到间歇）。
- 一次跨多级（罕见，如奖励 XP 极大）：只弹一次三选一，升 1 级；剩余 XP 留待下次跨阈值再触发（不连弹）。

### 暂停行为（见 ADR 015）
- Level Up UI 根节点 `process_mode = PROCESS_MODE_WHEN_PAUSED`。
- 进入时 `Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)`；选卡后 `MOUSE_MODE_CAPTURED`。
- RunDirector 触发前检查 `get_tree().paused`，若已暂停（如商店中）则延迟到 unpause 后再弹（罕见，记录为已知边界）。

### 抽卡
- 升级池：从定义集合中随机抽 **3 个不重复**项呈现（使用 `run_director.rng`）；池不足 3 时降级（抽全部）。
- "不重复"指**本次三张互不相同**，不跨级记忆——下一级升级仍可抽到上一次选过的项（即可重复选、可叠加）。

### 升级池初版与叠加语义（新增）
- 升级**可重复选、可叠加**（不同级升级可拿同一项）。叠加方式：
  - **加法类**（flat 加值）：`+20 最大血量`、`+5 护盾恢复速率`、`+0.5 移动速度`、`+1 每把枪备弹上限`——线性叠加（拿 3 次 `+20 血` = +60 血）。
  - **乘法类**（百分比）：`+15% 伤害`、`-10% 换弹时间`——**乘法叠加**（拿 3 次 `+15% 伤害` = ×1.15³ ≈ 1.52；拿 3 次 `-10% 换弹` = ×0.9³ ≈ 0.73）。
- **附加效果**：
  - `+20 最大血量`：抬上限 + 同步回 20 血（`health = min(health + 20, max_health)`，让升级即时有用）。
  - `+5 护盾恢复速率`：只加 `shield_regen_rate`，**不**立即回盾（靠后续 regen）。
  - `+0.5 移动速度`：加到玩家移动速度基础值。
  - `+1 每把枪备弹上限`：加 `bonus_max_reserve`（见下），**不**改 Weapon 资源。
  - `+15% 伤害`：乘到玩家伤害乘数 `damage_multiplier`（见下）。
  - `-10% 换弹时间`：乘到玩家换弹时间乘数 `reload_time_multiplier`（见下）。

### Player 升级 bonus 字段（新增，关键架构点）
- **不修改 `Weapon` 资源**（`.tres` 文件全局共享引用，直接改会跨局污染且可能写盘）。改为在 `Player` 上新增运行时 bonus 字段：
  - `@export var max_health: int = 100`（issue 03 已要求新增，此处共用）
  - `var bonus_max_reserve: int = 0`（每把枪有效上限 = `weapon.max_reserve + bonus_max_reserve`）
  - `var damage_multiplier: float = 1.0`（实际伤害 = `weapon.damage * damage_multiplier`）
  - `var reload_time_multiplier: float = 1.0`（实际换弹时间 = `weapon.reload_time * reload_time_multiplier`）
  - `var move_speed_bonus: float = 0.0`（实际移动速度 = `base_move_speed + move_speed_bonus`）
  - `var shield_regen_rate_bonus: float = 0.0`（实际回盾速率 = `shield_regen_rate + shield_regen_rate_bonus`）
- 这些字段是 Player 实例的运行时状态，随场景重置自然清零（配合 issue 06 的 `reload_current_scene()` 重开机制，无需手动 reset）。
- 升级 apply 时：`player.max_health += 20; player.health = min(player.health + 20, player.max_health)` 等。
- 现有射击 / 换弹 / 移动代码需改为读取"有效值"（`weapon.damage * player.damage_multiplier` 等），issue 实施时定位并改这些读取点。

### 选卡与恢复
- 玩家选 1 后 apply 到对应玩家属性，`get_tree().paused = false`，隐藏 UI，恢复鼠标捕获。
- 暴露 `level_up_offered(choices: Array)` 信号（供测试与 HUD）。

### UI 与其它暂停 UI 的关系
- 升级卡选择 UI 与商店 UI（issue 04）、Game Over（issue 06）同为暂停态 UI，但触发来源不同（XP vs walk-in vs 死亡）。

## 评论

- 升级可重复 + 乘法叠加，让后期 build 有指数成长感，配合波次数量递增平衡。
- `bonus_*` 字段方案避免了 Weapon 资源污染，且 `reload_current_scene()` 天然重置——与 issue 06 的重开机制一致。
- 现有代码读取 `weapon.damage` / `weapon.reload_time` / `weapon.max_reserve` 的位置需在实施时 grep 并改为"有效值"读取（射击、换弹、商店上限检查三处至少）。

## 答案

已实现，TDD 测试 [tests/test_level_up.gd](file:///g:/work/Starter-Kit-FPS/tests/test_level_up.gd) 全绿（38 项断言）。

实现要点：
- **Player bonus 字段**（[player.gd:76-83](file:///g:/work/Starter-Kit-FPS/objects/player.gd#L76-L83)）：`bonus_max_reserve=0` / `damage_multiplier=1.0` / `reload_time_multiplier=1.0` / `move_speed_bonus=0.0` / `shield_regen_rate_bonus=0.0`（运行时状态，随 reload_current_scene 重置）。
- **有效值读取点**：
  - 移动速度（[player.gd:302](file:///g:/work/Starter-Kit-FPS/objects/player.gd#L302)）：`movement_speed + move_speed_bonus`
  - 射击伤害（[player.gd:410](file:///g:/work/Starter-Kit-FPS/objects/player.gd#L410)）：`weapon.damage * damage_multiplier`
  - 换弹时间（[player.gd:498-510](file:///g:/work/Starter-Kit-FPS/objects/player.gd#L498-L510)）：`w.reload_time * reload_time_multiplier`（含 tween 与 reload_started 信号）
  - 护盾恢复（[player.gd:661](file:///g:/work/Starter-Kit-FPS/objects/player.gd#L661)）：`shield_regen_rate + shield_regen_rate_bonus`
  - 备弹上限（[player.gd:673-674](file:///g:/work/Starter-Kit-FPS/objects/player.gd#L673-L674)）：`effective_max_reserve(weapon) = weapon.max_reserve + bonus_max_reserve`
- **升级池**（[run_director.gd:67-74](file:///g:/work/Starter-Kit-FPS/scripts/run_director.gd#L67-L74)）：6 项 const，id 为 `&"max_health"` / `&"shield_regen"` / `&"damage"` / `&"move_speed"` / `&"max_reserve"` / `&"reload_time"`。
- **抽卡**（[run_director.gd:143-146](file:///g:/work/Starter-Kit-FPS/scripts/run_director.gd#L143-L146)）：`_pick_upgrades(count)` 用本局 rng 打乱池取前 N，池不足降级。
- **触发流程**（[run_director.gd:119-140](file:///g:/work/Starter-Kit-FPS/scripts/run_director.gd#L119-L140)）：`add_xp` 跨阈值 → `_offer_level_up()` → `get_tree().paused = true` + 抽 3 不重复 + 发 `level_up_offered(choices)`；一次跨多级只弹一次、升 1 级，剩余 XP 留待下次。
- **apply**（[run_director.gd:148-180](file:///g:/work/Starter-Kit-FPS/scripts/run_director.gd#L148-L180)）：`apply_upgrade(id)` 由 UI 调用 → `_apply_upgrade_to_player(id)` 修改 bonus 字段 → 清 pending → `get_tree().paused = false` → 发 `xp_changed`。加法类线性叠加，乘法类乘法叠加（3× +15% 伤害 = ×1.15³）。
- **Level Up UI**（[scripts/level_up.gd](file:///g:/work/Starter-Kit-FPS/scripts/level_up.gd) + [scenes/level_up.tscn](file:///g:/work/Starter-Kit-FPS/scenes/level_up.tscn)）：`Control` 挂 HUD 下，`process_mode = WHEN_PAUSED`；监听 `level_up_offered` 显示 3 卡（名称+描述 Button）；选 1 → `apply_upgrade` → 隐藏 + 恢复鼠标捕获。

测试：`godot --headless res://tests/test_level_up.tscn --quit-after 600` → `[TEST] PASS`（bonus 字段默认值、升级池 6 项、抽 3 不重复、6 项 apply 效果、3× 叠加=×1.15³、add_xp 暂停+恢复、多级跨阈值只弹一次）。

### 已知边界
- 若 add_xp 在已暂停状态（如商店中）触发，当前简单处理仍覆盖暂停并弹升级卡；ADR 015 的"延迟到 unpause 后再弹"作为边界情况记录，v1 不实现。
- test_run_director.gd 的 test 2/5/6 需在 add_xp 触发升级后调 `apply_upgrade` 恢复暂停，否则后续测试受暂停影响。
