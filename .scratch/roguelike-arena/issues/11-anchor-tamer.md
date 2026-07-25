# 11 — 锚点敌人：驯兽师（SummonPet 模块）

Status: planning
Type: task
Refs: ADR 022, issue 09

## 描述

实现第二个锚点敌人「驯兽师」及其 SummonPet 模块。驯兽师定位为**远程召唤型**：进 CHASE 状态时召唤 2–3 只 cube-pet 围攻玩家。验证模块系统的"产生新实体"能力。

## 前置依赖

- [ ] issue 09（模块钩子）完成
- [ ] issue 10（忍者）**不强制**——本工单可与 10 并行，但至少 issue 09 钩子就绪

## 验收标准

### SummonPet 模块

- [ ] 新建 `scripts/modules/module_summon_pet.gd`
- [ ] `on_enter_state(AIState.CHASE)` 时：在敌人周围 2–3m 半径随机位置实例化 `pet_count`（`@export int = 3`）只 cube-pet
- [ ] 每只 pet 冷却 `pet_cooldown`（`@export float = 8.0`）秒后才能再召；驯兽师死亡时场上 pets 一起销毁
- [ ] cube-pet 复用简单 AI（追玩家 → 近身 → 咬，伤害低、血量低、无模块）

### Cube-Pet 规格

- [ ] 从 `kenney_cube-pets_1.0` 中挑选 1–2 种可爱小动物 GLB 导入 `models/monsters/`
- [ ] 新建 `objects/pet_cube.gd` + `objects/pet_cube.tscn`：`extends CharacterBody3D`（**不是 monster_base 子类**，不参与模块系统）
- [ ] 简单 AI：`_physics_process` 内朝玩家走 → 2m 内咬（`damage = 5`）→ 冷却 1s
- [ ] `health = 20`、`move_speed = 4.0`、使用 NavigationAgent3D 导航
- [ ] 被击杀时不掉金币/经验、不触发血包（不是 RunDirector 管理的敌种）
- [ ] 驯兽师死亡 → 所有其召唤的 pets `queue_free()`

### 驯兽师敌人配置

- [ ] 导入 `character-a（驯兽师）.glb` 到 `models/monsters/`
- [ ] 创建 `objects/enemy_tamer.tscn`：远程型，`SummonPet` 模块为子节点
- [ ] `@export` 参数：`health = 100`（中）、`move_speed = 2.5`（慢，他靠宠物）、远程射击伤害 15、攻击冷却 2.5s
- [ ] 模型挂远程武器（复用 `blaster.glb`，同现有 `monster_ranged` 模式）
- [ ] `ENEMY_CONFIG` 添加：cost=22, reward=22, min_wave=13

### 测试

- [ ] `tests/test_enemy_tamer.gd`：
  - 验证进 CHASE 后 3 只 pet 在范围内生成
  - 验证冷却内不重复召唤
  - 验证驯兽师死亡 → pets 消失
