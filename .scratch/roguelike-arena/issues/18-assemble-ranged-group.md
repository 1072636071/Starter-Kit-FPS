# 18 — 远程组组装（警察 / 律师 / 日本艺妓 / 研究员-老人 / 牛仔 / 独眼牛仔 / 猎人 / 普通黑女）

Status: done
Type: task
Refs: ADR 022, issues 09/12/14/15

## 描述

组装全部 8 个远程组敌人：GLB 导入 + `.tscn` 创建 + 挂已有模块 + `ENEMY_CONFIG` 注册。**不写新模块代码**——所有模块来自 issue 12、14、15。

## 前置依赖

- [x] issue 09（模块钩子）
- [ ] issue 12（PlaceTrap 模块 + Damage 变体）
- [ ] issue 14（SpeedAura + HealAura 模块）
- [ ] issue 15（MultiShot + ChargedShot + DebuffOnHit 模块）

## 验收标准

每敌人独立验收，8 个可完全并行推进。

### 1. 警察（Police）— 参数型，无新模块

- [ ] GLB：`character-j` → `models/monsters/`
- [ ] `.tscn`：`objects/enemy_police.tscn`，远程持枪，无模块
- [ ] `@export`：`health = 100`、`move_speed = 3.5`、`attack_damage = 16`、`attack_cooldown = 1.2`
- [ ] 独有：`awareness_range = 16`、`chase_range = 40`（高于默认值）
- [ ] `ENEMY_CONFIG`：`cost = 6, reward = 6, min_wave = 4`

### 2. 律师（Lawyer）— DebuffOnHit

- [ ] GLB：`character-q` → `models/monsters/`
- [ ] `.tscn`：`objects/enemy_lawyer.tscn`，远程，挂 `module_debuff_on_hit`
- [ ] `@export`：`health = 80`、`move_speed = 2.8`、`attack_damage = 14`、`attack_cooldown = 1.5`
- [ ] `ENEMY_CONFIG`：`cost = 10, reward = 10, min_wave = 4`

### 3. 日本艺妓（Geisha）— SpeedAura

- [ ] GLB：`character-n` → `models/monsters/`
- [ ] `.tscn`：`objects/enemy_geisha.tscn`，远程，挂 `module_speed_aura`
- [ ] `@export`：`health = 85`、`move_speed = 2.5`、`attack_damage = 12`、`attack_cooldown = 2.0`
- [ ] `ENEMY_CONFIG`：`cost = 10, reward = 10, min_wave = 4`

### 4. 研究员-老人（Researcher）— HealAura

- [ ] GLB：`character-i` → `models/monsters/`
- [ ] `.tscn`：`objects/enemy_researcher.tscn`，远程，挂 `module_heal_aura`
- [ ] `@export`：`health = 70`、`move_speed = 2.0`、`attack_damage = 10`、`attack_cooldown = 2.5`
- [ ] `ENEMY_CONFIG`：`cost = 12, reward = 12, min_wave = 4`

### 5. 牛仔（Cowboy）— MultiShot

- [ ] GLB：`character-k` → `models/monsters/`
- [ ] `.tscn`：`objects/enemy_cowboy.tscn`，远程，挂 `module_multishot`
- [ ] `@export`：`health = 90`、`move_speed = 3.0`、`attack_damage = 12`、`attack_cooldown = 2.0`
- [ ] `ENEMY_CONFIG`：`cost = 12, reward = 12, min_wave = 7`

### 6. 独眼牛仔（OneEye）— ChargedShot

- [ ] GLB：`character-p` → `models/monsters/`
- [ ] `.tscn`：`objects/enemy_cowboy_oneeye.tscn`，远程，挂 `module_charged_shot`
- [ ] `@export`：`health = 80`、`move_speed = 2.5`、`attack_damage = 12`（蓄力后 ×3 = 36）、`attack_cooldown = 3.0`
- [ ] `ENEMY_CONFIG`：`cost = 14, reward = 14, min_wave = 7`

### 7. 猎人（Hunter）— PlaceTrap:Damage

- [ ] GLB：`character-m` → `models/monsters/`
- [ ] `.tscn`：`objects/enemy_hunter.tscn`，远程，挂 `module_place_trap_damage`
- [ ] `@export`：`health = 85`、`move_speed = 2.8`、`attack_damage = 15`、`attack_cooldown = 2.2`
- [ ] `ENEMY_CONFIG`：`cost = 14, reward = 14, min_wave = 7`

### 8. 普通黑女（Normal-Female-Black）— 无模块基础远程

- [ ] GLB：`character-f` → `models/monsters/`
- [ ] `.tscn`：`objects/enemy_normal_female_black.tscn`，远程持枪，无模块（纯 `monster_ranged` 模式）
- [ ] `@export`：`health = 60`、`move_speed = 2.8`、`attack_damage = 10`、`attack_cooldown = 1.8`
- [ ] `ENEMY_CONFIG`：`cost = 5, reward = 5, min_wave = 1`

### 测试

- [ ] 每敌人独立测试文件（`tests/test_enemy_<name>.gd`）：
  - 远程射击行为正常（弹体生成、方向正确）
  - 特殊模块触发条件与效果验证
  - 死亡 `died` 信号 + 奖励结算正确
