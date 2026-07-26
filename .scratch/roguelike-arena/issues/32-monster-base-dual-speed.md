# 32 — monster_base 双速模型

Status: ready-for-agent
Type: task
Refs: ADR 025, issue 31

## 描述

为 `monster_base`（地面怪物基类）引入 `drift_speed` 缓行速度，与现有 `move_speed`（追击最大速度）分离。IDLE 状态下怪物不再静止，而是以 `drift_speed` 缓慢朝玩家移动；追击触发后仍以 `move_speed` 全速战斗。动画选择阈值从单一 `move_speed * 0.8` 改为动态 `(drift_speed + move_speed) / 2`，确保缓行播 walk、追击播 run。

## 前置依赖

无 — 可立即开始。

## 验收标准

### drift_speed 导出与自动计算

- [ ] `monster_base.gd` 新增 `@export var drift_speed: float = 0.0`
- [ ] `_ready()` 中：若 `drift_speed <= 0.0`，自动设为 `move_speed * 0.35`
- [ ] 子类（如 monster_melee、monster_ranged）可显式覆盖 drift_speed 且不被覆盖

### IDLE 状态缓行

- [ ] `_tick_idle()` 改为朝玩家方向以 `drift_speed` 移动：
  - 设置 `nav_agent.target_position = player.global_position`
  - `_desired_velocity = dir * drift_speed`（替代原来的 `Vector3.ZERO`）
- [ ] 缓降阶段（`_dropping = true`）不参与 IDLE 缓行（`_physics_process` 中提前 return，不变）

### CHASE / LOST / JUMP 不变

- [ ] `_tick_chase()`、`_tick_lost()`、`_tick_jump()` 不修改，仍使用 `move_speed`
- [ ] ATTACK / RETREAT 状态不修改

### 动画选择器

- [ ] 新增 `_animation_threshold() -> float`：返回 `(drift_speed + move_speed) / 2.0`
- [ ] `_select_animation()` 使用动态阈值：水平速度 > threshold → "run"，否则 "walk"

### RVO 避障适配

- [ ] `nav_agent.max_speed` 在 `_ready()` 中设到 `move_speed`（上限），不影响 `drift_speed` 生效
- [ ] IDLE 缓行后 `_desired_velocity` 非零，RVO 避障正常参与

## 测试

- [ ] `tests/test_monster_dual_speed.gd`：
  - 测试 1：drift_speed 自动计算（melee: `move_speed * 0.35`，ranged: `move_speed * 0.35`；手动设定后不被覆盖）
  - 测试 2：IDLE 缓行移动（`_desired_velocity` 非零、朝玩家方向、量级 ≈ drift_speed）
  - 测试 3：CHASE 全速不变（移动速度 = move_speed，未被 drift_speed 拖慢）
  - 测试 4：动画选择阈值（水平速度 < threshold → walk，> threshold → run）
