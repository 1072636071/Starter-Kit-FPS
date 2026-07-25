# 16 — 锚点敌人组装（忍者 + 驯兽师 + 化学人）

Status: ready-for-agent
Type: task
Refs: ADR 022, issues 09/10/11/12

## 描述

组装前三个锚点敌人——导入 GLB、创建 `.tscn` 挂模块、注册 `ENEMY_CONFIG`。这是模块系统的端到端验证：**只做 GLB 导入 + 模块挂载 + 配置录入，不做新模块**。

## 前置依赖

- [x] issue 09（模块钩子）
- [ ] issue 10（Stealth + Dash 模块）
- [ ] issue 11（SummonPet 模块 + CubePet）
- [ ] issue 12（PlaceTrap 模块 + Poison 变体）

## 验收标准

### 忍者（Ninja）

- [ ] 导入 `character-r（忍者）.glb` → `models/monsters/`
- [ ] 创建 `objects/enemy_ninja.tscn`：
  - 根节点 `monster_base`，类型为近战（`monster_melee` 模式）
  - 子节点挂 `module_stealth` + `module_dash`
  - 武器：空手或剑（同现有 `monster_melee` 模式）
  - `@export`：`health = 70`、`move_speed = 5.0`、`attack_damage = 15`、`attack_cooldown = 2.0`、`jump_height = 5.0`
- [ ] `ENEMY_CONFIG` 添加：`cost = 25, reward = 25, min_wave = 13, scene = "res://objects/enemy_ninja.tscn"`

### 驯兽师（Tamer）

- [ ] 导入 `character-a（驯兽师）.glb` → `models/monsters/`
- [ ] 创建 `objects/enemy_tamer.tscn`：
  - 根节点 `monster_base`，类型为远程（挂 `blaster.glb` 武器，同 `monster_ranged`）
  - 子节点挂 `module_summon_pet`（`pet_scene` 指向 `pet_cube.tscn`）
  - `@export`：`health = 100`、`move_speed = 2.5`、`attack_damage = 15`、`attack_cooldown = 2.5`
- [ ] `ENEMY_CONFIG` 添加：`cost = 22, reward = 22, min_wave = 13`

### 化学人（Chemist）

- [ ] 导入 `character-d（化学人）.glb` → `models/monsters/`
- [ ] 创建 `objects/enemy_chemist.tscn`：
  - 根节点 `monster_base`，远程型，挂 `module_place_trap_poison`
  - `@export`：`health = 90`、`move_speed = 2.8`、`attack_damage = 18`、`attack_cooldown = 1.8`
- [ ] `ENEMY_CONFIG` 添加：`cost = 15, reward = 15, min_wave = 7`

### 测试

- [ ] `tests/test_enemy_anchor_trio.gd`：分别 spawn 三种锚点敌人 → 断言各自：
  - 忍者进 ATTACK 后隐身 + 瞬步到玩家旁
  - 驯兽师进 CHASE 后召唤 3 只 pet
  - 化学人 5s 后放置毒陷阱
  - 全部死亡后 `died` 信号正确携带 monster_type
