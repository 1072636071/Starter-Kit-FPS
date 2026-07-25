## Issue 15 测试：ChargedShot 模块 — 触发 ATTACK → 1.2s 蓄力后射出 1 发，伤害 3 倍
## 运行：godot --headless --path . res://tests/test_module_charged_shot.tscn --quit-after 30
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
	var monster: CharacterBody3D = preload("res://objects/monster_ranged.tscn").instantiate()
	add_child(monster)

	var original_damage: float = float(monster.attack_damage)

	# 挂载 ChargedShot 模块
	var charged_script: Script = preload("res://scripts/modules/module_charged_shot.gd")
	var charged: Node = Node.new()
	charged.set_script(charged_script)
	charged.charge_time = 1.2
	charged.charged_damage_mult = 3.0
	monster.add_child(charged)

	var root_children_before: int = get_tree().root.get_child_count()

	# 触发 ATTACK 状态
	monster._change_state(monster.AIState.ATTACK)

	# 断言：蓄力期间 _desired_velocity 为 0
	charged.on_tick(0.016)
	_check(monster._desired_velocity == Vector3.ZERO,
		"_desired_velocity == Vector3.ZERO during charge")

	# 断言：0.5s 内不应有弹体（蓄力中）
	await get_tree().create_timer(0.5).timeout
	var mid_children: int = get_tree().root.get_child_count() - root_children_before
	_check(mid_children == 0,
		"no projectiles during charge (got %d)" % mid_children)

	# 等待超过 charge_time（1.2s + margin）
	await get_tree().create_timer(0.9).timeout

	# 此时应有 1 发弹体
	var final_children: int = get_tree().root.get_child_count() - root_children_before
	_check(final_children >= 1,
		"at least 1 projectile after charge (got %d)" % final_children)

	# 断言：伤害已恢复
	_check(abs(float(monster.attack_damage) - original_damage) < 0.01,
		"attack_damage restored to original after charged shot (got %.2f, expected %.2f)" % [float(monster.attack_damage), original_damage])

	# 断言：蓄力结束 _charging = false
	_check(bool(charged.get("_charging")) == false,
		"_charging == false after shot")

	monster.queue_free()

	if failures == 0:
		print("[TEST] PASS — issue 15 ChargedShot module")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
