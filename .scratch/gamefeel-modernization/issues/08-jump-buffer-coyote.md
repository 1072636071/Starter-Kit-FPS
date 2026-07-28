# 08 — 跳跃缓冲 + 土狼时间

Status: needs-triage
Type: task
Refs: PRD.md, CONTEXT.md「Jump Buffer / Coyote Time」

## 描述

当前跳跃必须在 `is_on_floor()` 时按下才生效，导致"差一点落地被吞跳"的挫败感。引入两个现代化机制：跳跃缓冲（提前按跳，落地自动触发）和土狼时间（走出边缘后短暂仍可跳）。

## 验收标准

- player.gd 新增常量：
  - `JUMP_BUFFER_WINDOW: float = 0.15` — 缓冲窗口（秒）
  - `COYOTE_TIME: float = 0.1` — 土狼时间（秒）
- 新增运行时状态：
  - `_jump_buffer_timer: float = 0.0` — 缓冲计时器
  - `_coyote_timer: float = 0.0` — 土狼计时器
- `handle_controls()` 中跳跃输入改为：
  - 按跳 → `_jump_buffer_timer = JUMP_BUFFER_WINDOW`
  - 执行跳跃的条件改为：`jumps_remaining > 0 AND (_jump_buffer_timer > 0 OR is_on_floor() OR _coyote_timer > 0)`
  - 执行跳跃后：`_jump_buffer_timer = 0`，`_coyote_timer = 0`
- `_process()` 或 `_physics_process()` 中：
  - `_jump_buffer_timer = max(0, _jump_buffer_timer - delta)`
  - 如果 `is_on_floor()`：`_coyote_timer = COYOTE_TIME`
  - 如果离开地面：`_coyote_timer = max(0, _coyote_timer - delta)`
- 缓冲和土狼时间均在已有 `jumps_remaining` 机制之上叠加（不改变多段跳逻辑）

## 技术要点

- 两个计时器都极短，用 `_process` delta 驱动足够
- 落地时重置 `_coyote_timer` 为最大值，确保"刚好落地"时 `_coyote_timer > 0`
- 缓冲窗口和土狼时间独立运作：缓冲是"提前按"→ 落地自动跳；土狼是"晚按"→ 离地瞬间仍可跳
- 行业标准值已验证良好体验，无需调参
- **buffer 与现有 `jumps_remaining` 守卫的交互**（关键）：现有代码 `if Input.is_action_just_pressed("jump"): if jumps_remaining: action_jump()` 在 `jumps_remaining == 0` 时直接丢弃输入。修改后逻辑：按跳时先设置 `_jump_buffer_timer = JUMP_BUFFER_WINDOW`，然后才检查是否有剩余跳跃次数。即 `is_action_just_pressed("jump")` → 无条件设置 buffer timer → 如果有 `jumps_remaining` 则立即 `action_jump()` 并清零 buffer；如果无 `jumps_remaining` 则保留 buffer 等待落地触发。`_process` 中递减 `_jump_buffer_timer`，落地时若 `_jump_buffer_timer > 0` 且 `jumps_remaining > 0` 则触发跳跃

## 评论

（无）
