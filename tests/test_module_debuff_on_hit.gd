## Issue 15 测试：DebuffOnHit 模块 — 弹体命中玩家 → 2s 内 damage_multiplier 降至 0.7 倍
## 运行：godot --headless --path . res://tests/test_module_debuff_on_hit.tscn --quit-after 30
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

	# 创建简易玩家 stub
	var player: Node3D = Node3D.new()
	player.set_script(_make_player_stub())
	player.damage_multiplier = 1.0
	player.add_to_group("player")
	add_child(player)

	# 挂载 DebuffOnHit 模块
	var debuff_script: Script = preload("res://scripts/modules/module_debuff_on_hit.gd")
	var debuff: Node = Node.new()
	debuff.set_script(debuff_script)
	debuff.debuff_mult = 0.7
	debuff.debuff_duration = 2.0
	monster.add_child(debuff)

	# 直接 emit projectile_hit_player 信号模拟弹体命中
	_check(monster.has_signal("projectile_hit_player"),
		"monster_ranged has projectile_hit_player signal")
	monster.projectile_hit_player.emit(player)

	# 断言：damage_multiplier 降至 0.7
	_check(abs(float(player.damage_multiplier) - 0.7) < 0.01,
		"player damage_multiplier = 0.7 after hit (got %.2f)" % float(player.damage_multiplier))

	# 等待 2.1s（超过 debuff_duration）后恢复
	await get_tree().create_timer(2.1).timeout
	_check(abs(float(player.damage_multiplier) - 1.0) < 0.01,
		"player damage_multiplier restored to 1.0 after 2s (got %.2f)" % float(player.damage_multiplier))

	# 测试重复命中：再次命中应再次施加 debuff
	player.damage_multiplier = 1.0
	monster.projectile_hit_player.emit(player)
	_check(abs(float(player.damage_multiplier) - 0.7) < 0.01,
		"second hit: damage_multiplier = 0.7 (got %.2f)" % float(player.damage_multiplier))

	monster.queue_free()
	player.queue_free()

	if failures == 0:
		print("[TEST] PASS — issue 15 DebuffOnHit module")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)


func _make_player_stub() -> Script:
	var s := GDScript.new()
	s.source_code = """extends Node3D
var damage_multiplier: float = 1.0
"""
	s.reload()
	return s
