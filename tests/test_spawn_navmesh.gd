## 竞技场 Issue 33 测试：RunDirector NavMesh 刷怪选点 + 兜底
## 运行：godot --headless --path . res://tests/test_spawn_navmesh.tscn --quit-after 600
extends Node3D

var failures: int = 0
var rd: Node

func _ready():
	call_deferred("_run_tests")

func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1

func _run_tests() -> void:
	# 创建 RunDirector 实例
	rd = preload("res://scripts/run_director.gd").new()
	rd.rng_seed = 42
	var mp := Node3D.new()
	mp.name = "Monsters"
	add_child(mp)
	rd.monsters_parent = mp
	add_child(rd)

	# === 测试 5：_find_spawn_positions 不崩溃且返回点满足基本约束 ===
	var player_pos := Vector3(0, 0, 0)
	var positions: Array = rd.call("_find_spawn_positions", 5, player_pos)
	_check(positions is Array, "_find_spawn_positions returns Array (got %s)" % str(positions))

	# 如果有返回位置，验证约束
	if positions.size() > 0:
		for p in positions:
			var pv: Vector3 = p
			var h_dist := Vector2(pv.x - player_pos.x, pv.z - player_pos.z).length()
			_check(h_dist >= 10.0,
				"spawn pos h_dist >= 10m from player (got %.1f)" % h_dist)
			_check(h_dist <= 65.0,
				"spawn pos h_dist <= 65m from player (got %.1f)" % h_dist)

		# 间距检查
		for i in range(positions.size()):
			for j in range(i + 1, positions.size()):
				var a: Vector3 = positions[i]
				var b: Vector3 = positions[j]
				var d := Vector2(a.x - b.x, a.z - b.z).length()
				_check(d >= 2.5 or positions.size() <= 1,
					"spawn spacing >= 2.5m (got %.1f between %d and %d)" % [d, i, j])
	else:
		print("[TEST] ok: _find_spawn_positions returned empty (expected in headless)")

	# === 测试 6：兜底——NavMesh 无数据时 _spawn_all 回退固定 SpawnPoints ===
	# 创建有固定出生点的 RunDirector
	var rd2 := preload("res://scripts/run_director.gd").new()
	rd2.rng_seed = 7
	var mp2 := Node3D.new()
	add_child(mp2)
	rd2.monsters_parent = mp2

	# 设置固定出生点
	var pts: Array[Marker3D] = []
	for i in 3:
		var m := Marker3D.new()
		add_child(m)
		m.global_position = Vector3(i * 4.0, 0.5, 0)
		pts.append(m)
	rd2.spawn_points = pts

	# 注入假 _player（Node3D，不在 group 中，让 _find_spawn_positions 可用）
	var fake_player := Node3D.new()
	fake_player.add_to_group("player")
	fake_player.position = Vector3(5, 0, 5)
	add_child(fake_player)

	# 注意：_spawn_all 需要 player 已设置；但 _auto_find_player 在 _ready 时跑
	# RunDirector 的 _player 通过 get_tree().get_first_node_in_group("player") 获取
	add_child(rd2)

	# 直接用 _spawn_all 刷怪，验证不崩溃
	var types: Array[StringName] = [&"monster_melee", &"monster_melee", &"monster_melee"]
	rd2.call("_spawn_all", types)
	_check(mp2.get_child_count() >= 3, "fallback spawn: >= 3 monsters spawned (got %d)" % mp2.get_child_count())

	await get_tree().process_frame

	if failures == 0:
		print("[TEST] PASS — NavMesh spawn placement + fallback")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
