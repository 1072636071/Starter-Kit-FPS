# 09 — 敌人模块系统 + 数据驱动架构（P0 重构）

Status: review
Type: task
Refs: ADR 022, CONTEXT.md「EnemyModule / 模块钩子 / ENEMY_CONFIG」

## 描述

这是敌人角色化的**基础设施工单**。在 `monster_base.gd` 中植入模块钩子系统，将 `RunDirector` 的敌人配置从硬编码改为数据驱动。本工单不实现任何具体模块或敌人，只为后续 16 个角色工单铺路。

## 验收标准

### 模块钩子（monster_base.gd）

- [x] 新增 `_modules: Array[Node]`，`_ready()` 末尾调用 `_collect_modules()` 收集子节点中实现了 `module_setup` 的节点
- [x] `_collect_modules()` 对每个模块调用 `module_setup(self)` 传递宿主引用
- [x] `_change_state(new_state)` 末尾调用 `_run_module_hook("on_enter_state", [new_state])`
- [x] `_physics_process` 每帧调用 `_run_module_hook("on_tick", [delta])`（置于缓降分支前，缓降期也 tick；比"_tick_state 末尾"更早，保证模块在 dropping 阶段同样生效）
- [x] `damage(amount)` 中（减血前）调用 `_run_module_hook("on_damage", [amount])`（另按 ADR 022 同时回调 `on_exit_state`）
- [x] `destroy()` 中（`_dead = true` 后、`died.emit` 前）调用 `_run_module_hook("on_death", [])`
- [x] `_run_module_hook` 用 `has_method` 检测，安全的空模块不报错

### 数据驱动 RunDirector（run_director.gd）

- [x] 新增 `ENEMY_CONFIG: Dictionary` 常量字典（`cost` / `reward` / `min_wave` / `scene`；初始仅 3 种，issue 10–14 追加其余 13 种，本票不预填）
- [x] `_available_types(wave)` 改为遍历 `ENEMY_CONFIG` 过滤 `min_wave <= wave`（1–3 仅近战、4–6 加远程、7+ 全类型，行为与旧规则一致）
- [x] `_reward_for(type)` 改为 `ENEMY_CONFIG[type]["reward"]`
- [x] `_spawn_monster` 场景解析顺序：@export 注入 → `ENEMY_CONFIG[type]["scene"]`
- [x] `MONSTER_COST` / `REWARD_*` 常量移除；`_monster_scenes` 保留为 @export 注入层（test_run_director 依赖其注入假场景，见下行）
- [x] 旧 3 种怪物类型的 `@export` 场景字段和预加载保留（过渡兼容 + 测试注入），正式刷怪以 ENEMY_CONFIG 为准

### Weapon Resource 扩展（weapon.gd）

- [x] `@export var ammo_type: StringName`（issue 17 已预置，本票确认；两把现有武器均为 `能量电池`）
- [x] `@export var weapon_cost: int`（同上，已预置）
- [x] `@export var durability_max: int`（同上，已预置）
- [x] 旧 `gold_cost_per_bullet` 保留字段但标记 DEPRECATED，全仓库已无逻辑引用（商店改用 `shop_ui.AMMO_COST_PER_TYPE`）

### 弹药池重构（player.gd）

- [x] `reserve: Array[int]` 改为 `ammo_reserve: Dictionary`（键 StringName 弹药类型，值备弹数）
- [x] 初始化时按已装备武器 ammo_type 建键，保底含 `ammo_reserve[&"手枪弹"] = 36`（每类初始 36 发）
- [x] 所有引用 `reserve[i]` 的地方改为弹药池访问（`get_reserve`/`add_reserve`/`get_reserves_snapshot`；`ammo_updated` 信号签名不变）
- [x] `effective_max_reserve(weapon)` 签名不变，换弹从 `ammo_reserve[ammo_type]` 取
- [x] `weapons` 数组最大长度限制为 3（setter 截断，`MAX_WEAPONS = 3`）

### 耐久度追踪（player.gd）

- [x] 新增 `weapon_durability: Array[int]`（与 `weapons` 数组一一对应），初始值为对应武器的 `durability_max`
- [x] 击发逻辑（`action_shoot` 成功击发点）中：每次 `weapon_durability[weapon_index] -= 1`（`durability_max <= 0` 无限耐久跳过）
- [x] 耐久归零时自动触发 `_on_weapon_broken(index)`：
  - 播放碎片粒子特效（`GPUParticles3D` 一次性爆发，lifetime 0.3s）
  - 从 `weapons` + `weapon_durability` + `magazine` 数组中移除该枪
  - 若还有剩余的枪 → 自动切到下一把；若全无 → 空手状态（`weapon=null, weapon_index=-1`，射击/切枪/换弹均加守卫）
- [x] 换枪/装新枪时耐久数组同步更新（_ready 初始化 + _on_weapon_broken 同步移除）
- [x] **允许同枪重复持有**：`weapons` 数组不检查重复，同一 `Weapon` 资源可出现在多个槽位

### 键位调整（project.godot）

- [x] `struggle` 动作键从 G（physical_keycode=71）改为 H（physical_keycode=72）
- [x] 新增 `throw_grenade` 动作，绑定 G（physical_keycode=71）
- [x] 新增 `drop_weapon` 动作，绑定 X（physical_keycode=88）

### 测试

- [x] `tests/test_module_hooks.gd`：假模块断言 6 个钩子的调用与时机（含同状态不重复触发、死后不再回调、空模块跳过）
- [x] `tests/test_enemy_config.gd`：断言表结构/数值、`_available_types` 按 min_wave 解锁、wave1 全近战×12、`_reward_for` 正确值、场景可实例化

## 完成摘要（2026-07-25）

**实现：** monster_base 模块钩子（`_collect_modules` + `_run_module_hook`）；run_director `ENEMY_CONFIG` 数据驱动（3 条目：melee 5/5/1、ranged 8/8/4、enemy 10/10/7）；weapon.gd `gold_cost_per_bullet` 标记 DEPRECATED（其余 3 字段 issue 17 已预置）；player.gd 弹药池（保底 `手枪弹`=36，每类初始 36）+ 耐久追踪 + 武器损毁（0.3s 粒子 → 移除 → 自动切换/空手）+ weapons 上限 3；project.godot 键位（struggle→H、throw_grenade→G、drop_weapon→X）。

**范围扩展（弹药池重构连带，已同步更新）：** `scripts/hud.gd`、`scripts/weapon_inspect_ui.gd`、`scripts/shop_ui.gd`（新增 `AMMO_COST_PER_TYPE` 过渡成本表，能量电池/手枪弹暂 1 金/发，issue 15/16 定稿）、`run_director.apply_chest_reward`；测试 `test_ammo_system.gd`、`test_shop.gd` 断言适配；`CONTEXT.md` 术语同步。

**与票面假设的偏差（代码现状差异，语义不变）：** 玩家武器索引实际名为 `weapon_index`（非 `current_index`）；击杀入口为 `destroy()`；`on_tick` 置于 `_physics_process` 缓降分支前而非 `_tick_state` 末尾；耐久扣减在 `action_shoot`（实际击发点）；ENEMY_CONFIG 初始 3 条（票内已说明后续票补齐）。

**验证：** 全套 21 个测试运行——本票新增/改动 5 个全部 PASS，其余 14 个 PASS/通过；2 个预存在失败与本票无关（`test_enemy_ai`：HEAD 已有缓降期 `avoidance_enabled=false`，测试过期；`test_minimap_t3`：`main.tscn` Monsters 节点自 issue 02 起为空 + `weapon_inspect_ui.gd` 在 HEAD 已有解析错误，属 issue 17 范围）。

**DoD 自检：**
- [x] `godot --headless --path . res://tests/test_module_hooks.tscn` 全部断言通过
- [x] `godot --headless --path . res://tests/test_enemy_config.tscn` 全部断言通过
- [x] 现有测试无回归（2 个失败为预存在，与本票无关，已记录）
- [x] 领域文档已同步（CONTEXT.md；ADR 022 无需变更）
- [x] 票据已更新（本摘要 + Status → review）
