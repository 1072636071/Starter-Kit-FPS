## Issue 26：集成烟雾测试 — 全武器 .tres 字段验证
## 运行：godot --headless --path . res://tests/test_smoke_weapons.tscn --quit-after 30
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

func _load_weapon_tres_files() -> Array:
	var pool: Array = []
	var dir := DirAccess.open("res://weapons/")
	if dir == null:
		return pool
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var res := load("res://weapons/" + fname)
			if res is Weapon:
				pool.append({"path": fname, "weapon": res})
		fname = dir.get_next()
	dir.list_dir_end()
	return pool

func _run_tests() -> void:
	var weapons := _load_weapon_tres_files()
	_check(weapons.size() >= 2, "weapons/ has at least 2 .tres files (got %d)" % weapons.size())

	for entry in weapons:
		var fname: String = entry["path"]
		var w: Weapon = entry["weapon"]

		# 关键字段非空/非零
		_check(w.display_name != null and w.display_name.length() > 0,
			"%s display_name = '%s'" % [fname, w.display_name])
		_check(w.ammo_type != null and String(w.ammo_type).length() > 0,
			"%s ammo_type = '%s'" % [fname, w.ammo_type])
		_check(w.weapon_cost > 0,
			"%s weapon_cost = %d (expected > 0)" % [fname, w.weapon_cost])
		_check(w.durability_max > 0,
			"%s durability_max = %d (expected > 0)" % [fname, w.durability_max])
		_check(w.magazine_size > 0,
			"%s magazine_size = %d (expected > 0)" % [fname, w.magazine_size])

		# 数值范围合理性检查
		_check(w.weapon_cost >= 30 and w.weapon_cost <= 175,
			"%s weapon_cost %d in [30, 175]" % [fname, w.weapon_cost])
		_check(w.durability_max >= 80 and w.durability_max <= 200,
			"%s durability_max %d in [80, 200]" % [fname, w.durability_max])

		# 弹药类型有效性
		var valid_ammo := [&"手枪弹", &"步枪弹", &"霰弹", &"狙击弹", &"能量电池", &"榴弹"]
		_check(valid_ammo.has(w.ammo_type),
			"%s ammo_type '%s' is valid" % [fname, w.ammo_type])

		# cooldown 和 damage
		_check(w.cooldown > 0.0,
			"%s cooldown = %.2f (expected > 0)" % [fname, w.cooldown])
		_check(w.damage > 0.0 or w.shot_count > 1,
			"%s damage=%.1f shot_count=%d (at least one > 0)" % [fname, w.damage, w.shot_count])

		# reliability_stars 范围
		_check(w.reliability_stars >= 1 and w.reliability_stars <= 3,
			"%s reliability_stars = %d (expected 1-3)" % [fname, w.reliability_stars])

		# role_title / role_features 非空
		_check(w.role_title != null and w.role_title.length() > 0,
			"%s role_title = '%s'" % [fname, w.role_title])

	# 验证 weapon_cost 与 ammo_type 的对应关系（已知武器的具体值检查）
	var blaster_found := false
	var repeater_found := false
	for entry in weapons:
		var w: Weapon = entry["weapon"]
		if w.display_name == "爆能枪":
			blaster_found = true
			_check(w.weapon_cost == 50, "blaster weapon_cost = 50 (got %d)" % w.weapon_cost)
			_check(w.durability_max == 120, "blaster durability_max = 120 (got %d)" % w.durability_max)
			_check(w.ammo_type == &"能量电池", "blaster ammo_type = 能量电池")
		if w.display_name == "连发枪":
			repeater_found = true
			_check(w.weapon_cost == 70, "blaster-repeater weapon_cost = 70 (got %d)" % w.weapon_cost)
			_check(w.durability_max == 100, "blaster-repeater durability_max = 100 (got %d)" % w.durability_max)
			_check(w.ammo_type == &"能量电池", "blaster-repeater ammo_type = 能量电池")

	_check(blaster_found, "blaster.tres found in weapons/")
	_check(repeater_found, "blaster-repeater.tres found in weapons/")

	if failures == 0:
		print("[TEST] PASS — issue 26 smoke weapons")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
