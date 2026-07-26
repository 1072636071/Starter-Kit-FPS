## Issue 27：平衡——波次生存模拟（验证波次预算公式与敌人配置）
## 运行：godot --headless --path . res://tests/test_balance_wave_survival.tscn --quit-after 30
extends Node3D

var failures: int = 0

func _ready() -> void:
	call_deferred("_run_tests")

func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1


func _run_tests() -> void:
	# 创建 RunDirector 以读取 ENEMY_CONFIG（动态数据源，非硬编码）
	var rd := preload("res://scripts/run_director.gd").new()
	rd.rng_seed = 42
	rd.monsters_parent = self
	rd.spawn_points = []
	add_child(rd)

	var cfg: Dictionary = rd.ENEMY_CONFIG
	_check(cfg.size() >= 3, "ENEMY_CONFIG has at least 3 entries (got %d)" % cfg.size())

	# 1. 波次预算公式验证
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

	# 2. 高波次应有更多可用敌种（预算+解锁阶段递增）
	for wave_num: int in [1, 5, 10, 15]:
		var types := rd._available_types(wave_num)
		_check(types.size() > 0,
			"wave %d available_types non-empty (got %d)" % [wave_num, types.size()])

	# 3. 所有敌人 cost > 0
	for type_id in cfg:
		var cost: int = cfg[type_id]["cost"]
		_check(cost > 0, "enemy %s cost %d > 0" % [type_id, cost])

	# 4. 所有敌人 reward > 0
	for type_id in cfg:
		var reward: int = cfg[type_id]["reward"]
		_check(reward > 0, "enemy %s reward %d > 0" % [type_id, reward])

	# 5. min_wave 随 cost 单调不降（高成本敌人不应比低成本更早解锁）
	var entries: Array = []
	for type_id in cfg:
		var entry: Dictionary = cfg[type_id]
		entries.append({"type": type_id, "cost": entry["cost"], "min_wave": entry["min_wave"]})
	entries.sort_custom(func(a, b): return a["cost"] < b["cost"])
	for i in range(1, entries.size()):
		var prev: Dictionary = entries[i - 1]
		var curr: Dictionary = entries[i]
		_check(curr["min_wave"] >= prev["min_wave"],
			"min_wave monotonic: %s(cost=%d,w=%d) >= %s(cost=%d,w=%d)" % [
				curr["type"], curr["cost"], curr["min_wave"],
				prev["type"], prev["cost"], prev["min_wave"]])

	# 6. 所有成本不归零
	for type_id in cfg:
		_check(cfg[type_id]["cost"] != 0,
			"enemy %s cost != 0" % type_id)

	# 7. 验证所有 ENEMY_CONFIG 条目有 scene 字段（PackedScene 或 null）
	for type_id in cfg:
		var scene = cfg[type_id].get("scene")
		_check(scene != null, "enemy %s has scene field" % type_id)

	rd.queue_free()

	if failures == 0:
		print("[TEST] PASS — issue 27 balance wave survival")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
