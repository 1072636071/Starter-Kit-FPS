# 17 — 近战组组装（健壮男 / 机器人-男电 / 机器人-女心 / 游戏宅 / 普通女）

Status: done
Type: task
Refs: ADR 022, issues 09/13/14

## 描述

组装全部 5 个近战组敌人：GLB 导入 + `.tscn` 创建 + 挂已有模块 + `ENEMY_CONFIG` 注册。**不写新模块代码**——所有模块来自 issue 13 和 14。

## 前置依赖

- [x] issue 09（模块钩子）
- [ ] issue 13（BerserkOnDamage + Shield + SelfDestruct + ExplodeOnDeath 模块）
- [ ] issue 14（DebuffAura 模块）

## 验收标准

每敌人独立验收，可并行推进。

### 1. 健壮男（Brawny）— BerserkOnDamage

- [ ] GLB：`character-b` → `models/monsters/`
- [ ] `.tscn`：`objects/enemy_brawny.tscn`，近战，挂 `module_berserk_on_damage`
- [ ] `@export`：`health = 180`、`move_speed = 2.5`、`attack_damage = 20`、`attack_cooldown = 1.5`
- [ ] `ENEMY_CONFIG`：`cost = 16, reward = 16, min_wave = 10`

### 2. 机器人-男电（Robot-Male）— Shield + EMPBurst

- [ ] GLB：`character-g` → `models/monsters/`
- [ ] `.tscn`：`objects/enemy_robot_male.tscn`，近战，挂 `module_shield` + `module_emp_burst`
- [ ] 新建 `scripts/modules/module_emp_burst.gd`（小模块，本工单内完成）：监听 Shield 的 `shield_broken` → 对 8m 内玩家减速（移速 ×0.5，持续 2s）
- [ ] `@export`：`health = 100`、`move_speed = 3.0`、`attack_damage = 18`
- [ ] `ENEMY_CONFIG`：`cost = 18, reward = 18, min_wave = 10`

### 3. 机器人-女心（Robot-Female）— SelfDestruct + ExplodeOnDeath

- [ ] GLB：`character-h` → `models/monsters/`
- [ ] `.tscn`：`objects/enemy_robot_female.tscn`，近战，挂 `module_self_destruct` + `module_explode_on_death`
- [ ] `@export`：`health = 80`、`move_speed = 4.0`、`attack_damage = 12`
- [ ] `ENEMY_CONFIG`：`cost = 20, reward = 20, min_wave = 10`

### 4. 游戏宅（Nerd）— DebuffAura

- [ ] GLB：`character-c` → `models/monsters/`
- [ ] `.tscn`：`objects/enemy_nerd.tscn`，近战，挂 `module_debuff_aura`
- [ ] `@export`：`health = 85`、`move_speed = 3.0`、`attack_damage = 14`
- [ ] `ENEMY_CONFIG`：`cost = 8, reward = 8, min_wave = 1`

### 5. 普通女（Normal-Female）— 无模块基础近战

- [ ] GLB：`character-e` → `models/monsters/`
- [ ] `.tscn`：`objects/enemy_normal_female.tscn`，近战，无模块（纯 `monster_base` + 近战 FSM，空手）
- [ ] `@export`：`health = 60`、`move_speed = 3.0`、`attack_damage = 10`、`attack_cooldown = 1.5`
- [ ] `ENEMY_CONFIG`：`cost = 5, reward = 5, min_wave = 1`

### 测试

- [ ] `tests/test_enemy_brawny.gd`：受击后触发狂暴 → 断言伤害/移速提升
- [ ] `tests/test_enemy_robot_male.gd`：攻击破盾 → 断言 EMP 减速生效
- [ ] `tests/test_enemy_robot_female.gd`：接近 3m → 断言 0.8s 后爆炸；击杀 → 断言死亡爆炸
- [ ] `tests/test_enemy_nerd.gd`：接近 5m → 断言玩家减速 + 攻速降低
- [ ] `tests/test_enemy_normal_female.gd`：基础近战行为正常、死亡掉 5 金币/5 XP
