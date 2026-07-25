# 13 — 近战组（健壮男 / 机器人-男电 / 机器人-女心 / 游戏宅 / 普通女）

Status: planning
Type: task-group
Refs: ADR 022, issue 09

## 描述

实现全部 5 个近战组角色敌人，每个敌人一张子工单。建议按编号顺序做（先简单后复杂）。

## 前置依赖

- [ ] issue 09（模块钩子）
- [ ] issue 10–12（锚点 3 人）——建议至少锚点完成再做，确保模块模式已验证

---

## 子工单 13.1：健壮男（BerserkOnDamage）

- 新建 `scripts/modules/module_berserk_on_damage.gd`
- `on_damage` 触发狂暴计时器（3s 持续时间）：`damage_multiplier = 1.5`、`move_speed_multiplier = 1.3`
- 狂暴期间可见红色 glow（emission 材质切换或 modulate）
- 3s 后恢复，冷却 `berserk_cooldown = 8.0s`
- 导入 `character-b（健壮男）.glb` → `objects/enemy_brawny.tscn`
- `@export`：`health = 180`、`move_speed = 2.5`、`attack_damage = 20`、`attack_cooldown = 1.5`
- `ENEMY_CONFIG`：cost=16, reward=16, min_wave=10

## 子工单 13.2：机器人-男电（Shield + EMPBurst）

- 新建 `scripts/modules/module_shield.gd`：
  - `shield_max = 60`（`@export`）、`shield_current` 初始满
  - `on_damage(amount)`：先扣盾，盾破时触发 `shield_broken` 信号
- 新建 `scripts/modules/module_emp_burst.gd`：
  - 监听 Shield 的 `shield_broken` → 对玩家施加 2s 减速（移速 ×0.5）
  - EMP 范围 `emp_radius = 8.0m`
- 导入 `character-g（机器人-男电）.glb` → `objects/enemy_robot_male.tscn`
- `@export`：`health = 100`、`move_speed = 3.0`、`attack_damage = 18`
- `ENEMY_CONFIG`：cost=18, reward=18, min_wave=10

## 子工单 13.3：机器人-女心（SelfDestruct + ExplodeOnDeath）

- 新建 `scripts/modules/module_self_destruct.gd`：
  - `on_tick` 检测到玩家距离 < `detonate_range = 3.0m` 时：0.8s 蜂鸣闪烁前摇 → 爆炸
  - 爆炸：`explosion_radius = 5.0m`，`explosion_damage = 60`，AOE
  - 爆炸后敌人死亡（调用 `destroy()`）
- 新建 `scripts/modules/module_explode_on_death.gd`：
  - `on_death` 时爆炸 AOE（`radius = 4.0m`，`damage = 40`）
  - 若已被 SelfDestruct 杀死则不重复爆
- 导入 `character-h（机器人-女心）.glb` → `objects/enemy_robot_female.tscn`
- `@export`：`health = 80`、`move_speed = 4.0`（冲得快）、`attack_damage = 12`
- `ENEMY_CONFIG`：cost=20, reward=20, min_wave=10

## 子工单 13.4：游戏宅（DebuffAura）

- 新建 `scripts/modules/module_debuff_aura.gd`：
  - `on_tick` 检测 `aura_radius = 5.0m` 内玩家 → 施加减速（移速 ×0.7）+ 攻速降低（射速 ×0.8）
  - 离开范围立即恢复
- 导入 `character-c（游戏宅）.glb` → `objects/enemy_nerd.tscn`
- `@export`：`health = 85`、`move_speed = 3.0`、`attack_damage = 14`
- `ENEMY_CONFIG`：cost=8, reward=8, min_wave=1

## 子工单 13.5：普通女（无模块基础近战）

- 导入 `character-e（普通女）.glb` → `objects/enemy_normal_female.tscn`
- 无模块，纯 `monster_base` + 近战 FSM（同现有 `monster_melee` 但不挂武器模型、空手）
- `@export`：`health = 60`、`move_speed = 3.0`、`attack_damage = 10`、`attack_cooldown = 1.5`
- `ENEMY_CONFIG`：cost=5, reward=5, min_wave=1

---

## 测试（每子工单独立）

每子工单创建 `tests/test_enemy_<name>.gd`，断言：
- 敌人正确生成并进入 CHASE
- 特殊模块触发条件与效果（狂暴/护盾/自爆/光环）
- 死亡清理
