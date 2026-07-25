## Issue 11 测试：SummonPet 模块
## 运行：godot --headless --path . res://tests/test_module_summon_pet.tscn --quit-after 600
extends Node3D

var failures: int = 0


func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1


func _ready():
	call_deferred("_run_tests")


func _run_tests() -> void:
	var monster_scene: PackedScene = load("res://objects/monster_melee.tscn")
	var monster: Node3D = monster_scene.instantiate()
	add_child(monster)
	monster.global_position = Vector3(0.0, 0.0, 0.0)

	# 创建一个 dummy player
	var player := CharacterBody3D.new()
	player.name = "DummyPlayer"
	player.add_to_group("player")
	add_child(player)
	player.global_position = Vector3(10.0, 0.0, 0.0)

	await get_tree().process_frame

	var summon := preload("res://scripts/modules/module_summon_pet.gd").new()
	summon.pet_count = 3
	summon.pet_cooldown = 8.0
	summon.spawn_radius = 3.0
	monster.add_child(summon)
	summon.module_setup(monster)

	# 触发 CHASE 状态（AIState.CHASE = 1）
	monster._change_state(1)  # AIState.CHASE

	await get_tree().process_frame

	# 断言 3 只 pet spawned
	_check(summon._active_pets.size() == 3,
		"3 pets spawned (got %d)" % summon._active_pets.size())

	# 断言位置在宿主 2–3m 内
	for pet in summon._active_pets:
		if is_instance_valid(pet):
			var dist := (pet.global_position - monster.global_position).length()
			_check(dist >= 1.5 and dist <= 3.5,
				"pet distance %.2f in [1.5, 3.5]" % dist)

	# 模拟时间推进 5s（冷却内）→ 再次触发 CHASE 不应重复召唤
	# 重置 _last_spawn_time 为当前时间以模拟冷却
	summon._last_spawn_time = Time.get_ticks_msec() / 1000.0
	monster._change_state(1)  # 再次 CHASE

	await get_tree().process_frame

	# 冷却内（8s），不应再召唤
	_check(summon._active_pets.size() == 3,
		"no additional pets during cooldown (still %d)" % summon._active_pets.size())

	# 调用 destroy → on_death 清理所有 pets
	monster.destroy()

	await get_tree().process_frame

	for pet in summon._active_pets:
		_check(not is_instance_valid(pet) or pet.is_queued_for_deletion(),
			"pet queued for deletion after destroy()")

	if failures == 0:
		print("[TEST] PASS — issue 11 module_summon_pet")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
