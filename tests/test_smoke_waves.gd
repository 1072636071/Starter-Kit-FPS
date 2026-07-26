## Issue 26：集成烟雾测试 — 波次 1–15 预算/构成/spawn 无崩溃
## 运行：godot --headless --path . res://tests/test_smoke_waves.tscn --quit-after 60
extends Node3D

var failures: int = 0
var _counters: Dictionary = {}

func _ready() -> void:
	call_deferred("_run_tests")

func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1

func _run_tests() -> void:
	# 创建 RunDirector
	var rd := preload("res://scripts/run_director.gd").new()
	rd.rng_seed = 42
	rd.monsters_parent = self
	rd.spawn_points = []
	add_child(rd)

	# 创建出生点（多个避免 spawn 警告）
	for i in 6:
		var sp := Marker3D.new()
		add_child(sp)
		sp.global_position = Vector3(i * 3.0, 0.5, 0)
		rd.spawn_points.append(sp)

	# 1. 验证波次预算公式：60 × 1.2^(N-1)
	var expected_budgets := {
		1: 60, 2: 72, 3: 86, 4: 104, 5: 124,
		6: 149, 7: 179, 8: 215, 9: 258, 10: 310,
		11: 372, 12: 446, 13: 535, 14: 642, 15: 770,
	}
	for wave_num: int in expected_budgets:
		var actual := rd.wave_budget(wave_num)
		var expected: int = expected_budgets[wave_num]
		_check(actual == expected,
			"wave_budget(%d) = %d (expected %d)" % [wave_num, actual, expected])

	# 2. 逐波验证构成 + spawn 不崩溃
	var total_spawned := 0
	for wave_num in range(1, 16):
		var budget := rd.wave_budget(wave_num)
		var available := rd._available_types(wave_num)
		_check(available.size() > 0,
			"wave %d available_types non-empty (got %d)" % [wave_num, available.size()])

		var comp: Array = rd.compute_wave_composition(wave_num)
		_check(comp.size() > 0,
			"wave %d composition non-empty (got %d types)" % [wave_num, comp.size()])

		# 计算总成本 ≥ 预算
		var total_cost := 0
		for t in comp:
			total_cost += int(rd.ENEMY_CONFIG[t]["cost"])
		_check(total_cost >= budget,
			"wave %d total_cost %d >= budget %d" % [wave_num, total_cost, budget])

		# 构成中所有类型均在可用列表中
		var all_valid := true
		for t in comp:
			if not available.has(t):
				all_valid = false
				print("  WARN: wave %d has type %s not in available" % [wave_num, t])
		_check(all_valid, "wave %d all types in available" % wave_num)

		# spawn_all 不崩溃
		rd.set("_wave_active", true)
		rd.alive_count = comp.size()
		rd._spawn_all(comp)
		total_spawned += comp.size()

		# 清理所有已生成的怪物
		for c in get_children():
			if c is Node3D and c.has_method("destroy") and c != rd and not (c is Marker3D):
				if "_dead" in c:
					c.set("_dead", false)
				c.destroy()
		# 等一帧让 queue_free 生效
		await get_tree().process_frame
		# 强制清理残余
		for c in get_children():
			if c is Node3D and c.has_method("destroy") and c != rd and not (c is Marker3D):
				c.queue_free()
		await get_tree().process_frame

	_check(total_spawned > 0, "total spawned across 15 waves = %d (expected > 0)" % total_spawned)

	# 3. 验证波次解锁规则
	_check(rd._available_types(1).has(&"monster_melee"), "wave 1 has melee")
	_check(not rd._available_types(1).has(&"monster_ranged"), "wave 1 no ranged")
	_check(not rd._available_types(1).has(&"enemy"), "wave 1 no enemy")

	_check(rd._available_types(4).has(&"monster_ranged"), "wave 4 has ranged")
	_check(not rd._available_types(4).has(&"enemy"), "wave 4 no enemy")

	_check(rd._available_types(7).has(&"enemy"), "wave 7 has enemy")
	_check(rd._available_types(15).size() == 3, "wave 15 all 3 types available (got %d)" % rd._available_types(15).size())

	rd.queue_free()

	if failures == 0:
		print("[TEST] PASS — issue 26 smoke waves")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
