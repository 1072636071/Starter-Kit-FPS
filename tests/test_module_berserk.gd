extends Node
## Issue 13：BerserkOnDamage 模块测试
## 验证：触发伤害 → move_speed 和 damage_multiplier 变为乘后值，3s 后恢复

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
	# 创建假 enemy，带 move_speed 和 damage_multiplier
	var enemy := _make_fake_enemy()
	add_child(enemy)

	var mod := load("res://scripts/modules/module_berserk_on_damage.gd").new()
	mod.name = "BerserkOnDamage"
	enemy.add_child(mod)
	mod.module_setup(enemy)

	# 记录原始值
	var orig_speed: float = enemy.get("move_speed")
	var orig_dmg_mult: float = enemy.get("damage_multiplier")

	_check(orig_speed == 3.0, "original speed = 3.0")
	_check(orig_dmg_mult == 1.0, "original damage_multiplier = 1.0")

	# 触发伤害 → 狂暴
	mod.on_damage(10.0)

	# 断言属性变化
	var berserk_speed: float = enemy.get("move_speed")
	var berserk_dmg: float = enemy.get("damage_multiplier")
	_check(abs(berserk_speed - orig_speed * 1.3) < 0.01, "speed multiplied by 1.3: %.1f (expected %.1f)" % [berserk_speed, orig_speed * 1.3])
	_check(abs(berserk_dmg - orig_dmg_mult * 1.5) < 0.01, "damage_multiplier × 1.5: %.1f (expected %.1f)" % [berserk_dmg, orig_dmg_mult * 1.5])

	# 等待 3s 狂暴结束后恢复
	await get_tree().create_timer(3.1).timeout

	var restored_speed: float = enemy.get("move_speed")
	var restored_dmg: float = enemy.get("damage_multiplier")
	_check(abs(restored_speed - orig_speed) < 0.01, "speed restored after 3s: %.1f (expected %.1f)" % [restored_speed, orig_speed])
	_check(abs(restored_dmg - orig_dmg_mult) < 0.01, "damage_multiplier restored after 3s: %.1f (expected %.1f)" % [restored_dmg, orig_dmg_mult])

	# 冷却期间再次触发 → 不应再次狂暴
	enemy.set("move_speed", orig_speed)
	enemy.set("damage_multiplier", orig_dmg_mult)
	mod.on_damage(10.0)

	# 冷却中，属性不应改变
	var during_cd_speed: float = enemy.get("move_speed")
	_check(abs(during_cd_speed - orig_speed) < 0.01, "no berserk during cooldown (speed unchanged: %.1f)" % during_cd_speed)

	# 清理
	enemy.queue_free()
	await get_tree().process_frame

	if failures == 0:
		print("[TEST] PASS — module_berserk")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)


func _make_fake_enemy() -> Node3D:
	var enemy := CharacterBody3D.new()
	enemy.name = "FakeEnemy_Berserk"
	enemy.add_to_group("enemy")

	var s := GDScript.new()
	s.source_code = """extends CharacterBody3D
var move_speed: float = 3.0
var damage_multiplier: float = 1.0
"""
	s.reload()
	enemy.set_script(s)
	return enemy
