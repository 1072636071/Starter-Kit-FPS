extends Node
## Issue 13：Shield 模块测试
## 验证：先扣盾再扣血；盾破后 shield_broken 信号发出
##
## Shield 与 monster_base.damage() 协作：
##   damage(amount) → hook on_damage(amount) → health -= amount
## Shield 在 on_damage 中吸收盾部分，把 enemy.health 加回 absorbed 量，
## 因此净效果 = 只扣溢出量。

var failures: int = 0
var _shield_broken_emitted: bool = false


func _ready() -> void:
	call_deferred("_run_tests")


func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1


func _run_tests() -> void:
	# === 测试 1：盾吸收全部伤害 ===
	var enemy1 := _make_fake_enemy()
	add_child(enemy1)

	var mod1 := load("res://scripts/modules/module_shield.gd").new()
	mod1.name = "Shield"
	enemy1.add_child(mod1)
	mod1.module_setup(enemy1)

	_check(mod1.shield_current == 60, "initial shield = 60 (got %d)" % mod1.shield_current)

	# 模拟 monster_base.damage(30) 的完整流程：
	# hook on_damage(30) → health -= 30
	enemy1.set("health", 100.0)
	mod1.on_damage(30.0)        # 盾吸收 30，health 补偿 +30
	enemy1.set("health", float(enemy1.get("health")) - 30.0)  # 基类扣 30

	_check(mod1.shield_current == 30, "shield reduced to 30 (got %d)" % mod1.shield_current)
	_check(float(enemy1.get("health")) == 100.0, "health unchanged when shield fully absorbs (got %.1f)" % float(enemy1.get("health")))

	# === 测试 2：盾部分吸收，溢出扣血 ===
	mod1.shield_broken.connect(func(): _shield_broken_emitted = true)

	mod1.on_damage(40.0)        # 盾吸收 30，health 补偿 +30
	enemy1.set("health", float(enemy1.get("health")) - 40.0)  # 基类扣 40

	_check(mod1.shield_current == 0, "shield depleted (got %d)" % mod1.shield_current)
	# 净效果：100 + 30(补偿) - 40(基类扣) = 90
	_check(float(enemy1.get("health")) == 90.0, "health reduced by overflow 10 → 90 (got %.1f)" % float(enemy1.get("health")))
	_check(_shield_broken_emitted == true, "shield_broken signal emitted")

	# === 测试 3：盾破后伤害全扣血 ===
	mod1.on_damage(20.0)        # 盾=0，不吸收，health 补偿 0
	enemy1.set("health", float(enemy1.get("health")) - 20.0)  # 基类扣 20

	_check(mod1.shield_current == 0, "shield stays 0 (got %d)" % mod1.shield_current)
	_check(float(enemy1.get("health")) == 70.0, "health reduced directly → 70 (got %.1f)" % float(enemy1.get("health")))

	# 清理
	enemy1.queue_free()
	await get_tree().process_frame

	if failures == 0:
		print("[TEST] PASS — module_shield")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)


func _make_fake_enemy() -> Node3D:
	var enemy := CharacterBody3D.new()
	enemy.name = "FakeEnemy_Shield"
	enemy.add_to_group("enemy")

	var s := GDScript.new()
	s.source_code = """extends CharacterBody3D
var health: float = 100.0
func damage(amount: float) -> void:
	health -= amount
"""
	s.reload()
	enemy.set_script(s)
	return enemy
