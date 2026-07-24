# Auto-Step 抖动修复经验

## 问题描述

玩家角色在地面走动时（尤其是小台阶附近），角色一抖一抖的，无法平滑移动。

## 根因分析

### 第一层：`move_and_slide()` 在 `_process` 中调用

`move_and_slide()` 以及相关的物理计算（重力、碰撞响应）在 `_process`（可变帧率）中运行，而怪物在 `_physics_process`（固定物理 tick）中运行。这导致物理位置更新频率随 FPS 波动，产生抖动。

**修复：** 将 `move_and_slide()`、`handle_gravity()`、`_try_auto_step()` 迁移到 `_physics_process`。

### 第二层：帧率依赖的 lerp

`velocity.lerp(movement_velocity, delta * 10)` 和 `container.position = lerp(..., delta * 10)` 在不同帧率下加速/衰减行为不同。

**修复：** 改为 `lerp(a, b, 1.0 - exp(-N * delta))`，帧率无关的指数衰减平滑。

### 第三层（核心）：`_try_auto_step` 用 `intersect_ray` 精度不足

原实现用 PhysicsRayQueryParameters3D 的单条射线检测前方台阶顶面，然后直接修改 `global_position.y`。但 `move_and_slide` 随后用完整碰撞体做碰撞响应时，发现玩家实际位置与台阶顶面不匹配，将其推回原地面。每帧"抬升 → 推回"循环 = Y 轴振荡。

**插桩证据：** 120 帧中抬升 11 次但回落 109 次（`lifts=11 drops=109`），`last_lift=0.2037`。

### 走过的弯路

1. **禁用 floor_snap（`floor_snap_length = 0.0`）** — 导致 `is_on_floor()` 返回 false，重力无法归零，造成新的抖动
2. **缩小 floor_snap（`floor_snap_length = step_up - 0.01`）** — 同样问题，重力累加无法消除
3. **`_try_auto_step` 移到 `move_and_slide` 之后** — 下一帧的 floor_snap 仍会拉回

### 正确方案：`test_move` 替代 `intersect_ray`

使用 `test_move`（完整碰撞形状）替代 `intersect_ray`（单条射线），在 `move_and_slide` 之前精确检测前方台阶顶面。

```gdscript
# 关键代码片段
func _try_auto_step(delta: float) -> void:
    if not is_on_floor():
        return

    var horiz_vel := Vector3(velocity.x, 0.0, velocity.z)
    if horiz_vel.length() < 0.5:
        return

    var max_step := StepConstants.STEP_HEIGHT

    # 测试位置：当前位置 + 水平移动量 + 抬高 max_step
    var sweep_transform := global_transform.translated(
        horiz_vel * delta + Vector3(0.0, max_step, 0.0)
    )
    var down_motion := Vector3(0.0, -max_step, 0.0)
    var result := KinematicCollision3D.new()

    var hit := test_move(sweep_transform, down_motion, result)
    if not hit:
        return

    var travel_y := result.get_travel().y  # 负值（向下）
    var step_up := max_step + travel_y

    if step_up <= 0.01 or step_up >= max_step:
        return

    global_position.y += step_up
```

## 关键教训

| 编号 | 教训 | 详情 |
|------|------|------|
| 1 | **`move_and_slide` 必须在 `_physics_process` 中调用** | Godot 物理引擎的碰撞/摩擦/floor_snap 都在物理 tick 中求解，在 `_process` 中调用会引入帧率依赖的不确定性 |
| 2 | **自定义位置修改与引擎物理求解器存在隐含耦合** | `_try_auto_step` 修改 `global_position.y`，而 `move_and_slide` 的 floor_snap 会撤销该修改。两套系统没有协调机制 |
| 3 | **射线检测（`intersect_ray`）不足以代表完整碰撞体** | 单条射线的命中点与胶囊体碰撞响应点不一致，导致抬升偏移。应使用 `test_move` 或 `ShapeCast3D` 做完整碰撞检测 |
| 4 | **禁用物理机制（`floor_snap`）会产生连锁效应** | 禁用 floor_snap 导致 `is_on_floor()` 返回 false，重力不能归零，引发新的抖动。不要禁用物理机制，而是确保物理机制能正确工作 |
| 5 | **帧率相关的 lerp 必须用 exp 衰减** | `lerp(a, b, delta * N)` 在不同帧率下行为不一致。标准公式：`lerp(a, b, 1.0 - exp(-N * delta))` |

## 参考来源

- [Godot 4 Stair Stepping Guide](https://dresswithpockets.github.io/2025/03/19/godot-stair-stepping.html) — 使用 `test_move` 实现平滑上下楼梯的社区经典方案
- ADR 003: [Step and Monster Navigation](/docs/adr/003-step-and-monster-navigation.md)
- CONTEXT.md: "Auto-Step" 与 "step_height" 术语条目