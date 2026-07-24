# Auto-Step 抖动调试过程记录

## 概述

本文档记录从"玩家走动一抖一抖"到找到根因并修复的完整调试过程，包括反馈循环构建、假设生成、插桩验证、社区调研等环节。

## 阶段 1：构建反馈循环

### 1.1 代码审查

首先阅读 [player.gd](file:///g:/work/Starter-Kit-FPS/objects/player.gd) 的全部代码，第一时间发现关键异常：

- **玩家**的 `move_and_slide()` 在 `_process` 中调用
- **怪物**（monster_melee.gd）的 `move_and_slide()` 在 `_physics_process` 中调用

### 1.2 量化抖动指标

在 `_process` 末尾插入抖动检测代码，计算帧间水平位移的变异系数（标准差/均值）：

```gdscript
# 每帧记录水平位移 delta
var h_delta := Vector2(position.x - prev.x, position.z - prev.z).length()
# 每 120 帧输出变异系数 cv
# cv > 0.3 判定为明显抖动
```

**输出：** 移动时 cv 在 1.2~2.5 之间，远超 0.3 阈值，确认抖动可量化。

## 阶段 2：生成假设

生成 3 个排序假设，向用户展示后按优先级执行：

| 优先级 | 假设 | 预测 |
|--------|------|------|
| #1 | `move_and_slide` 在 `_process` 中调用 | 迁移到 `_physics_process` 后抖动消失 |
| #2 | 帧率依赖的 `lerp(a, b, delta * 10)` | 改为 `1.0 - exp(-10 * delta)` 后消失 |
| #3 | 武器模型 container 位置 lerp 抖动 | 仅修复 container lerp 武器抖动消失但位置抖动仍在 |

## 阶段 3：插桩验证

### 3.1 初次修复（失败）

迁移 `move_and_slide` 到 `_physics_process` + 修复 lerp 后，用户反馈抖动依然存在。

### 3.2 Y 轴追踪插桩

加入帧级 Y 轴追踪，检测 `_try_auto_step` 抬升与 `move_and_slide` 后的回落：

```gdscript
# 记录抬升前 y → 抬升后 y → slide 后 y
y_before_step → y_after_step → y_after_slide
```

**关键发现：** 120 帧中 `_try_auto_step` 抬升 11 次，但 `move_and_slide` 之后回落 109 次。`avg_change ≈ 0`（正负交替），确认是"抬升→回落"振荡。

### 3.3 方案 1：禁用 floor_snap（失败）

在抬升后设置 `floor_snap_length = 0.0`，下一帧恢复。

**结果：** 抖动变化。插桩显示 `is_on_floor()` 在 floor_snap 禁用期间返回 false，重力无法归零（`g_mean=1.7`），产生新的抖动。

### 3.4 方案 2：缩小 floor_snap（失败）

将 `floor_snap_length` 设为 `step_up - 0.01`，使 floor_snap 只能触及新台阶顶面。

**结果：** 同样问题，`is_on_floor()` 间歇性 false。

### 3.5 方案 3：`_try_auto_step` 移到 `move_and_slide` 之后（失败）

先让物理引擎完成碰撞，再抬升。

**结果：** 下一帧的 floor_snap 仍然把玩家拉回。

## 阶段 4：社区调研

在三个方案都失败后，转向社区寻找经典实现：

1. 搜索 "Godot 4 CharacterBody3D auto step up stairs implementation"
2. 找到 **dresswithpockets** 的 Godot 4 Stair Stepping Guide
3. 核心方案：使用 `test_move` 替代 `intersect_ray`

**为什么 `test_move` 比 `intersect_ray` 更正确：**

| 对比 | `intersect_ray` | `test_move` |
|------|-----------------|-------------|
| 碰撞形状 | 单条射线 | 完整碰撞体（胶囊体、盒子等） |
| 实际表现 | 命中点与引擎解算不一致 | 与 `move_and_slide` 的碰撞响应一致 |
| 结果 | 抬升量偏差 → 被 physics 推回 | 精确匹配 → 稳定站立 |

## 阶段 5：最终修复

### 5.1 重写 `_try_auto_step`

```gdscript
# 用 test_move 替代 intersect_ray
# 1. 抬高 max_step 到前方
# 2. 向下测试移动 max_step
# 3. 从 travel 计算精确抬升量
# 4. 在 move_and_slide 之前抬升
```

### 5.2 清理所有中间 hack

移除 `_step_skip_snap_frames`、`_step_applied_this_frame`、`_last_step_up` 等临时变量。

## 关键时间线

```
代码审查 → 发现 _process 异常 → 量化抖动指标
  → 3 个假设 → 迁移到 _physics_process → 用户反馈抖动仍在
  → Y 轴追踪插桩 → 发现 auto-step 振荡
  → 禁用 floor_snap（失败）→ 缩小 floor_snap（失败）
  → 移到 move_and_slide 之后（失败）
  → 社区调研 → 找到 test_move 方案
  → 重写 _try_auto_step → 用户确认修复
```

## 教训总结

1. **插桩先于猜测**：Y 轴追踪插桩直接定位了"抬升→回落"振荡，否则可能一直猜测帧率问题
2. **不要与物理引擎对抗**：禁用 floor_snap 等方案都在与引擎对抗，正确方案是让引擎的检测结果自洽
3. **社区调研是高效手段**：三个方案失败后转向社区，10 分钟找到了成熟方案
4. **`test_move` 是 Godot 4 中处理自定义碰撞检测的标准工具**，比手动射线检测更可靠