## 测试 UIMotion 动效工具：Tween 创建与生命周期。
## 运行：godot --headless --path . res://tests/test_ui_motion.tscn --quit-after 300
extends Node3D

var failures: int = 0

func _ready():
	call_deferred("_run_tests")

func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1

func _run_tests() -> void:
	# === 1. tween_in 创建有效 Tween ===
	var ctrl_in := Control.new()
	ctrl_in.modulate = Color(1, 1, 1, 0)
	add_child(ctrl_in)
	var t_in := UIMotion.tween_in(ctrl_in)
	_check(t_in != null, "tween_in 返回非空 Tween")
	_check(t_in.is_valid(), "tween_in 返回有效 Tween")

	# === 2. tween_out 创建有效 Tween ===
	var ctrl_out := Control.new()
	add_child(ctrl_out)
	var t_out := UIMotion.tween_out(ctrl_out)
	_check(t_out != null, "tween_out 返回非空 Tween")
	_check(t_out.is_valid(), "tween_out 返回有效 Tween")

	# === 3. tween_modal_in 创建有效 Tween ===
	var ctrl_mi := Control.new()
	ctrl_mi.size = Vector2(200, 150)
	ctrl_mi.modulate = Color(1, 1, 1, 0)
	add_child(ctrl_mi)
	var t_mi := UIMotion.tween_modal_in(ctrl_mi)
	_check(t_mi != null, "tween_modal_in 返回非空 Tween")
	_check(t_mi.is_valid(), "tween_modal_in 返回有效 Tween")

	# === 4. tween_modal_out 创建有效 Tween ===
	var ctrl_mo := Control.new()
	ctrl_mo.size = Vector2(200, 150)
	add_child(ctrl_mo)
	var t_mo := UIMotion.tween_modal_out(ctrl_mo)
	_check(t_mo != null, "tween_modal_out 返回非空 Tween")
	_check(t_mo.is_valid(), "tween_modal_out 返回有效 Tween")

	# === 5. tween_value 创建有效 Tween ===
	var lbl := Label.new()
	lbl.text = "0"
	add_child(lbl)
	var t_val := UIMotion.tween_value(lbl, 0, 100)
	_check(t_val != null, "tween_value 返回非空 Tween")
	_check(t_val.is_valid(), "tween_value 返回有效 Tween")

	# === 6. pulse_glow 创建有效 Tween（循环） ===
	var ctrl_glow := Control.new()
	add_child(ctrl_glow)
	var t_glow := UIMotion.pulse_glow(ctrl_glow, Color.RED)
	_check(t_glow != null, "pulse_glow 返回非空 Tween")
	_check(t_glow.is_valid(), "pulse_glow 返回有效 Tween")
	# pulse_glow 应设置循环
	_check(t_glow.get_loops_left() != 0, "pulse_glow 设置了循环")

	# === 7. 时长常量 ===
	_check(UIMotion.DURATION_HUD_IN == 0.12, "DURATION_HUD_IN 正确")
	_check(UIMotion.DURATION_MODAL_IN == 0.18, "DURATION_MODAL_IN 正确")
	_check(UIMotion.DURATION_MODAL_OUT == 0.12, "DURATION_MODAL_OUT 正确")
	_check(UIMotion.DURATION_VALUE == 0.25, "DURATION_VALUE 正确")
	_check(UIMotion.DURATION_PULSE == 1.2, "DURATION_PULSE 正确")

	# === 报告 ===
	if failures == 0:
		print("[TEST] ALL PASSED")
	else:
		print("[TEST] %d FAILURES" % failures)

	# === 清理 ===
	ctrl_in.queue_free()
	ctrl_out.queue_free()
	ctrl_mi.queue_free()
	ctrl_mo.queue_free()
	lbl.queue_free()
	ctrl_glow.queue_free()