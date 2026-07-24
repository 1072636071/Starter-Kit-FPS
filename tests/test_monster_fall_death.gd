## 竞技场 Issue 02 测试：怪物坠落死亡判定（position.y < -10 → destroy → died 信号）
## 运行：godot --headless --path . res://tests/test_monster_fall_death.tscn --quit-after 600
## 判定：[TEST] PASS 即通过；任何 [TEST] FAIL 即失败（脚本自行 quit(1)）
extends Node

var failures: int = 0
var _counters: Dictionary = {}
var _received_type: Dictionary = {}
var _dead_state: Dictionary = {}

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

	# === T1: monster_melee 坠落 → died 信号发射 ===
	var melee_scene := preload("res://objects/monster_melee.tscn")
	var melee: CharacterBody3D = melee_scene.instantiate()
	add_child(melee)
	_counters["melee"] = 0
	_received_type["melee"] = &""
	melee.died.connect(func(t: StringName):
		_counters["melee"] += 1
		_received_type["melee"] = t
	)
	# 设到坠落阈值以下
	melee.position = Vector3(0, -11, 0)
	# 等两帧确保 _physics_process 执行
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(int(_counters["melee"]) == 1, "monster_melee fall y=-11 → died emitted once (got %d)" % int(_counters["melee"]))
	_check(_received_type["melee"] == &"monster_melee", "monster_melee died carries &monster_melee (got %s)" % str(_received_type["melee"]))
	_check(bool(melee.get("_dead")) == true, "monster_melee _dead set true after fall")

	# === T2: monster_melee y=-9 → 不触发死亡 ===
	var melee_safe: CharacterBody3D = melee_scene.instantiate()
	add_child(melee_safe)
	_counters["melee_safe"] = 0
	melee_safe.died.connect(func(_t: StringName):
		_counters["melee_safe"] += 1
	)
	melee_safe.position = Vector3(0, -9, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(int(_counters["melee_safe"]) == 0, "monster_melee y=-9 → no death (got %d)" % int(_counters["melee_safe"]))
	_check(bool(melee_safe.get("_dead")) == false, "monster_melee y=-9 _dead still false")
	melee_safe.queue_free()

	# === T3: monster_ranged 坠落 → died 信号发射 ===
	var ranged_scene := preload("res://objects/monster_ranged.tscn")
	var ranged: CharacterBody3D = ranged_scene.instantiate()
	add_child(ranged)
	_counters["ranged"] = 0
	_received_type["ranged"] = &""
	ranged.died.connect(func(t: StringName):
		_counters["ranged"] += 1
		_received_type["ranged"] = t
	)
	ranged.position = Vector3(0, -11, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(int(_counters["ranged"]) == 1, "monster_ranged fall y=-11 → died emitted once (got %d)" % int(_counters["ranged"]))
	_check(_received_type["ranged"] == &"monster_ranged", "monster_ranged died carries &monster_ranged (got %s)" % str(_received_type["ranged"]))

	# === T4: enemy（飞行）坠落 → died 信号发射 ===
	var enemy_scene := preload("res://objects/enemy.tscn")
	var enemy: Node3D = enemy_scene.instantiate()
	enemy.set("player", dummy_player)
	add_child(enemy)
	_counters["enemy"] = 0
	_received_type["enemy"] = &""
	_dead_state["enemy"] = false
	enemy.died.connect(func(t: StringName):
		_counters["enemy"] += 1
		_received_type["enemy"] = t
		_dead_state["enemy"] = bool(enemy.get("_dead"))
	)
	# enemy 的 _process 会用 target_position 覆盖 position，必须设 target_position
	enemy.set("target_position", Vector3(0, -11, 0))
	enemy.position = Vector3(0, -11, 0)
	# enemy 用 _process 检测
	await get_tree().process_frame
	await get_tree().process_frame
	_check(int(_counters["enemy"]) == 1, "enemy fall y=-11 → died emitted once (got %d)" % int(_counters["enemy"]))
	_check(_received_type["enemy"] == &"enemy", "enemy died carries &enemy (got %s)" % str(_received_type["enemy"]))
	_check(_dead_state["enemy"] == true, "enemy _dead set true after fall")

	# === T5: enemy y=-9 → 不触发死亡 ===
	var enemy_safe: Node3D = enemy_scene.instantiate()
	enemy_safe.set("player", dummy_player)
	add_child(enemy_safe)
	_counters["enemy_safe"] = 0
	enemy_safe.died.connect(func(_t: StringName):
		_counters["enemy_safe"] += 1
	)
	enemy_safe.set("target_position", Vector3(0, -9, 0))
	enemy_safe.position = Vector3(0, -9, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(int(_counters["enemy_safe"]) == 0, "enemy y=-9 → no death (got %d)" % int(_counters["enemy_safe"]))
	_check(bool(enemy_safe.get("_dead")) == false, "enemy y=-9 _dead still false")
	enemy_safe.queue_free()

	# === T6: RunDirector 集成——坠落死亡正常结算奖励 + alive_count 递减 + 波次清场 ===
	var rd_scene := preload("res://scripts/run_director.gd")
	var rd: Node = Node.new()
	rd.set_script(rd_scene)
	# 配置 RunDirector
	var monsters_parent := Node3D.new()
	monsters_parent.name = "Monsters"
	add_child(monsters_parent)
	rd.set("monsters_parent", monsters_parent)
	# 提供出生点
	var sp_parent := Node3D.new()
	sp_parent.name = "SpawnPoints"
	add_child(sp_parent)
	var marker := Marker3D.new()
	marker.position = Vector3(0, 0.5, 0)
	sp_parent.add_child(marker)
	rd.set("spawn_points", [marker] as Array[Marker3D])
	rd.set("rng_seed", 42)  # 可复现
	add_child(rd)

	# 手动开波（wave 1 = 4 只 melee）
	_counters["wave_cleared"] = 0
	rd.wave_cleared.connect(func(_w: int, _t: bool):
		_counters["wave_cleared"] += 1
	)
	rd.start_next_wave()
	_check(rd.alive_count == 4, "wave 1 alive_count == 4 (got %d)" % rd.alive_count)

	# 将所有怪物移到坠落阈值以下
	for m in monsters_parent.get_children():
		if m is Node3D:
			m.position = Vector3(0, -11, 0)
	# 等物理帧让坠落检测触发
	await get_tree().physics_frame
	await get_tree().physics_frame  # 多等一帧确保全部处理

	_check(rd.alive_count == 0, "all fell → alive_count == 0 (got %d)" % rd.alive_count)
	_check(int(_counters["wave_cleared"]) == 1, "wave_cleared emitted once (got %d)" % int(_counters["wave_cleared"]))
	_check(rd.kills == 4, "kills == 4 after fall (got %d)" % rd.kills)
	_check(rd.gold == 20, "gold == 20 (4×5 melee reward) (got %d)" % rd.gold)

	# 等一帧让延迟 queue_free / 计时器不至于在 quit 前抛错
	await get_tree().process_frame

	if failures == 0:
		print("[TEST] PASS — arena issue 02 monster fall death")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
