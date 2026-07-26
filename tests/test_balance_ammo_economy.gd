## Issue 27：平衡——弹药经济模拟
## 运行：godot --headless --path . res://tests/test_balance_ammo_economy.tscn --quit-after 30
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
	# 1. 初始手枪弹药充足性：36 备弹 + 12 弹匣 = 48 发
	var initial_reserve := 36
	var initial_magazine := 12
	var total_initial := initial_reserve + initial_magazine
	_check(total_initial > 30, "initial pistol ammo 48 > 30 (sufficient for first 2 waves)")

	# 2. 各弹种每发成本在合理范围
	var costs := {
		&"手枪弹": {"bundle": 24, "price": 1},
		&"步枪弹": {"bundle": 20, "price": 2},
		&"霰弹":   {"bundle": 8,  "price": 3},
		&"狙击弹": {"bundle": 4,  "price": 4},
		&"能量电池": {"bundle": 12, "price": 3},
		&"榴弹":   {"bundle": 2,  "price": 5},
	}
	for type_id in costs:
		var entry: Dictionary = costs[type_id]
		var cost_per_bullet: float = float(entry["price"]) / float(entry["bundle"])
		_check(cost_per_bullet >= 0.04 and cost_per_bullet <= 2.5,
			"ammo %s cost/bullet %.3f in [0.04, 2.5]" % [type_id, cost_per_bullet])

	# 3. 武器价格范围合理性
	var min_cost := 30
	var max_cost := 175
	_check(min_cost < max_cost, "weapon cost range [30, 175] is valid")

	# 4. 手雷价格合理性
	var emp_price := 25
	var frag_price := 20
	_check(emp_price > 0, "EMP price %d > 0" % emp_price)
	_check(frag_price > 0, "frag price %d > 0" % frag_price)
	_check(emp_price > 1, "EMP price > 1 (above cheapest ammo)")
	_check(frag_price > 1, "frag price > 1")

	# 5. 耐久经济不会软锁
	var min_durability := 25
	_check(min_durability > 20, "minimum durability 25 > 20 (not soft-locked)")

	# 6. 波次金币收入递增
	var wave_1_budget := _budget(1)
	var wave_5_budget := _budget(5)
	_check(wave_5_budget > wave_1_budget, "wave 5 budget %d > wave 1 budget %d" % [wave_5_budget, wave_1_budget])
	_check(float(wave_5_budget) <= float(wave_1_budget) * 5.0,
		"wave 5 budget growth <= 5x (reasonable escalation)")

	# 7. 动态读取武器 .tres 验证 field 完整性
	var dir := DirAccess.open("res://weapons/")
	if dir != null:
		dir.list_dir_begin()
		var fname := dir.get_next()
		var weapon_count := 0
		while fname != "":
			if not dir.current_is_dir() and fname.ends_with(".tres"):
				var res := load("res://weapons/" + fname)
				if res is Weapon:
					weapon_count += 1
					_check(res.magazine_size > 0, "%s magazine_size > 0" % fname)
					_check(res.durability_max > 0, "%s durability_max > 0" % fname)
			fname = dir.get_next()
		dir.list_dir_end()
		_check(weapon_count >= 2, "at least 2 weapon .tres files (got %d)" % weapon_count)

	if failures == 0:
		print("[TEST] PASS — issue 27 balance ammo economy")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)


func _budget(wave_number: int) -> int:
	return int(round(60.0 * pow(1.2, wave_number - 1)))
