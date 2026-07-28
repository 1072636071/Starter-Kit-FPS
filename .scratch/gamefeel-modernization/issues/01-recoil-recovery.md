# 01 — 后坐力自动恢复系统

Status: needs-triage
Type: task
Refs: PRD.md, ADR 028, CONTEXT.md「Knockback / Recoil Recovery」

## 描述

当前 `action_shoot()` 中后坐力施加角度偏转后**永不恢复**（`camera.rotation.x/y` 和 `rotation_target.x/y` 永久偏移）。本 issue 实现"停止射击后自动回弹到原始瞄准点"的自动恢复机制。

## 验收标准

- Weapon 资源新增两个 `@export` 字段（`@export_subgroup("Recoil")`）：
  - `recoil_recovery_speed: float = 8.0` — 恢复速度（值越大越快）
  - `recoil_recovery_delay: float = 0.08` — 停止射击后等待多久开始恢复（秒）
- player.gd 新增运行时状态：
  - `_recoil_offset: Vector2` — 当前后坐力累积偏移（垂直 = x，水平 = y）
  - `_recoil_target: Vector2` — 每帧 lerp 的目标值（始终为 Vector2.ZERO）
  - `_recoil_timer: float` — 停止射击后倒计时
- `action_shoot()` 中：移除对 `camera.rotation` / `rotation.y` / `rotation_target` 的直接修改（当前第 825-828 行），改为**仅**累加 knockback 到 `_recoil_offset`（`_recoil_offset.x += knockback.x`，`_recoil_offset.y += knockback.y`），并重置 `_recoil_timer = weapon.recoil_recovery_delay`。`container.position.z += 0.25` 和 `movement_velocity += Vector3(0, 0, weapon.knockback)` 保持不变。
- `_process()` 中新增 `_step_recoil_recovery(delta)`：
  - 如果正在射击（`Input.is_action_pressed("shoot")`）：`_recoil_timer = weapon.recoil_recovery_delay`，不恢复
  - 否则：`_recoil_timer` 递减，到 0 后 `_recoil_offset = _recoil_offset.lerp(Vector2.ZERO, 1.0 - exp(-weapon.recoil_recovery_speed * delta))`
- **关键架构变更** — `camera.rotation` 的每帧合成必须在 `_process` 中完成（不能只在 `_input` 事件触发时计算）：
  - `handle_rotation()` 的鼠标路径（当前第 700-701 行）：移除 `camera.rotation.x = rotation_target.x` 和 `rotation.y = rotation_target.y` 两行——`handle_rotation` 仅负责更新 `rotation_target` 和 clamp
  - `handle_rotation()` 的手柄路径（当前第 695-696 行）：将 `camera.rotation.x = lerp_angle(...)` 和 `rotation.y = lerp_angle(...)` 的 lerp 目标改为 `rotation_target.x + _recoil_offset.x` 和 `rotation_target.y + _recoil_offset.y`
  - `_process` 中在 `handle_controls(delta)` 调用之后、所有震屏偏移之前，新增 `_step_apply_recoil(delta)`：鼠标模式直接 `camera.rotation.x = rotation_target.x + _recoil_offset.x` / `rotation.y = rotation_target.y + _recoil_offset.y`；手柄模式已在上面的 lerp 目标中处理，此处不重复赋值
- 切枪时：立即清除 `_recoil_offset = Vector2.ZERO`（新枪不受旧枪后坐力影响）
- 换弹时：后坐力照常恢复（换弹中不射击，自然触发恢复）
- 空弹匣扣扳机时：不累加后坐力（无击发无后坐）

## 技术要点

- 恢复利用已有 `_process` 循环，不新增 Timer 节点
- 用 `exp` 衰减公式保证帧率无关：`lerp(offset, target, 1.0 - exp(-speed * delta))`
- `rotation_target` 体系保持不变（鼠标/手柄输入驱动），`_recoil_offset` 作为叠加层
- 武器切换时 `_recoil_offset = Vector2.ZERO` 防残留

## 评论

（无）
