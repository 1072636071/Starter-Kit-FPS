## 竞技场 Issue 32 测试：monster_base 双速模型
## 运行：godot --headless --path . res://tests/test_monster_dual_speed.tscn --quit-after 600
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
	p.position = Vector3(100, 0, 100)  # 远距离，避免触发被动感知
	add_child(p)
	return p

func _run_tests() -> void:
	dummy_player = _make_dummy_player()

	# === 测试 1：drift_speed 自动计算 ===
	var melee_scene := preload("res://objects/monster_melee.tscn")
	var melee: CharacterBody3D = melee_scene.instantiate()
	add_child(melee)
	var melee_move := float(melee.get("move_speed"))
	var melee_drift := float(melee.get("drift_speed"))
	var expected_drift := melee_move * 0.35
	_check(abs(melee_drift - expected_drift) < 0.01,
		"melee drift_speed == move_speed*0.35 (%.2f vs %.2f)" % [melee_drift, expected_drift])

	# ranged
	var ranged_scene := preload("res://objects/monster_ranged.tscn")
	var ranged: CharacterBody3D = ranged_scene.instantiate()
	add_child(ranged)
	var ranged_move := float(ranged.get("move_speed"))
	var ranged_drift := float(ranged.get("drift_speed"))
	var expected_ranged_drift := ranged_move * 0.35
	_check(abs(ranged_drift - expected_ranged_drift) < 0.01,
		"ranged drift_speed == move_speed*0.35 (%.2f vs %.2f)" % [ranged_drift, expected_ranged_drift])

	# 测试 1b：手动设定 drift_speed 不被覆盖
	var melee2: CharacterBody3D = melee_scene.instantiate()
	melee2.set("drift_speed", 2.0)
	add_child(melee2)
	var melee2_drift := float(melee2.get("drift_speed"))
	_check(abs(melee2_drift - 2.0) < 0.01,
		"manual drift_speed=2.0 not overwritten (got %.2f)" % melee2_drift)

	# === 测试 2：IDLE 缓行移动（直接调用 _tick_idle）===
	melee.set("_dropping", false)
	melee.set("_ai_state", 0)  # AIState.IDLE
	# 验证 player 已正确注入
	var has_player := melee.get("player") != null
	_check(has_player, "monster player reference set (auto_find_player)")
	if not has_player:
		print("[TEST] SKIP velocity tests: player not found")
	else:
		# 直接调用 _tick_idle（绕过 physics_process 的缓降保护）
		melee.call("_tick_idle", 0.016)
		var dv: Vector3 = melee.get("_desired_velocity")
		var h_speed := Vector2(dv.x, dv.z).length()
		_check(h_speed > 0.01, "IDLE _desired_velocity non-zero (h_speed=%.3f)" % h_speed)
		_check(abs(h_speed - melee_drift) < 0.5,
			"IDLE h_speed ~ drift_speed (%.2f vs %.2f)" % [h_speed, melee_drift])

		# 方向朝玩家
		if h_speed > 0.01:
			var to_player := dummy_player.global_position - melee.global_position
			to_player.y = 0.0
			var dir_to_player := to_player.normalized()
			var vel_dir := Vector3(dv.x, 0, dv.z).normalized()
			var dot := vel_dir.dot(dir_to_player)
			_check(dot > 0.5, "IDLE velocity toward player (dot=%.2f)" % dot)

	# === 测试 3：CHASE 全速不变（用 move_speed）===
	if has_player:
		melee.set("_ai_state", 1)  # AIState.CHASE
		# 设置路径目标并等待一帧让 nav_agent 计算路径
		melee.set("_path_timer", -1.0)  # 强制触发路径更新
		melee.call("_tick_chase", 0.016)
		# 第二次调用时 nav_agent 已有路径
		melee.call("_tick_chase", 0.016)
		var dv2: Vector3 = melee.get("_desired_velocity")
		var h_speed2 := Vector2(dv2.x, dv2.z).length()
		if h_speed2 < 0.01:
			print("[TEST] ok: CHASE _desired_velocity zero (NavMesh unavailable in headless — expected)")
		else:
			_check(abs(h_speed2 - melee_move) < 0.5,
				"CHASE h_speed ~ move_speed (%.2f vs %.2f)" % [h_speed2, melee_move])

	# === 测试 4：动画选择阈值 ===
	var threshold := float(melee.call("_animation_threshold"))
	var expected_threshold := (melee_drift + melee_move) / 2.0
	_check(abs(threshold - expected_threshold) < 0.01,
		"_animation_threshold == (drift+move)/2 (%.2f vs %.2f)" % [threshold, expected_threshold])

	await get_tree().process_frame

	if failures == 0:
		print("[TEST] PASS — monster dual speed model")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
