# 34 — enemy 飞行敌人双速适配

Status: ready-for-agent
Type: task
Refs: ADR 025, issue 31, issue 32

## 描述

为飞行敌人 `enemy.gd` 适配双速模型。enemy 不使用 NavMesh 也不调用 `_tick_idle()`，其 IDLE 行为由 `_process()` 控制。在未进入追逐时以 `drift_speed` 缓慢靠近玩家，进入追击后以 `fly_speed` 全速战斗。飞行怪的行为节奏与地面怪（#32）一致化。

## 前置依赖

无 — 可立即开始。与 #32 并行实施，触碰文件不重叠。

## 验收标准

### drift_speed 导出与自动计算

- [ ] `enemy.gd` 新增 `@export var drift_speed: float = 0.0`
- [ ] `_ready()` 中：若 `drift_speed <= 0.0`，自动设为 `fly_speed * 0.35`（≈ 1.5）

### 缓行阶段

- [ ] 未进入追逐时（即 IDLE / 未警觉），以 `drift_speed` 朝玩家移动
- [ ] 缓行移动在 `_process()` 中实现，使用向量飞行（与 enemy 现有移动方式一致）

### 追击阶段

- [ ] 进入追逐后以 `fly_speed` 追击（不变）
- [ ] 追击触发逻辑（awareness_range 等）不变

### 与 #32 行为一致

- [ ] 玩家能感受到飞行敌人也有"缓行逼近 → 追击全速"的节奏层次
- [ ] drift_speed / fly_speed 速度比与地面怪 drift_speed / move_speed 保持同比例关系

## 测试

- [ ] `tests/test_enemy_dual_speed.gd`：
  - 测试 1：drift_speed 自动计算（= fly_speed * 0.35；手动设定后不被覆盖）
  - 测试 2：IDLE 缓行移动（未进入追逐时朝玩家方向移动，速度 ≈ drift_speed）
  - 测试 3：CHASE 全速不变（进入追击后速度 = fly_speed）
