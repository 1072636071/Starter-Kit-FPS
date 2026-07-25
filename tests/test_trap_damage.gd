extends Node
## Issue 12：Damage 陷阱测试
## 验证：玩家踩入伤害陷阱 → 立刻扣血 40

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
	# 创建假玩家
	var player := _make_fake_player()
	add_child(player)
	player.global_position = Vector3.ZERO

	# 实例化伤害陷阱
	var trap_scene := load("res://scenes/trap_damage.tscn")
	var trap: Area3D = trap_scene.instantiate()
	add_child(trap)
	trap.global_position = Vector3.ZERO

	# 记录初始血量
	var initial_health: float = player.get("health")

	# 触发陷阱
	trap.activate(player)

	# 等待一帧让伤害生效
	await get_tree().process_frame

	# 断言扣血 40
	var actual_damage := initial_health - float(player.get("health"))
	_check(actual_damage == 40.0, "damage trap AOE: 40 damage (got %.1f)" % actual_damage)

	# 陷阱应已 queue_free
	await get_tree().process_frame
	_check(not is_instance_valid(trap), "trap queue_free after activation")

	# 清理
	player.queue_free()
	await get_tree().process_frame

	if failures == 0:
		print("[TEST] PASS — trap_damage")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)


func _make_fake_player() -> Node3D:
	var p := CharacterBody3D.new()
	p.name = "FakePlayer_Damage"
	p.add_to_group("player")
	var s := GDScript.new()
	s.source_code = """extends CharacterBody3D
var health: float = 100.0
func damage(amount: float) -> void:
	health -= amount
"""
	s.reload()
	p.set_script(s)
	return p
