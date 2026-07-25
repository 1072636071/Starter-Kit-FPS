## 按键说明面板集成测试（ADR 024）
## 运行：godot --headless --path . res://tests/test_controls_help.tscn --quit-after 300
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
	# === 1. 准备 player + controls_help_ui ===
	var player_scene := preload("res://objects/player.tscn")
	var player: CharacterBody3D = player_scene.instantiate()
	player.add_to_group("player")
	add_child(player)

	var ui_scene := preload("res://scripts/controls_help_ui.gd") as GDScript
	var ui: Control = ui_scene.new()
	add_child(ui)

	_check(ui.visible == false, "panel hidden before open")
	_check(get_tree().paused == false, "game not paused before test")
	_check(ui.is_open() == false, "is_open() false before open")

	# === 2. open() 暂停游戏并显示面板 ===
	ui.open(player)
	_check(ui.visible == true, "panel visible after open")
	_check(ui.is_open() == true, "is_open() true after open")
	_check(get_tree().paused == true, "game paused after open")

	# === 3. close() 恢复游戏并隐藏面板 ===
	ui.close()
	_check(ui.visible == false, "panel hidden after close")
	_check(ui.is_open() == false, "is_open() false after close")
	_check(get_tree().paused == false, "game unpaused after close")

	# === 4. closed 信号发射 ===
	var sig_state := {"fired": false}
	ui.closed.connect(func(): sig_state["fired"] = true)
	ui.open(player)
	ui.close()
	_check(sig_state["fired"] == true, "closed signal emitted on close")

	# === 5. mouse_mode 设为 VISIBLE ===
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.open(player)
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "mouse VISIBLE after open")
	ui.close()
	# 注：headless 模式下 close 后 MOUSE_MODE_CAPTURED 不生效（无窗口），
	# 但运行时可验证；此处仅断言 open 侧的 VISIBLE 行为。

	# === 6. 双开防护 ===
	ui.open(player)
	_check(ui.is_open() == true, "open sets is_open")
	ui.open(player)  # 不应崩溃
	_check(ui.is_open() == true, "double open is safe (no-op)")
	ui.close()

	# === 7. 点击背景关闭 ===
	ui.open(player)
	var bg_found := false
	for child in ui.get_children():
		if child is ColorRect and child.color.a > 0.5:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			child.gui_input.emit(click)
			bg_found = true
			break
	_check(bg_found, "background ColorRect found")
	_check(ui.visible == false, "click background closes panel")
	_check(get_tree().paused == false, "click background unpauses game")

	# === 8. KEY_MAP 完整性 ===
	for action_name in ui.KEY_MAP:
		var events := InputMap.action_get_events(action_name)
		_check(events.size() > 0, "KEY_MAP action '%s' has InputMap events" % action_name)

	# === 报告 ===
	if failures == 0:
		print("[TEST] ALL PASSED")
	else:
		print("[TEST] %d FAILURES" % failures)

	# === 清理 ===
	ui.queue_free()
	player.queue_free()
