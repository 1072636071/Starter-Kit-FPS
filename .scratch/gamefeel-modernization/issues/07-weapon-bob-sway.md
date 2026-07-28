# 07 — 武器摆动（Bob & Sway）

Status: needs-triage
Type: task
Refs: PRD.md, CONTEXT.md「Weapon Bob / Weapon Sway」

## 描述

为第一人称武器视图模型添加程序化摆动：空闲时缓慢呼吸式摇摆（idle sway），移动时节奏性摆动（bob），ADS 时大幅减弱。

## 验收标准

- player.gd 新增 `@export_subgroup("Weapon Bob & Sway")` 参数：
  - `bob_speed: float = 8.0` — 移动摆动频率
  - `bob_amplitude_h: float = 0.015` — 水平摆动幅度（米）
  - `bob_amplitude_v: float = 0.025` — 垂直摆动幅度（米）
  - `idle_sway_speed: float = 1.5` — 空闲摇摆频率
  - `idle_sway_amplitude: float = 0.005` — 空闲摇摆幅度（米）
  - `ads_bob_factor: float = 0.3` — ADS 时摆动衰减系数
- `_process()` 中 `_step_weapon_bob(delta)`：
  - 累加 `_bob_time += delta * bob_speed`
  - 空闲（速度 < 0.5）：`container.position` = `container_offset` + 正弦 idle sway（慢速小幅）
  - 移动中：`container.position` = `container_offset` + 正弦 bob（横向 = sin，纵向 = |cos|×2 模拟脚步双峰）
  - 冲刺：振幅 × 1.3
  - 蹲伏：振幅 × 0.6
  - ADS：振幅 × `ads_bob_factor`
- idle sway 额外叠加轻微旋转：`container.rotation.z = sin(time) * 0.01`
- 落地瞬间：bob 短暂放大（`bob_amplitude_v *= 1.5`，0.2s lerp 回）
- 与已有 `container.position` 的 velocity lerp（第 436 行）共存：先算 bob 偏移，再叠加 velocity 偏移

## 技术要点

- 纯数学 sine 波，不需要动画资源
- bob 的时间累加器用 `wrapf()` 防浮点溢出
- 与已有第 436 行 `container.position` lerp 逻辑整合：`final_pos = container_offset + bob_offset + velocity_offset`
- 参考 CS/COD 的"双峰 bob"：移动时垂直运动用 `abs(sin(time))` 产生两个峰（模拟左右脚步）

## 评论

（无）
