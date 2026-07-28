# 11 — 受伤反馈增强（vignette + 方向指示）

Status: needs-triage
Type: task
Refs: PRD.md, CONTEXT.md「Damage Vignette / Directional Damage Indicator」

## 描述

当前玩家受伤仅有数字扣减和 HUD 更新，缺乏紧迫感。新增屏幕边缘红色 vignette（受击时闪红，强度与伤害成正比）+ 方向指示器（显示伤害来源方向）。

## 验收标准

### Vignette（屏幕边缘变红）

- 新增 `scripts/damage_vignette.gd`（`extends ColorRect`）：
  - 全屏 `ColorRect`，anchor 铺满，默认 `color = Color(1, 0, 0, 0)`（完全透明）
  - 使用 shader material 实现径向渐变：中心透明，边缘红色
  - 或用 `texture` 替代 shader（一张中心透明的径向渐变 PNG）
  - `trigger(intensity: float)` 方法：
    - 设置 `color.a = intensity`（clamp 0–0.5）
    - 立即衰减：`create_tween().tween_property(self, "color:a", 0.0, 0.5)`
- player.gd 的 `damage()` 中调用：
  - `vignette.trigger(clampf(amount / max_health, 0.1, 0.5))`

### 方向指示器

- 新增 `scripts/damage_direction.gd`（`extends Control`）：
  - 屏幕中心一个指向伤害来源的红色箭头（三角形 `draw_polygon()`）
  - `trigger(direction: Vector3)` 方法：将世界方向转为屏幕方向，显示箭头，1s 淡出
  - 箭头不跟随视角旋转（固定在"受伤瞬间"的方向）
- player.gd 的 `damage()` 需知道伤害来源方向：
  - 当前 `damage()` 只接收 `amount`，需扩展签名或另加 `damage_with_direction(amount, source_pos)`
  - v1 简化：假设伤害来源在 `-camera.global_transform.basis.z` 反方向（前方），方向指示器始终指向前方
  - 如果怪物 `damage()` 调用时能传递位置，则用真实方向

## 技术要点

- Vignette 叠加在 HUD 最上层，忽略鼠标事件（`mouse_filter = IGNORE`）
- 方向指示器用 `atan2()` 计算屏幕角度
- v1 方向指示器仅在"前方受伤"时有效——如果从背后受击，方向指示会不准确。v2 可扩展 `damage()` 签名

## 评论

（无）
