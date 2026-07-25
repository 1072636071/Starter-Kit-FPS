## Issue 14 测试：DebuffAura 模块 — 玩家进入 5m 范围减速×0.7 + 攻速×0.8，离开恢复
## 运行：godot --headless --path . res://tests/test_module_debuff_aura.tscn --quit-after 30
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
	# 用 monster_melee 作为载体（任何 monster_base 子类均可）
	var monster: CharacterBody3D = preload("res://objects/monster_melee.tscn").instantiate()
	add_child(monster)

	# 创建 DebuffAura 模块并挂载
	var aura_script: Script = preload("res://scripts/modules/module_debuff_aura.gd")
	var aura: Node = Node.new()
	aura.set_script(aura_script)
	aura.aura_radius = 5.0
	aura.debuff_speed_mult = 0.7
	aura.debuff_damage_mult = 0.8
	monster.add_child(aura)

	# 创建简易玩家节点（需要 movement_speed, move_speed_bonus, damage_multiplier 字段）
	var player: Node3D = Node3D.new()
	player.set_script(_make_player_stub())
	player.movement_speed = 5.0
	player.move_speed_bonus = 0.0
	player.damage_multiplier = 1.0
	add_child(player)

	# 让怪物引用玩家
	monster.set("player", player)

	# 玩家放在怪物 3m 处（< 5m 范围）
	player.global_position = monster.global_position + Vector3(3.0, 0.0, 0.0)

	# 驱动 on_tick
	aura.on_tick(0.016)

	# 断言：移速变为 0.7 倍
	var expected_speed_bonus: float = (5.0 + 0.0) * 0.7 - 5.0  # 3.5 - 5.0 = -1.5
	_check(abs(float(player.move_speed_bonus) - expected_speed_bonus) < 0.01,
		"move_speed_bonus set to %.1f (expected %.1f)" % [float(player.move_speed_bonus), expected_speed_bonus])
	_check(abs(float(player.damage_multiplier) - 0.8) < 0.01,
		"damage_multiplier set to 0.8 (got %.2f)" % float(player.damage_multiplier))
	_check(bool(aura.get("_active")) == true, "aura _active == true")

	# 再次 tick 不应叠加
	var speed_after_second_tick: float = float(player.move_speed_bonus)
	aura.on_tick(0.016)
	_check(abs(float(player.move_speed_bonus) - speed_after_second_tick) < 0.001,
		"second tick does not re-apply debuff (no stacking)")

	# 玩家移出范围
	player.global_position = monster.global_position + Vector3(10.0, 0.0, 0.0)
	aura.on_tick(0.016)

	# 断言恢复
	_check(abs(float(player.move_speed_bonus) - 0.0) < 0.01,
		"move_speed_bonus restored to 0.0 (got %.2f)" % float(player.move_speed_bonus))
	_check(abs(float(player.damage_multiplier) - 1.0) < 0.01,
		"damage_multiplier restored to 1.0 (got %.2f)" % float(player.damage_multiplier))
	_check(bool(aura.get("_active")) == false, "aura _active == false after leaving")

	monster.queue_free()
	player.queue_free()

	if failures == 0:
		print("[TEST] PASS — issue 14 DebuffAura module")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)


## 为测试创建一个简单的 player stub，具有所需字段
func _make_player_stub() -> Script:
	var s := GDScript.new()
	s.source_code = """extends Node3D
var movement_speed: float = 5.0
var move_speed_bonus: float = 0.0
var damage_multiplier: float = 1.0
"""
	s.reload()
	return s
