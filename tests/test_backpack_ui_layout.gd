## 背包 UI 布局回归测试
## 锁定 bug：根 Control 未设 full-rect 锚点 → 子节点 bg/panel 相对零尺寸父节点也为零尺寸，
## 渲染在 (0,0) 左上角（"什么都没有 + UI 在左上角"）。
## 运行：godot --headless --path . res://tests/test_backpack_ui_layout.tscn --quit-after 300
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
	var ui_scene := preload("res://scripts/backpack_ui.gd") as GDScript
	var ui: Control = ui_scene.new()
	add_child(ui)

	# 根 Control 必须填满视口（与 weapon_inspect_ui.tscn 一致）
	_check(ui.anchor_right == 1.0, "root Control anchor_right == 1.0 (fills viewport width)")
	_check(ui.anchor_bottom == 1.0, "root Control anchor_bottom == 1.0 (fills viewport height)")

	if failures == 0:
		print("[TEST] ALL PASSED")
	else:
		print("[TEST] %d FAILURES" % failures)

	ui.queue_free()
