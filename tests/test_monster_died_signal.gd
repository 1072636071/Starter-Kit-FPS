## 竞技场 Issue 03 测试：三种怪物 died(monster_type) 信号 + _dead 守卫
## 运行：godot --headless --path . res://tests/test_monster_died_signal.tscn --quit-after 600
## 判定：[TEST] PASS 即通过；任何 [TEST] FAIL 即失败（脚本自行 quit(1)）
extends Node

var failures: int = 0
var _counters: Dictionary = {}
var _received_type: Dictionary = {}

func _ready():
	call_deferred("_run_tests")

func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1

## 提供一个在 "player" 组里的 Node3D，供 enemy._process / 怪物 _auto_find_player 使用
func _make_dummy_player() -> Node3D:
	var p := Node3D.new()
	p.add_to_group("player")
	p.position = Vector3(10, 0, 10)
	add_child(p)
	return p

func _run_tests() -> void:
	var dummy_player := _make_dummy_player()

	# === monster_melee ===
	var melee_scene := preload("res://objects/monster_melee.tscn")
	var melee: CharacterBody3D = melee_scene.instantiate()
	add_child(melee)
	_check(str(melee.get("MONSTER_TYPE")) == "monster_melee",
		"monster_melee MONSTER_TYPE == monster_melee (got %s)" % str(melee.get("MONSTER_TYPE")))
	_check(melee.has_signal("died"), "monster_melee has died signal")
	_counters["melee"] = 0
	_received_type["melee"] = &""
	melee.died.connect(func(t: StringName):
		_counters["melee"] += 1
		_received_type["melee"] = t
	)
	melee.damage(9999.0)
	_check(int(_counters["melee"]) == 1, "monster_melee died emitted once on lethal (got %d)" % int(_counters["melee"]))
	_check(_received_type["melee"] == &"monster_melee",
		"monster_melee died carries &monster_melee (got %s)" % str(_received_type["melee"]))
	_check(bool(melee.get("_dead")) == true, "monster_melee _dead set true")
	# 再次 lethal 不应再发（destroy 重入守卫；注意 die 动画期间延迟 queue_free 仍在树）
	melee.damage(9999.0)
	_check(int(_counters["melee"]) == 1, "monster_melee died NOT re-emitted (got %d)" % int(_counters["melee"]))

	# === monster_ranged ===
	var ranged_scene := preload("res://objects/monster_ranged.tscn")
	var ranged: CharacterBody3D = ranged_scene.instantiate()
	add_child(ranged)
	_check(str(ranged.get("MONSTER_TYPE")) == "monster_ranged",
		"monster_ranged MONSTER_TYPE == monster_ranged (got %s)" % str(ranged.get("MONSTER_TYPE")))
	_check(ranged.has_signal("died"), "monster_ranged has died signal")
	_counters["ranged"] = 0
	_received_type["ranged"] = &""
	ranged.died.connect(func(t: StringName):
		_counters["ranged"] += 1
		_received_type["ranged"] = t
	)
	ranged.damage(9999.0)
	_check(int(_counters["ranged"]) == 1, "monster_ranged died emitted once on lethal (got %d)" % int(_counters["ranged"]))
	_check(_received_type["ranged"] == &"monster_ranged",
		"monster_ranged died carries &monster_ranged (got %s)" % str(_received_type["ranged"]))

	# === enemy（飞行，Node3D，独立脚本）===
	var enemy_scene := preload("res://objects/enemy.tscn")
	var enemy: Node3D = enemy_scene.instantiate()
	# enemy._process / _on_timer_timeout 直接访问 player，必须先注入避免崩溃
	enemy.set("player", dummy_player)
	add_child(enemy)
	_check(str(enemy.get("MONSTER_TYPE")) == "enemy",
		"enemy MONSTER_TYPE == enemy (got %s)" % str(enemy.get("MONSTER_TYPE")))
	_check(enemy.has_signal("died"), "enemy has died signal")
	_counters["enemy"] = 0
	_received_type["enemy"] = &""
	enemy.died.connect(func(t: StringName):
		_counters["enemy"] += 1
		_received_type["enemy"] = t
	)
	enemy.damage(9999.0)
	_check(int(_counters["enemy"]) == 1, "enemy died emitted once on lethal (got %d)" % int(_counters["enemy"]))
	_check(_received_type["enemy"] == &"enemy",
		"enemy died carries &enemy (got %s)" % str(_received_type["enemy"]))
	_check(bool(enemy.get("_dead")) == true, "enemy _dead set true")
	# enemy destroy 重入守卫：直接再调 destroy 不应再发信号
	enemy.call("destroy")
	_check(int(_counters["enemy"]) == 1, "enemy destroy re-entry does not re-emit died (got %d)" % int(_counters["enemy"]))

	# 等一帧让延迟 queue_free / 计时器不至于在 quit 前抛错
	await get_tree().process_frame

	if failures == 0:
		print("[TEST] PASS — arena issue 03 monster died(monster_type) signal")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
