## Issue 26：集成烟雾测试 — 全敌人 spawn / 方法 / 信号验证
## 运行：godot --headless --path . res://tests/test_smoke_enemies.tscn --quit-after 30
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
	# 创建 RunDirector 以读取 ENEMY_CONFIG
	var rd := preload("res://scripts/run_director.gd").new()
	rd.rng_seed = 1
	rd.monsters_parent = self
	rd.spawn_points = []
	add_child(rd)

	var cfg: Dictionary = rd.ENEMY_CONFIG
	_check(cfg.size() >= 3, "ENEMY_CONFIG has at least 3 entries (got %d)" % cfg.size())

	# 创建出生点
	var sp := Marker3D.new()
	add_child(sp)
	sp.global_position = Vector3(0, 0.5, 0)
	rd.spawn_points = [sp]

	# 逐个测试每个敌人类型
	for type in cfg:
		var entry: Dictionary = cfg[type]
		var scene: PackedScene = entry.get("scene")
		_check(scene is PackedScene, "%s scene is PackedScene" % type)
		if not (scene is PackedScene):
			continue
		_check(scene.can_instantiate(), "%s scene can instantiate" % type)

		# 实例化
		var inst: Node3D = scene.instantiate()
		_check(inst != null, "%s instantiate → non-null" % type)
		if inst == null:
			continue

		add_child(inst)
		inst.global_position = Vector3(0, 0.5, 0)

		# 验证必要方法
		_check(inst.has_method("damage"), "%s has method damage" % type)
		_check(inst.has_method("destroy"), "%s has method destroy" % type)

		# 验证必要信号
		_check(inst.has_signal("died"), "%s has signal died" % type)

		# 验证 destroy 不崩溃
		if inst.has_method("destroy"):
			# 先设 _dead 避免 destroy 内部跳过
			if "_dead" in inst:
				inst.set("_dead", false)
			inst.destroy()
			_check(true, "%s destroy() no crash" % type)

		# 清理
		if is_instance_valid(inst):
			inst.queue_free()

	# 验证 monster_melee 的 min_wave=1（波 1 可用）
	var avail_w1 := rd._available_types(1)
	_check(avail_w1.has(&"monster_melee"), "wave 1 available types includes monster_melee")

	# 验证 enemy 的 min_wave=7
	var avail_w6 := rd._available_types(6)
	_check(not avail_w6.has(&"enemy"), "wave 6 available types excludes enemy")
	var avail_w7 := rd._available_types(7)
	_check(avail_w7.has(&"enemy"), "wave 7 available types includes enemy")

	rd.queue_free()

	if failures == 0:
		print("[TEST] PASS — issue 26 smoke enemies")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
