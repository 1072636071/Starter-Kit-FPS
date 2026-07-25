## Issue 14 测试：HealAura 模块 — 8m 内友方回血 3HP/s，不超过 max_health
## 运行：godot --headless --path . res://tests/test_module_heal_aura.tscn --quit-after 30
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
	# 创建两只怪物，加入 "enemy" group
	var monster_a: CharacterBody3D = preload("res://objects/monster_melee.tscn").instantiate()
	monster_a.add_to_group("enemy")
	add_child(monster_a)
	monster_a.global_position = Vector3(0.0, 0.5, 0.0)

	var monster_b: CharacterBody3D = preload("res://objects/monster_melee.tscn").instantiate()
	monster_b.add_to_group("enemy")
	add_child(monster_b)
	monster_b.global_position = Vector3(3.0, 0.5, 0.0)  # 3m 距离，在 8m 范围内

	# 在 monster_a 上挂 HealAura
	var aura_script: Script = preload("res://scripts/modules/module_heal_aura.gd")
	var aura: Node = Node.new()
	aura.set_script(aura_script)
	aura.aura_radius = 8.0
	aura.heal_per_second = 3.0
	monster_a.add_child(aura)

	# 扣 monster_b 血量至 50
	var max_hp: float = float(monster_b.health)
	monster_b.set("health", 50.0)
	_check(abs(float(monster_b.health) - 50.0) < 0.01,
		"monster_b health set to 50 (got %.1f)" % float(monster_b.health))

	# 驱动 5 秒 on_tick（模拟：3 HP/s × 5s = 15 HP 恢复）
	var delta: float = 0.016
	var total_time: float = 5.0
	var elapsed: float = 0.0
	while elapsed < total_time:
		aura.on_tick(delta)
		elapsed += delta

	# 预期 50 + 15 = 65
	var expected_health: float = minf(50.0 + 3.0 * 5.0, max_hp)
	_check(abs(float(monster_b.health) - expected_health) < 1.5,
		"monster_b health ~%.0f after 5s heal (expected ~%.0f, got %.1f)" % [expected_health, expected_health, float(monster_b.health)])

	# 验证不超过 max_health：回满后再 tick 不应超
	monster_b.set("health", max_hp - 1.0)
	aura.on_tick(1.0)  # 一次 tick 1s，回 3 HP，但只差 1 HP
	_check(float(monster_b.health) <= max_hp + 0.01,
		"heal does not exceed max_health (got %.1f, max %.1f)" % [float(monster_b.health), max_hp])

	# 超出范围不应治疗
	monster_b.set("health", 30.0)
	monster_b.global_position = Vector3(20.0, 0.5, 0.0)  # 超出 8m
	aura.on_tick(5.0)
	_check(abs(float(monster_b.health) - 30.0) < 0.01,
		"out-of-range monster not healed (health stays 30, got %.1f)" % float(monster_b.health))

	monster_a.queue_free()
	monster_b.queue_free()

	if failures == 0:
		print("[TEST] PASS — issue 14 HealAura module")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
