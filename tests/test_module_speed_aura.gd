## Issue 14 测试：SpeedAura 模块 — 10m 内友方移速×1.2，离开恢复
## 运行：godot --headless --path . res://tests/test_module_speed_aura.tscn --quit-after 30
extends Node3D

var failures: int = 0


func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1


func _ready() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	# 创建两只怪物，均加入 "enemy" group
	var monster_a: CharacterBody3D = preload("res://objects/monster_melee.tscn").instantiate()
	monster_a.add_to_group("enemy")
	add_child(monster_a)
	monster_a.global_position = Vector3(0.0, 0.5, 0.0)

	var monster_b: CharacterBody3D = preload("res://objects/monster_melee.tscn").instantiate()
	monster_b.add_to_group("enemy")
	add_child(monster_b)
	monster_b.global_position = Vector3(5.0, 0.5, 0.0)  # 5m 距离，在 10m 范围内

	# 记录 monster_b 原始移速
	var original_speed_b: float = float(monster_b.move_speed)

	# 在 monster_a 上挂 SpeedAura
	var aura_script: Script = preload("res://scripts/modules/module_speed_aura.gd")
	var aura: Node = Node.new()
	aura.set_script(aura_script)
	aura.aura_radius = 10.0
	aura.speed_mult = 1.2
	monster_a.add_child(aura)

	# 驱动 on_tick
	aura.on_tick(0.016)

	# 断言 monster_b 移速变为 1.2 倍
	var expected_speed: float = original_speed_b * 1.2
	_check(abs(float(monster_b.move_speed) - expected_speed) < 0.01,
		"monster_b move_speed buffed to %.2f (expected %.2f)" % [float(monster_b.move_speed), expected_speed])

	# 检查 _buffed_enemies 记录了 monster_b
	var buffed: Dictionary = aura.get("_buffed_enemies")
	_check(buffed.has(monster_b.get_instance_id()), "_buffed_enemies contains monster_b id")

	# 移出范围（monster_b 移到 15m 外）
	monster_b.global_position = Vector3(15.0, 0.5, 0.0)
	aura.on_tick(0.016)

	# 断言恢复
	_check(abs(float(monster_b.move_speed) - original_speed_b) < 0.01,
		"monster_b move_speed restored to %.2f (got %.2f)" % [original_speed_b, float(monster_b.move_speed)])
	_check(buffed.is_empty(), "_buffed_enemies empty after leaving range")

	monster_a.queue_free()
	monster_b.queue_free()

	if failures == 0:
		print("[TEST] PASS — issue 14 SpeedAura module")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
