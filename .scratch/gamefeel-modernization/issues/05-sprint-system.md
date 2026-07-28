# 05 — 冲刺系统

Status: needs-triage
Type: task
Refs: PRD.md, CONTEXT.md「Sprint」

## 描述

新增冲刺能力：按住 Shift 时移动速度提升，伴随 FOV 扩张，冲刺中不可射击（或极低精度）。

## 验收标准

- `project.godot` 新增输入动作 `sprint`（绑 Left Shift）
- player.gd 新增 `@export` 参数：
  - `sprint_speed_multiplier: float = 1.6`
  - `sprint_fov: float = 85.0`
- `handle_controls()` 中新增冲刺逻辑：
  - `Input.is_action_pressed("sprint")` + 地面 + 有移动输入 → `is_sprinting = true`
  - 松开 Shift / 停止移动 / 跳跃 / 空中 → `is_sprinting = false`
  - 冲刺中扣扳机 → 自动退出冲刺（或不准射击，v1 先退出冲刺）
- 移动速度：`movement_velocity *= sprint_speed_multiplier`（叠加在 ADS speed factor 之上，冲刺时 ADS 优先级低）
- FOV：`_process()` 中 FOV 目标增加冲刺态判断：
  - `is_sprinting → sprint_fov` > `is_aiming → AIM_FOV` > `_melee_active → DEFAULT_FOV + 5` > `DEFAULT_FOV`
  - 优先级：冲刺 > 近战 > 默认（ADS 和冲刺互斥——冲刺时不 AIM）
- 脚步声：冲刺时 `sound_footsteps.pitch_scale = 1.3`（稍快/高音调）
- 冲刺不消耗体力（PvE 不需要资源管理）

## 技术要点

- `is_sprinting` 为 bool 运行时状态
- 与 ADS 互斥：冲刺中 `is_aiming = false`
- FOV 过渡复用已有 `move_toward` 逻辑（`camera.fov = move_toward(camera.fov, fov_target, delta * 150.0)`）
- **射击退出冲刺的时序**（关键）：当 `is_sprinting and Input.is_action_pressed("shoot")` 时，本帧先设置 `is_sprinting = false`、恢复 `movement_velocity`、回退 FOV 目标，但**不执行射击**——射击在下一帧 `handle_controls` 中正常触发。这避免同一帧内"边跑边射"的瞬移感。实现方式：在冲刺逻辑块中将 `is_sprinting = false` 后 `return`（跳过本帧 `action_shoot()`），下帧自动进入正常射击路径

## 评论

（无）
