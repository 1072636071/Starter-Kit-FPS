extends Node
## Issue 12：Poison 陷阱测试
## 验证：玩家踩入毒陷阱 → 10s 内扣血 20 ticks × 8 = 160

var failures: int = 0
var _player: Node3D = null


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
	_player = _make_fake_player()
	add_child(_player)

	# 实例化毒陷阱
	var trap_scene := load("res://scenes/trap_poison.tscn")
	var trap: Area3D = trap_scene.instantiate()
	add_child(trap)
	trap.global_position = Vector3.ZERO

	# 玩家站在陷阱位置
	_player.global_position = Vector3.ZERO

	# 触发陷阱
	trap.activate(_player)

	# 验证陷阱 active
	_check(trap._active == true, "trap activated")

	# 模拟 10s 推进，每 0.5s 一次 tick
	var total_damage := 0.0
	var tick_count := 0
	var sim_time := 0.0
	while sim_time < 10.0:
		trap._process(0.5)
		sim_time += 0.5

	# 获取玩家的实际受伤害值：通过检查 _player 的 health 变化来验证
	# 由于 _player 是假的，我们直接验证 trap 逻辑
	# 在 10s 内应有 20 次 tick (10/0.5=20)
	# 每次 poison_dps=8，总伤害 = 160

	# 用模拟：直接验证 tick 逻辑
	var expected_ticks := int(10.0 / 0.5)  # 20
	# 验证 duration 到期后 trap 应 queue_free
	_check(not is_instance_valid(trap) or trap._elapsed >= 10.0, "trap duration completed after 10s")

	# 直接测试 DOT 计算
	var test_player := _make_fake_player()
	add_child(test_player)
	test_player.global_position = Vector3.ZERO
	test_player.set("health", 200.0)

	var trap2: Area3D = trap_scene.instantiate()
	add_child(trap2)
	trap2.global_position = Vector3.ZERO
	trap2.activate(test_player)

	# 模拟 20 次 tick
	for i in range(20):
		trap2._process(0.5)

	# 玩家应受到 20 × 8 = 160 伤害
	var expected_damage := 20 * 8  # 160
	var actual_damage := 200.0 - float(test_player.get("health"))
	_check(actual_damage == expected_damage, "poison DOT: 20 ticks x 8 = %d damage (got %.1f)" % [expected_damage, actual_damage])

	# 清理
	trap.queue_free()
	trap2.queue_free()
	test_player.queue_free()
	_player.queue_free()
	await get_tree().process_frame

	if failures == 0:
		print("[TEST] PASS — trap_poison")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)


func _make_fake_player() -> Node3D:
	var p := CharacterBody3D.new()
	p.name = "FakePlayer_Poison"
	p.add_to_group("player")
	p.set_script(_make_damageable_script())
	return p


func _make_damageable_script() -> Script:
	# 动态创建可受伤害的脚本
	var s := GDScript.new()
	s.source_code = """extends CharacterBody3D
var health: float = 200.0
func damage(amount: float) -> void:
	health -= amount
"""
	s.reload()
	return s
