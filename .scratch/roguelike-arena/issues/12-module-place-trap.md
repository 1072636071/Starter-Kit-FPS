# 12 — 陷阱模块组（PlaceTrap 基类 + Poison + Damage 变体）

Status: ready-for-agent
Type: task
Refs: ADR 022, issue 09

## 描述

实现 PlaceTrap 模块基类及两个变体（Poison / Damage）。这是模块系统中第一个"基类+变体"模式，验证复用性。**本工单只写模块 + 陷阱场景，不创建敌人。** 敌人组装见 issue 16（化学人）和 issue 18（猎人）。

## 前置依赖

- [x] issue 09（模块钩子 `on_tick`）

## 验收标准

### PlaceTrap 基类

- [ ] 新建 `scripts/modules/module_place_trap_base.gd`，继承 `EnemyModule`，实现：
  - `on_tick(delta)` — 倒计时 `_cooldown_remaining`，归零且在场陷阱 < `max_traps` 时 `_place_trap()`
  - `_place_trap()` — 在 `enemy.global_position` 处 instantiate 陷阱场景，记录到 `_active_traps`
  - `on_death()` — 遍历 `_active_traps` 全部 `queue_free()`
- [ ] `@export` 参数（子类覆盖）：
  - `trap_scene: PackedScene`
  - `place_cooldown: float = 5.0`
  - `max_traps: int = 3`

### 陷阱场景基类

- [ ] 新建 `scenes/trap_base.tscn` + `scripts/trap_base.gd`：
  - `extends Area3D`
  - 公开 `activate(player)` 虚方法（子类覆盖）
  - `body_entered` 检测 `"player"` 组 → 调用 `activate(player)` → 自身 `queue_free()` 或延迟 `queue_free()`
  - 默认 invisible（`visible = false`），子类加粒子特效

### Poison 变体

- [ ] 新建 `scripts/modules/module_place_trap_poison.gd`，继承 `module_place_trap_base`
- [ ] 新建 `scenes/trap_poison.tscn`，继承 `trap_base.gd`：
  - `activate(player)` → 展开绿色粒子区域（`GPUParticles3D`，半径 3m）→ 用 Timer 每 0.5s 对区域内玩家扣 `poison_dps` 伤害，持续 10s → `queue_free()`
  - `@export` 参数：`poison_radius: float = 3.0`、`tick_interval: float = 0.5`、`poison_dps: int = 8`、`duration: float = 10.0`

### Damage 变体

- [ ] 新建 `scripts/modules/module_place_trap_damage.gd`，继承 `module_place_trap_base`（覆盖 `trap_scene` 为 `trap_damage.tscn`，`place_cooldown = 6.0`）
- [ ] 新建 `scenes/trap_damage.tscn`，继承 `trap_base.gd`：
  - `activate(player)` → 立刻爆炸 AOE：`explosion_radius = 2.5m`，`explosion_damage = 40` → `queue_free()`

### 测试

- [ ] `tests/test_module_place_trap.gd`：
  - 创建临时怪物挂 Poison 模块，模拟 16s 推进（3 个 5s 冷却 + 1s buffer）
  - 断言正好 3 个陷阱 spawned（`max_traps` 上限生效），第 4 个冷却不产生
  - 调用 `destroy()` → 断言 3 个陷阱全部 `queue_free()`
- [ ] `tests/test_trap_poison.gd`：
  - 放置毒陷阱，玩家踩入 → 断言 10s 内扣血 20 ticks × 8 = 160
- [ ] `tests/test_trap_damage.gd`：
  - 放置伤害陷阱，玩家踩入 → 断言立刻扣血 40（AOE 范围内）
