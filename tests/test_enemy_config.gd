## Issue 09 测试：RunDirector ENEMY_CONFIG 数据驱动刷怪（ADR 022）
## 验证：配置表结构（cost/reward/min_wave/scene）、按 min_wave 解锁、
##       波次构成与奖励值全部经由配置表驱动，且行为与旧硬编码一致。
## 运行：godot --headless --path . res://tests/test_enemy_config.tscn --quit-after 30
extends Node3D

var failures: int = 0
var rd: Node = null

func _ready() -> void:
	call_deferred("_run_tests")

func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1

func _check_entry(type: StringName, cost: int, reward: int, min_wave: int) -> void:
	var cfg: Dictionary = rd.ENEMY_CONFIG
	_check(cfg.has(type), "ENEMY_CONFIG has %s" % type)
	if not cfg.has(type):
		return
	var e: Dictionary = cfg[type]
	_check(int(e.get("cost", -1)) == cost, "%s cost = %d (got %s)" % [type, cost, str(e.get("cost"))])
	_check(int(e.get("reward", -1)) == reward, "%s reward = %d (got %s)" % [type, reward, str(e.get("reward"))])
	_check(int(e.get("min_wave", -1)) == min_wave, "%s min_wave = %d (got %s)" % [type, min_wave, str(e.get("min_wave"))])
	var scene = e.get("scene")
	_check(scene is PackedScene, "%s scene is PackedScene" % type)
	if scene is PackedScene:
		_check(scene.can_instantiate(), "%s scene can instantiate" % type)

func _run_tests() -> void:
	rd = preload("res://scripts/run_director.gd").new()
	rd.rng_seed = 1
	add_child(rd)  # 入树触发 _ready（rng 初始化）

	# 1. 配置表初始含 3 种敌人（issue 10–14 追加其余 13 种）
	var cfg: Dictionary = rd.ENEMY_CONFIG
	_check(cfg.size() == 3, "ENEMY_CONFIG has 3 entries initially (got %d)" % cfg.size())

	# 2. 每个条目结构完整、数值与旧硬编码一致
	_check_entry(&"monster_melee", 5, 5, 1)
	_check_entry(&"monster_ranged", 8, 8, 4)
	_check_entry(&"enemy", 10, 10, 7)

	# 3. min_wave 解锁规则与旧行为一致：1–3 仅近战、4–6 加远程、7+ 全类型
	_check(rd._available_types(1) == [&"monster_melee"], "wave 1 → melee only")
	_check(rd._available_types(3) == [&"monster_melee"], "wave 3 → melee only")
	_check(rd._available_types(4) == [&"monster_melee", &"monster_ranged"], "wave 4 → +ranged")
	_check(rd._available_types(6) == [&"monster_melee", &"monster_ranged"], "wave 6 → +ranged")
	_check(rd._available_types(7) == [&"monster_melee", &"monster_ranged", &"enemy"], "wave 7 → all types")

	# 4. 波次构成经配置表 cost 驱动：wave 1 预算 60 / 近战 cost 5 = 12 只全近战
	var comp: Array = rd.compute_wave_composition(1)
	_check(comp.size() == 12, "wave 1 composition = 12 monsters (got %d)" % comp.size())
	var all_melee := true
	for t in comp:
		if t != &"monster_melee":
			all_melee = false
	_check(all_melee, "wave 1 composition all monster_melee")

	# 5. 奖励经配置表 reward 驱动
	_check(rd._reward_for(&"monster_melee") == 5, "reward melee = 5")
	_check(rd._reward_for(&"monster_ranged") == 8, "reward ranged = 8")
	_check(rd._reward_for(&"enemy") == 10, "reward enemy = 10")
	_check(rd._reward_for(&"nonexistent") == 0, "reward unknown type = 0")

	# 6. ENEMY_CONFIG 场景可实例化（scene 字段为有效怪物场景）
	for type in cfg:
		var inst = cfg[type]["scene"].instantiate()
		_check(inst != null, "%s scene instantiates" % type)
		inst.free()

	rd.queue_free()

	if failures == 0:
		print("[TEST] PASS — issue 09 ENEMY_CONFIG data-driven spawning")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
