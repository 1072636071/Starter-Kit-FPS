# 10 — 隐现模块组（Stealth + Dash）

Status: resolved
Type: task
Refs: ADR 022, issue 09

## 描述

实现两个最基础的战斗模块——Stealth（隐身）和 Dash（瞬步）。这两个模块不依赖任何其他模块，是验证模块系统"状态驱动"能力的最佳入口。**本工单只写模块代码，不创建敌人。** 敌人组装见 issue 16。

## 前置依赖

- [x] issue 09（模块钩子 `on_enter_state` / `on_tick` / `on_damage` / `on_death`）

## 验收标准

### Stealth 模块

- [x] 新建 `scripts/modules/module_stealth.gd`，继承 `EnemyModule`，实现：
  - `module_setup(enemy)` — 缓存宿主模型 mesh 引用
  - `on_enter_state(AIState.ATTACK)` — 把宿主模型所有 mesh 的 `transparency` 设为 0.4；用 `SceneTree.create_timer(0.5)` 恢复为 0
  - 非 ATTACK 状态进入不触发
- [x] `@export` 参数：`stealth_duration: float = 0.5`、`stealth_alpha: float = 0.4`
- [x] 模块挂为任意 `monster_base` 子类 `.tscn` 的子节点即可工作——不读不写敌人特定字段

### Dash 模块

- [x] 新建 `scripts/modules/module_dash.gd`，继承 `EnemyModule`，实现：
  - `module_setup(enemy)` — 缓存引用
  - `on_enter_state(AIState.ATTACK)` —
    - 计算 dash 方向：`(player.global_position - enemy.global_position).normalized()`，y 分量归零
    - 用 `Tween`（或直接 `global_position += dir * dash_distance`）瞬移
    - Dash 后调用 `enemy._deal_damage()`（复用 melee 距离判定）
  - 非 ATTACK 状态进入不触发
- [x] `@export` 参数：`dash_distance: float = 5.0`、`dash_duration: float = 0.15`

### 测试

- [x] `tests/test_module_stealth.gd`：
  - 创建临时 `monster_melee` 实例，挂 Stealth 模块
  - 触发 ATTACK → 断言 0.5s 内 mesh `transparency == 0.4`，0.6s 后恢复 0
- [x] `tests/test_module_dash.gd`：
  - 创建临时 `monster_melee` 实例，挂 Dash 模块
  - 放置 dummy player，触发 ATTACK → 断言位移方向正确、距离在 `dash_distance ± 0.5m` 内
