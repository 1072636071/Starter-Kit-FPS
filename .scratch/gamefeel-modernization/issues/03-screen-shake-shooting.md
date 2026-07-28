# 03 — 射击震屏系统

Status: needs-triage
Type: task
Refs: PRD.md, CONTEXT.md「Screen Shake」

## 描述

当前只有近战命中时有简易震屏（`_melee_hit_shake`，随机偏移 + lerp 衰减）。补充射击震屏：每次开枪时相机产生 Perlin-noise 驱动的抖动，振幅与武器后坐力强度成正比。

## 验收标准

- Weapon 资源新增 `@export_subgroup("Screen Shake")`：
  - `screen_shake_amplitude: float = 0.0` — 震屏振幅（世界单位），0 = 不振。Blaster 建议 0.015，Repeater 建议 0.005
  - `screen_shake_frequency: float = 30.0` — 噪声采样频率（Hz）
  - `screen_shake_duration: float = 0.08` — 单次震屏持续时间（秒）
- player.gd 新增运行时状态：
  - `_shake_intensity: float = 0.0` — 当前震屏强度（指数衰减）
  - `_shake_time: float = 0.0` — 噪声时间累加器
- `action_shoot()` 中：每次击发时 `_shake_intensity = weapon.screen_shake_amplitude`
- `_process()` 中 `_step_screen_shake(delta)`：
  - `_shake_intensity = lerp(_shake_intensity, 0.0, 1.0 - exp(-20.0 * delta))`
  - 如果 `_shake_intensity > 0.001`：`_shake_time += delta * weapon.screen_shake_frequency`
  - `camera.position.x += noise_1d(_shake_time) * _shake_intensity`
  - `camera.position.y += noise_1d(_shake_time + 1000.0) * _shake_intensity`
  - 使用 Godot 的 `FastNoiseLite` 或手动 `sin()` 组合近似 Perlin
- 震屏叠加在已有落地回弹和近战震屏之上，互不干扰
- beam 武器：每个 tick 也触发震屏（振幅可小一些）

## 技术要点

- 与已有 `_melee_hit_shake` 和落地回弹叠加：`camera.position.x/y` 累加多个偏移源。**叠加策略**：射击震屏、近战震屏、落地回弹三者独立计算各自的偏移量，最后在 `_process` 末尾一次性累加到 `camera.position`。如果多个震源同时活跃，取各自偏移之和（不取 max，因为震屏频率不同不会互相抵消）
- 用 Godot 的 `FastNoiseLite` 或简化 `sin(x*1.7) * cos(x*3.1)` 避免引入额外节点。v1 用手动 `sin/cos` 组合近似噪声（零依赖），后续可升级为 `FastNoiseLite`
- 震屏在 ADS 时可降为 0.3×（ADS 需要稳定性）
- **与近战震屏的 Tween 冲突**：近战震屏通过 `_melee_hit_shake` + lerp 直接修改 `camera.position`（第 456-458 行），射击震屏也修改 `camera.position`。两者不冲突——只需确保射击震屏的偏移在近战震屏偏移之后累加，且各自独立计算偏移量后求和。不使用 Tween 驱动震屏，使用 `_process` 中的浮点累加器

## 评论

（无）
