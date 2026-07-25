# 09 — 敌人模块系统 + 数据驱动架构（P0 重构）

Status: planning
Type: task
Refs: ADR 022, CONTEXT.md「EnemyModule / 模块钩子 / ENEMY_CONFIG」

## 描述

这是敌人角色化的**基础设施工单**。在 `monster_base.gd` 中植入模块钩子系统，将 `RunDirector` 的敌人配置从硬编码改为数据驱动。本工单不实现任何具体模块或敌人，只为后续 16 个角色工单铺路。

## 验收标准

### 模块钩子（monster_base.gd）

- [ ] 新增 `_modules: Array[Node]`，`_ready()` 末尾调用 `_collect_modules()` 收集子节点中实现了 `module_setup` 的节点
- [ ] `_collect_modules()` 对每个模块调用 `module_setup(self)` 传递宿主引用
- [ ] `_change_state(new_state)` 末尾调用 `_run_module_hook("on_enter_state", [new_state])`
- [ ] `_tick_state(delta)` 末尾（各 match 分支后）调用 `_run_module_hook("on_tick", [delta])`
- [ ] `damage(amount)` 中（减血前）调用 `_run_module_hook("on_damage", [amount])`
- [ ] `destroy()` 中（`_dead = true` 后、`died.emit` 前）调用 `_run_module_hook("on_death", [])`
- [ ] `_run_module_hook` 用 `has_method` 检测，安全的空模块不报错

### 数据驱动 RunDirector（run_director.gd）

- [ ] 新增 `ENEMY_CONFIG: Dictionary` 常量字典，包含 16 个条目的 `cost` / `reward` / `min_wave` / `scene`
- [ ] `_available_types(wave)` 改为遍历 `ENEMY_CONFIG` 过滤 `min_wave <= wave`
- [ ] `_reward_for(type)` 改为 `ENEMY_CONFIG[type]["reward"]`
- [ ] `_spawn_monster` 改为 `ENEMY_CONFIG[type]["scene"]` 取场景
- [ ] `MONSTER_COST` / 旧的 `_monster_scenes` 引用移除
- [ ] 旧 3 种怪物类型（`monster_melee`/`monster_ranged`/`enemy`）的 `@export` 场景字段和预加载保留但改为通过 ENEMY_CONFIG 间接引用（过渡兼容）

### Weapon Resource 扩展（weapon.gd）

- [ ] 新增 `@export var ammo_type: StringName = &"手枪弹"`
- [ ] 新增 `@export var weapon_cost: int = 30`
- [ ] 新增 `@export var durability_max: int = 150`
- [ ] 旧 `gold_cost_per_bullet` 保留字段但标记 `@deprecated`，不再被任何逻辑使用

### 弹药池重构（player.gd）

- [ ] `ammo_reserve: Array[int]` 改为 `ammo_reserve: Dictionary[StringName, int]`
- [ ] 初始化时 `ammo_reserve["手枪弹"] = 36`
- [ ] 所有引用 `reserve[i]` 的地方改为 `ammo_reserve[weapons[current_index].ammo_type]`
- [ ] `effective_max_reserve(weapon)` 签名不变，但换弹从 `ammo_reserve[type]` 取
- [ ] `weapons` 数组最大长度限制为 3（assign 时截断或拒绝）

### 耐久度追踪（player.gd）

- [ ] 新增 `weapon_durability: Array[int]`（与 `weapons` 数组一一对应），初始值为对应武器的 `durability_max`
- [ ] `_physics_process` 开火逻辑中：每次扣扳机 `weapon_durability[current_index] -= 1`
- [ ] 耐久归零时自动触发 `_on_weapon_broken(index)`：
  - 播放火花/碎片粒子特效（`GPUParticles3D` 一次性爆发，0.3s）
  - 从 `weapons` + `weapon_durability` 数组中移除该枪
  - 若还有剩余的枪 → 自动切到第一个可用槽；若全无 → 空手状态
- [ ] 换枪/装新枪时耐久数组同步更新
- [ ] **允许同枪重复持有**：`weapons` 数组不检查重复，同一 `Weapon` 资源可出现在多个槽位

### 键位调整（project.godot）

- [ ] `struggle` 动作键从 G（physical_keycode=71）改为 H（physical_keycode=72）
- [ ] 新增 `throw_grenade` 动作，绑定 G（physical_keycode=71）
- [ ] 新增 `drop_weapon` 动作，绑定 X（physical_keycode=88）

### 测试

- [ ] `tests/test_module_hooks.gd`：创建一个带假模块的怪物，断言 4 个钩子被正确调用和时机
- [ ] `tests/test_enemy_config.gd`：断言 `_available_types(3)` 只返回 min_wave ≤ 3 的敌人、`_reward_for` 返回正确值
