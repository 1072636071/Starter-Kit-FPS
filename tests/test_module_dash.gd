## Issue 10 测试：Dash 模块
## 运行：godot --headless --path . res://tests/test_module_dash.tscn --quit-after 600
extends Node3D

var failures: int = 0


func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1


func _ready():
	call_deferred("_run_tests")


func _run_tests() -> void:
	var monster_scene: PackedScene = load("res://objects/monster_melee.tscn")
	var monster: Node3D = monster_scene.instantiate()
	add_child(monster)

	# 创建一个 dummy player
	var player := CharacterBody3D.new()
	player.name = "DummyPlayer"
	player.add_to_group("player")
	add_child(player)
	player.global_position = Vector3(10.0, 0.0, 0.0)

	# 等待一帧让 _ready 执行完毕
	await get_tree().process_frame

	var dash := preload("res://scripts/modules/module_dash.gd").new()
	dash.dash_distance = 5.0
	dash.dash_duration = 0.15
	monster.add_child(dash)
	dash.module_setup(monster)

	var start_pos := monster.global_position
	# 触发 ATTACK 状态（AIState.ATTACK = 2）
	monster._change_state(2)  # AIState.ATTACK

	await get_tree().process_frame

	var end_pos := monster.global_position
	var moved := end_pos - start_pos
	var distance_moved := moved.length()
	var expected_dir := (player.global_position - start_pos)
	expected_dir.y = 0.0
	expected_dir = expected_dir.normalized()

	# 断言位移方向正确（水平方向一致，容差 0.1）
	var actual_dir := moved
	actual_dir.y = 0.0
	if actual_dir.length() > 0.01:
		actual_dir = actual_dir.normalized()
		var dot := actual_dir.dot(expected_dir)
		_check(dot > 0.99, "dash direction correct (dot=%.4f)" % dot)

	# 断言距离在 dash_distance ± 0.5m 内
	_check(abs(distance_moved - dash.dash_distance) < 0.5,
		"dash distance within ±0.5m of %.1f (got %.2f)" % [dash.dash_distance, distance_moved])

	# 清理
	monster.queue_free()
	player.queue_free()

	if failures == 0:
		print("[TEST] PASS — issue 10 module_dash")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
