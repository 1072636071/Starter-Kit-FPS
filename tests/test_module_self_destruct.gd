extends Node
## Issue 13：SelfDestruct 模块测试
## 验证：玩家接近 → 0.8s 前摇后爆炸 AOE 伤害 60，敌人死亡

var failures: int = 0
var _enemy_destroyed: bool = false
var _player_damage: float = 0.0


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

	# 创建假 enemy，带 destroy 方法和 player 引用
	var enemy := _make_fake_enemy(player)
	add_child(enemy)
	enemy.global_position = Vector3(1.0, 0, 0)  # 距离玩家 1m < detonate_range=3m

	var mod := load("res://scripts/modules/module_self_destruct.gd").new()
	mod.name = "SelfDestruct"
	enemy.add_child(mod)
	mod.module_setup(enemy)

	# 初始不应在引爆
	_check(mod._detonating == false, "not detonating initially")

	# tick → 检测玩家距离 < 3m → 启动引爆序列
	mod.on_tick(0.1)
	_check(mod._detonating == true, "detonation sequence started when player in range")

	# 等待 fuse_time + 一点余量
	await get_tree().create_timer(mod.fuse_time + 0.2).timeout

	# 玩家应受到 60 伤害
	_check(_player_damage == 60.0, "player received 60 AOE damage (got %.1f)" % _player_damage)

	# 敌人应已销毁
	_check(_enemy_destroyed == true, "enemy destroyed after explosion")

	# 清理
	player.queue_free()
	await get_tree().process_frame

	if failures == 0:
		print("[TEST] PASS — module_self_destruct")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)


func _make_fake_player() -> Node3D:
	var p := CharacterBody3D.new()
	p.name = "FakePlayer_SelfDestruct"
	p.add_to_group("player")

	var s := GDScript.new()
	s.source_code = """extends CharacterBody3D
var health: float = 200.0
func damage(amount: float) -> void:
	health -= amount
"""
	s.reload()
	p.set_script(s)

	# 监听 damage 调用
	p.set_meta("_test", self)
	return p


func _make_fake_enemy(player_ref: Node3D) -> Node3D:
	var enemy := CharacterBody3D.new()
	enemy.name = "FakeEnemy_SelfDestruct"
	enemy.add_to_group("enemy")

	var test_ref := self
	var s := GDScript.new()
	s.source_code = """extends CharacterBody3D
var player: Node3D
var health: float = 100.0
var destroyed: bool = false
func destroy() -> void:
	destroyed = true
	get_parent().get_node("FakePlayer_SelfDestruct").get_meta("_test")._player_damage = 200.0 - get_parent().get_node("FakePlayer_SelfDestruct").health
	get_parent().get_node("FakePlayer_SelfDestruct").get_meta("_test")._enemy_destroyed = true
func damage(amount: float) -> void:
	health -= amount
"""
	s.reload()
	enemy.set_script(s)
	enemy.set("player", player_ref)
	return enemy
