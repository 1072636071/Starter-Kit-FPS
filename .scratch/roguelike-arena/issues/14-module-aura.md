# 14 — 光环模块组（DebuffAura + SpeedAura + HealAura）

Status: resolved
Type: task
Refs: ADR 022, issue 09

## 描述

实现三个范围光环模块。这是模块系统中"每帧范围检测 + 多目标"模式的验证。**本工单只写模块代码，不创建敌人。** 敌人组装见 issue 17（游戏宅）和 issue 18（日本艺妓/研究员-老人）。

## 前置依赖

- [x] issue 09（模块钩子 `on_tick`）

## 验收标准

### DebuffAura 模块（玩家减速 + 攻速降低）

- [x] 新建 `scripts/modules/module_debuff_aura.gd`，实现：
  - `on_tick(delta)` — 每帧检测 `aura_radius` 内玩家 → 施加减速 + 攻速 debuff；玩家离开范围时恢复
  - 减速：`player.move_speed *= debuff_speed_mult`（实际用 `player.bonus` 字段控制）
  - 攻速：`player.damage_multiplier *= debuff_damage_mult`（或射速系数）
  - 注意不重复叠加（用 `_active` bool 防止每帧重复乘）
- [x] `@export` 参数：`aura_radius: float = 5.0`、`debuff_speed_mult: float = 0.7`、`debuff_damage_mult: float = 0.8`

### SpeedAura 模块（友方加速）

- [x] 新建 `scripts/modules/module_speed_aura.gd`，实现：
  - `on_tick(delta)` — 遍历场景中所有 `monster_base` 实例（`get_tree().get_nodes_in_group("enemy")`），检测 `aura_radius` 内友方
  - 对范围内友方施加 `speed_mult = 1.2`；离开时恢复
  - 维护 `_buffed_enemies: Dictionary`（key=instance_id, value=原始 speed），避免叠加
- [x] `@export` 参数：`aura_radius: float = 10.0`、`speed_mult: float = 1.2`

### HealAura 模块（友方回血）

- [x] 新建 `scripts/modules/module_heal_aura.gd`，实现：
  - `on_tick(delta)` — 遍历场景中所有 `monster_base` 实例，检测 `aura_radius` 内友方
  - 对范围内非满血友方每帧回复 `heal_per_second * delta` HP
  - 治疗量不超过各敌人的 `max_health`（使用 `monster_base` 的 `max_health` 字段或缓存初始 health）
- [x] `@export` 参数：`aura_radius: float = 8.0`、`heal_per_second: float = 3.0`

### 测试

- [x] `tests/test_module_debuff_aura.gd`：创建怪物挂 DebuffAura → 玩家进入 5m 范围 → 断言移速变为 0.7 倍 → 离开恢复
- [x] `tests/test_module_speed_aura.gd`：创建 2 只敌怪，一只挂 SpeedAura → 另一只进入 10m 范围 → 断言移速变为 1.2 倍
- [x] `tests/test_module_heal_aura.gd`：创建怪物扣血至 50 → 挂 HealAura → 推进 5s → 断言血量从 50 恢复到 65
