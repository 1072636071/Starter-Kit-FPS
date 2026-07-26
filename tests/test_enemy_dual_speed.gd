## 竞技场 Issue 34 测试：enemy 飞行敌人双速适配
## 运行：godot --headless --path . res://tests/test_enemy_dual_speed.tscn --quit-after 600
extends Node

var failures: int = 0
var dummy_player: Node3D

func _ready():
	call_deferred("_run_tests")

func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1

func _make_dummy_player() -> Node3D:
	var p := Node3D.new()
	p.add_to_group("player")
	p.position = Vector3(100, 0, 100)  # 远距离，超出 chase_range(70)，触发 drift
	add_child(p)
	return p

func _run_tests() -> void:
	dummy_player = _make_dummy_player()

	# === 测试 1：drift_speed 自动计算 ===
	var enemy_scene := preload("res://objects/enemy.tscn")
	var enemy: Node3D = enemy_scene.instantiate()
	enemy.set("player", dummy_player)
	add_child(enemy)

	var fly_speed := float(enemy.get("fly_speed"))
	var drift_speed := float(enemy.get("drift_speed"))
	var expected_drift := fly_speed * 0.35
	_check(abs(drift_speed - expected_drift) < 0.01,
		"enemy drift_speed == fly_speed*0.35 (%.2f vs %.2f)" % [drift_speed, expected_drift])

	# 测试 1b：手动设定 drift_speed 不被覆盖
	var enemy2: Node3D = enemy_scene.instantiate()
	enemy2.set("player", dummy_player)
	enemy2.set("drift_speed", 3.0)
	add_child(enemy2)
	var enemy2_drift := float(enemy2.get("drift_speed"))
	_check(abs(enemy2_drift - 3.0) < 0.01,
		"manual drift_speed=3.0 not overwritten (got %.2f)" % enemy2_drift)

	# === 测试 2：IDLE 缓行（玩家超出 chase_range，enemy 缓行靠近）===
	# enemy 刚 spawn 在缓降状态，先跳过缓降
	enemy.set("_dropping", false)
	enemy.set("position", Vector3(0, 4, 0))
	dummy_player.position = Vector3(100, 0, 100)  # dist ≈ 141 > chase_range(70)

	# 记录初始位置，推进 N 帧，检查是否朝 player 移动
	var start_pos: Vector3 = enemy.get("position")
	for _i in range(10):
		await get_tree().process_frame
	var end_pos: Vector3 = enemy.get("position")

	var to_player_start := Vector3(dummy_player.position.x - start_pos.x, 0, dummy_player.position.z - start_pos.z)
	var to_player_end := Vector3(dummy_player.position.x - end_pos.x, 0, dummy_player.position.z - end_pos.z)
	_check(to_player_end.length() < to_player_start.length() - 0.01,
		"enemy drifted toward player (dist %.1f → %.1f)" % [to_player_start.length(), to_player_end.length()])

	# === 测试 3：CHASE 全速（玩家在 chase_range 内，enemy 有移动）===
	dummy_player.position = Vector3(20, 0, 0)  # dist ≈ 20 < chase_range(70)
	enemy.set("position", Vector3(0, 4, 0))
	start_pos = enemy.get("position")

	# 推进更多帧让 lerp 平滑移动累积可观位移
	for _i in range(30):
		await get_tree().process_frame
	end_pos = enemy.get("position")

	var moved := Vector2(end_pos.x - start_pos.x, end_pos.z - start_pos.z).length()
	_check(moved > 0.005, "CHASE range: enemy moved (%.3f units over 30 frames)" % moved)

	await get_tree().process_frame

	if failures == 0:
		print("[TEST] PASS — enemy flying dual speed")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
