# 14 — 远程组（警察 / 律师 / 日本艺妓 / 研究员-老人 / 牛仔 / 独眼牛仔 / 猎人 / 普通黑女）

Status: planning
Type: task-group
Refs: ADR 022, issue 09

## 描述

实现全部 8 个远程组角色敌人。每角色一张子工单。

## 前置依赖

- [ ] issue 09（模块钩子）
- [ ] issue 10–12（锚点）建议先完成

---

## 子工单 14.1：警察（参数型，无新模块）

- 导入 `character-j（警察）.glb` → `objects/enemy_police.tscn`
- 纯参数区别：`awareness_range = 16`（默认远程 12）、`chase_range = 40`（默认 25）、`move_speed = 3.5`
- 远程持枪（复用 `monster_ranged` 武器挂载模式）
- `@export`：`health = 100`、`attack_damage = 16`、`attack_cooldown = 1.2`
- `ENEMY_CONFIG`：cost=6, reward=6, min_wave=4

## 子工单 14.2：律师（DebuffOnHit）

- 新建 `scripts/modules/module_debuff_on_hit.gd`：
  - 在敌人开火发射弹体时，给弹体附加一个 flag
  - 弹体命中玩家后：玩家 `damage_multiplier *= 0.7`，持续 `debuff_duration = 2.0s`
  - 实现方式：模块在 `on_enter_state(ATTACK)` 时覆盖开火逻辑，用 `_fire_debuff_projectile()` 代替默认
- 导入 `character-q（律师）.glb` → `objects/enemy_lawyer.tscn`
- `@export`：`health = 80`、`move_speed = 2.8`、`attack_damage = 14`、`attack_cooldown = 1.5`
- `ENEMY_CONFIG`：cost=10, reward=10, min_wave=4

## 子工单 14.3：日本艺妓（SpeedAura）

- 新建 `scripts/modules/module_speed_aura.gd`：
  - `on_tick` 检测 `aura_radius = 10.0m` 内所有友方敌怪 → 移速 ×1.2
  - 通过 `get_tree().get_nodes_in_group("enemy")` 或 `monsters_parent.get_children()` 遍历
  - 模块自己维护一个 buff 列表，离开范围时恢复速度
- 导入 `character-n（日本艺妓）.glb` → `objects/enemy_geisha.tscn`
- `@export`：`health = 85`、`move_speed = 2.5`、远程射击伤害 12、`attack_cooldown = 2.0`
- `ENEMY_CONFIG`：cost=10, reward=10, min_wave=4

## 子工单 14.4：研究员-老人（HealAura）

- 新建 `scripts/modules/module_heal_aura.gd`：
  - `on_tick` 检测 `aura_radius = 8.0m` 内友方敌怪 → `heal_per_second = 3` HP/s
  - 不回超过敌人自身 `max_health`（需敌人有 `max_health` 字段或在模块中缓存初始值）
- 导入 `character-i（研究员-老人）.glb` → `objects/enemy_researcher.tscn`
- `@export`：`health = 70`、`move_speed = 2.0`（慢）、远程射击伤害 10、`attack_cooldown = 2.5`
- `ENEMY_CONFIG`：cost=12, reward=12, min_wave=4

## 子工单 14.5：牛仔（MultiShot）

- 新建 `scripts/modules/module_multishot.gd`：
  - `on_enter_state(ATTACK)` 时：连续发射 `burst_count = 4` 发（间隔 `burst_interval = 0.15s`）
  - 每次发射走正常的 `_fire_projectile()` 路径，散布中等（3.0）
- 导入 `character-k（牛仔）.glb` → `objects/enemy_cowboy.tscn`
- `@export`：`health = 90`、`move_speed = 3.0`、远程射击伤害 12（单发）×4、`attack_cooldown = 2.0`
- `ENEMY_CONFIG`：cost=12, reward=12, min_wave=7

## 子工单 14.6：独眼牛仔（ChargedShot）

- 新建 `scripts/modules/module_charged_shot.gd`：
  - `on_enter_state(ATTACK)` 时：站定蓄力 `charge_time = 1.2s`（播放蓄力动画/特效）→ 一发高伤弹体
  - 蓄力期间不移除 RVO（仍可能被推），但 `_desired_velocity = Vector3.ZERO`
  - 蓄力完成发射：`charged_damage_multiplier = 3.0`（即单发 36）
- 导入 `character-p（独眼牛仔）.glb` → `objects/enemy_cowboy_oneeye.tscn`
- `@export`：`health = 80`、`move_speed = 2.5`、远程射击伤害 12×3、`attack_cooldown = 3.0`
- `ENEMY_CONFIG`：cost=14, reward=14, min_wave=7

## 子工单 14.7：猎人（PlaceTrap:Damage）

- 复用 `scripts/modules/module_place_trap_damage.gd`（与化学人的 PlaceTrap 共享基类设计）
- `on_tick` 在 CHASE 路径上每 `place_cooldown = 6.0s` 放置一个伤害陷阱
- 陷阱：`Area3D`，玩家踩中立刻爆炸 `explosion_damage = 40`、`explosion_radius = 2.5m`
- 最多 `max_traps = 3` 个在场
- 导入 `character-m（猎人）.glb` → `objects/enemy_hunter.tscn`
- `@export`：`health = 85`、`move_speed = 2.8`、远程射击伤害 15、`attack_cooldown = 2.2`
- `ENEMY_CONFIG`：cost=14, reward=14, min_wave=7

## 子工单 14.8：普通黑女（无模块基础远程）

- 导入 `character-f（普通黑女）.glb` → `objects/enemy_normal_female_black.tscn`
- 无模块，纯远程 FSM（同现有 `monster_ranged`）
- `@export`：`health = 60`、`move_speed = 2.8`、`attack_damage = 10`、`attack_cooldown = 1.8`
- `ENEMY_CONFIG`：cost=5, reward=5, min_wave=1

---

## 测试（每子工单独立）

每子工单创建 `tests/test_enemy_<name>.gd`，断言：
- 敌人正确生成、远程射击行为正常
- 特殊模块触发条件与效果
- 死亡清理
