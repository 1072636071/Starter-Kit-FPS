## UIMotion — 动效工具类，提供战术风（cubic ease-out）过渡动画。
##
## 全部使用 TRANS_CUBIC + EASE_OUT，无弹性/回弹/过冲。
## 所有方法均为静态方法，可直接调用。
##
## 用法：
##   UIMotion.tween_in(control)          → 面板滑入 + 淡入
##   UIMotion.tween_out(control)         → 面板滑出 + 淡出
##   UIMotion.tween_modal_in(control)    → Modal scale+fade 打开
##   UIMotion.tween_modal_out(control)   → Modal scale+fade 关闭
##   UIMotion.tween_value(label, 0, 100) → 数值滚动动画
##   UIMotion.pulse_glow(control, color) → 脉冲发光警示
class_name UIMotion
extends Node

## ── 时长常量（秒） ────────────────────────────────────────
const DURATION_HUD_IN    := 0.12
const DURATION_HUD_OUT   := 0.12
const DURATION_MODAL_IN  := 0.18
const DURATION_MODAL_OUT := 0.12
const DURATION_VALUE     := 0.25
const DURATION_PULSE     := 1.2

## ── 过渡常量 ──────────────────────────────────────────────
const TRANS_TYPE := Tween.TRANS_CUBIC
const EASE_TYPE  := Tween.EASE_OUT


## HUD 元素出现：8px 上滑 + fade-in（120ms）
static func tween_in(control: Control) -> Tween:
	var tween := control.create_tween()
	tween.set_parallel(true)
	tween.set_trans(TRANS_TYPE)
	tween.set_ease(EASE_TYPE)
	control.modulate.a = 0.0
	control.position.y += 8.0
	tween.tween_property(control, "modulate:a", 1.0, DURATION_HUD_IN)
	tween.tween_property(control, "position:y", control.position.y - 8.0, DURATION_HUD_IN)
	tween.set_parallel(false)
	return tween


## HUD 元素消失：8px 下滑 + fade-out（120ms）
static func tween_out(control: Control) -> Tween:
	var tween := control.create_tween()
	tween.set_parallel(true)
	tween.set_trans(TRANS_TYPE)
	tween.set_ease(EASE_TYPE)
	tween.tween_property(control, "modulate:a", 0.0, DURATION_HUD_OUT)
	tween.tween_property(control, "position:y", control.position.y + 8.0, DURATION_HUD_OUT)
	tween.set_parallel(false)
	return tween


## Modal 打开：scale 0.96→1.0 + fade-in（180ms）
static func tween_modal_in(control: Control) -> Tween:
	var tween := control.create_tween()
	tween.set_parallel(true)
	tween.set_trans(TRANS_TYPE)
	tween.set_ease(EASE_TYPE)
	control.modulate.a = 0.0
	control.pivot_offset = control.size / 2.0
	control.scale = Vector2(0.96, 0.96)
	tween.tween_property(control, "modulate:a", 1.0, DURATION_MODAL_IN)
	tween.tween_property(control, "scale", Vector2(1.0, 1.0), DURATION_MODAL_IN)
	tween.set_parallel(false)
	return tween


## Modal 关闭：scale 1.0→0.96 + fade-out（120ms）
static func tween_modal_out(control: Control) -> Tween:
	var tween := control.create_tween()
	tween.set_parallel(true)
	tween.set_trans(TRANS_TYPE)
	tween.set_ease(EASE_TYPE)
	control.pivot_offset = control.size / 2.0
	tween.tween_property(control, "modulate:a", 0.0, DURATION_MODAL_OUT)
	tween.tween_property(control, "scale", Vector2(0.96, 0.96), DURATION_MODAL_OUT)
	tween.set_parallel(false)
	return tween


## 数值变化：tween count up/down（250ms）
## 用法：UIMotion.tween_value(label, 0, 100)  → label.text 从 "0" 滚动到 "100"
static func tween_value(label: Label, from_val: float, to_val: float) -> Tween:
	var tween := label.create_tween()
	tween.set_trans(TRANS_TYPE)
	tween.set_ease(EASE_TYPE)
	var current := from_val
	tween.tween_method(
		func(v: float):
			current = v
			label.text = str(int(round(v))),
		from_val,
		to_val,
		DURATION_VALUE
	)
	return tween


## 脉冲发光：modulate 1.0→0.7→1.0 循环（1.2s）
## 用于低血/低弹/低耐久等关键状态警示。
static func pulse_glow(control: Control, pulse_color: Color = Color.WHITE) -> Tween:
	var tween := control.create_tween()
	tween.set_loops()
	tween.set_trans(TRANS_TYPE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(control, "modulate", pulse_color * 0.7, DURATION_PULSE / 2.0)
	tween.tween_property(control, "modulate", pulse_color, DURATION_PULSE / 2.0)
	return tween