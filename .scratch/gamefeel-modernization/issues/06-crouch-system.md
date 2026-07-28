# 06 — 蹲伏系统

Status: needs-triage
Type: task
Refs: PRD.md, CONTEXT.md「Crouch」

## 描述

新增蹲伏能力：按住 Ctrl 时玩家高度降低、移动减速、hitbox 缩小。

## 验收标准

- `project.godot` 新增输入动作 `crouch`（绑 Left Ctrl）
- player.gd 新增 `@export` 参数：
  - `crouch_speed_multiplier: float = 0.5`
  - `crouch_height_reduction: float = 0.6` — 碰撞体高度缩小比例
  - `crouch_camera_offset: float = -0.6` — 相机相对头部下移量
- `handle_controls()` 中新增蹲伏逻辑：
  - Hold Ctrl → `is_crouching = true`
  - 松开 Ctrl → 检测头顶空间（`test_move` 向上），有空间才站起
- 碰撞体调整（**注意**：实际节点名为 `$Collider`，形状为 `CapsuleShape3D`，不是 `CollisionShape3D` + `BoxShape3D`）：
  - `_ready()` 中缓存原始值：`_crouch_original_height = $Collider.shape.height`（当前为 1.0）、`_crouch_original_y = $Collider.position.y`（当前为 0.55）
  - 蹲下：`$Collider.shape.height = _crouch_original_height * crouch_height_reduction`，`$Collider.position.y = _crouch_original_y * crouch_height_reduction`
  - 站起：恢复为 `_crouch_original_height` 和 `_crouch_original_y`
  - **CapsuleShape3D 语义**：`height` 是胶囊体圆柱段高度，不含上下半球（radius=0.3）。蹲下后圆柱段 = 1.0 × 0.6 = 0.6，加上半球总高 ≈ 1.2；站立总高 ≈ 1.6。比例合理。
- 相机/头部下移：`$Head.position.y` 调整（或 `camera_item.position.y`）
- 移动速度：`movement_velocity *= crouch_speed_multiplier`
- 蹲伏中射击：精准度提升 20%（`spread *= 0.8`），但不能冲刺
- 脚步声：蹲伏中 `sound_footsteps.volume_db = -6`（更安静）

## 技术要点

- 碰撞体缩放用 `$Collider.shape.height`（CapsuleShape3D），避免 `scale` 的嵌套变换问题。`_ready()` 中缓存原始 height 和 position.y，站起时精确恢复
- 站起检测：松开 Ctrl 时用 `test_move` 向上检测 0.5m，有碰撞则保持蹲伏
- 相机平滑过渡：`camera.position.y = lerp(camera.position.y, crouch_offset, 1.0 - exp(-12.0 * delta))`

## 评论

（无）
