# 11 — 召唤模块（SummonPet + CubePet）

Status: ready-for-agent
Type: task
Refs: ADR 022, issue 09

## 描述

实现 SummonPet 模块和 CubePet 子实体。这是第一个"产生新实体"的模块，验证模块系统能否管理跨实体生命周期。**本工单只写模块 + Pet，不创建驯兽师敌人。** 敌人组装见 issue 16。

## 前置依赖

- [x] issue 09（模块钩子）

## 验收标准

### CubePet（独立实体）

- [ ] 从 `kenney_cube-pets_1.0` 挑选 1 种宠物 GLB 导入 `models/monsters/`
- [ ] 新建 `objects/pet_cube.tscn` + `objects/pet_cube.gd`：
  - `extends CharacterBody3D`（**不是** `monster_base` 子类）
  - `@export` 参数：`health = 20`、`move_speed = 4.0`、`damage = 5`、`attack_cooldown = 1.0`
  - 简单 AI：`_physics_process` 内用 `NavigationAgent3D` 追玩家 → 2m 内扣血 → 冷却
  - 被击杀时 `queue_free()`，**不发** `died` 信号（不参与 RunDirector 奖励体系）
  - 碰撞层级同怪物（layer 2），但 mask 只含 layer 1（地形）+ layer 3（玩家攻击）

### SummonPet 模块

- [ ] 新建 `scripts/modules/module_summon_pet.gd`，继承 `EnemyModule`，实现：
  - `module_setup(enemy)` — 加载 pet 场景引用
  - `on_enter_state(AIState.CHASE)` — 检查冷却就绪 → 在宿主周围 2–3m 随机位置 `instantiate(pet_scene)`，记录到 `_active_pets: Array`
  - `on_death()` — 遍历 `_active_pets` 全部 `queue_free()`
- [ ] `@export` 参数：
  - `pet_scene: PackedScene`（默认指向 `pet_cube.tscn`）
  - `pet_count: int = 3`
  - `pet_cooldown: float = 8.0`（冷却中不再召唤）
  - `spawn_radius: float = 3.0`

### 测试

- [ ] `tests/test_module_summon_pet.gd`：
  - 创建临时怪物挂 SummonPet 模块，触发 CHASE
  - 断言 3 只 pet spawned、位置在宿主 2–3m 内
  - 模拟时间推进 5s（冷却内）→ 断言不再重复召唤
  - 调用 `destroy()` → 断言所有 pet `is_queued_for_deletion()`
