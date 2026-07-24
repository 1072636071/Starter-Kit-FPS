# 05 — 升级三选一卡

Status: ready-for-agent
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
