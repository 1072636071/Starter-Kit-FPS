# 01 — 全敌人警戒范围翻倍

Status: resolved
Type: task
Refs: PRD.md, ADR 017, CONTEXT.md「Chain Aggro」

## 描述

将所有敌人的感知参数全局翻倍——被动感知范围、追踪范围、警觉传播半径。玩家进入竞技场后，敌人从更远距离发现玩家、追踪更远、声音传播更广，显著提升战斗密度。

## 验收标准

### 怪物基类默认值

- `monster_base.gd` 的 `@export` 默认值：
  - `awareness_range`: 8.0 → 16.0
  - `chase_range`: 25.0 → 50.0
  - `DEATH_ALERT_RADIUS`: 20.0 → 40.0

### 远程怪开枪 alert

- `monster_ranged.gd` 的 `SHOOT_ALERT_RADIUS`: 25.0 → 50.0

### 飞行怪追踪范围

- `enemy.gd` 的 `@export chase_range`: 35.0 → 70.0

### 玩家开枪 alert

- `player.gd` 中玩家开枪时调用 `AlertSystem.emit_alert()` 的半径参数: 30.0 → 60.0

### 验证

- 现有 `tests/test_smoke_enemies.tscn` 和 `tests/test_smoke_waves.tscn` 场景正常运行
- 怪物在更大的范围内对玩家产生反应（被动感知 + alert 传播）

## 评论

**实现完成（2026-07-25）。**

所有感知参数已按验收标准翻倍，且为保持「全局翻倍」语义一致，对 `monster_melee.gd` / `monster_ranged.gd` 中覆盖 `chase_range` / `awareness_range` 的子类初值也一并翻倍（否则这些子类不会真正获得加倍效果）：

- `objects/monster_base.gd`：`awareness_range` 8→16、`chase_range` 25→50、`DEATH_ALERT_RADIUS` 20→40
- `objects/monster_melee.gd`：`chase_range` 25→50、`awareness_range` 8→16
- `objects/monster_ranged.gd`：`SHOOT_ALERT_RADIUS` 25→50、`chase_range` 30→60、`awareness_range` 12→24
- `objects/enemy.gd`：`chase_range` 35→70
- `objects/player.gd`：`SHOOT_ALERT_RADIUS` 30→60

`tests/test_chain_aggro.gd` 中硬编码旧值的断言（T9a / T9b / T8）已同步更新为翻倍后数值，相关注释一并修正。

**验证：** `test_chain_aggro`（T1–T10 全 ok，PASS）、`test_smoke_enemies`、`test_smoke_waves`、`test_enemy_ai`、`test_enemy_config`、`test_monster_died_signal`、`test_monster_fall_death` 均无头运行 EXIT=0，无 SCRIPT ERROR。
