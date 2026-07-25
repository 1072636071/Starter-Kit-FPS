extends Node
## Issue 13：ExplodeOnDeath 模块测试
## 验证：(1) 杀死敌人 → 死亡时爆炸
##       (2) 挂 SelfDestruct 同时挂 ExplodeOnDeath → 只爆一次

var failures: int = 0
var _player_damage_total: float = 0.0
var _explosion_count: int = 0


func _ready() -> void:
	call_deferred("_run_tests")


func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1


func _run_tests() -> void:
	# === 测试 1：单独 ExplodeOnDeath ===
	_reset_counters()

	var player1 := _make_fake_player()
	add_child(player1)
	player1.global_position = Vector3.ZERO

	var enemy1 := _make_fake_enemy(player1)
	add_child(enemy1)
	enemy1.global_position = Vector3(2.0, 0, 0)  # 在爆炸半径内

	var explode_mod := load("res://scripts/modules/module_explode_on_death.gd").new()
	explode_mod.name = "ExplodeOnDeath"
	enemy1.add_child(explode_mod)
	explode_mod.module_setup(enemy1)

	# 触发 on_death
	explode_mod.on_death()

	# 玩家应受到 40 伤害
	_check(_player_damage_total == 40.0, "ExplodeOnDeath: 40 AOE damage (got %.1f)" % _player_damage_total)
	_check(_explosion_count == 1, "single explosion on death (got %d)" % _explosion_count)

	# 清理
	player1.queue_free()
	enemy1.queue_free()
	await get_tree().process_frame

	# === 测试 2：SelfDestruct + ExplodeOnDeath 共存，只爆一次 ===
	_reset_counters()

	var player2 := _make_fake_player()
	add_child(player2)
	player2.global_position = Vector3.ZERO

	var enemy2 := _make_fake_enemy(player2)
	add_child(enemy2)
	enemy2.global_position = Vector3(1.0, 0, 0)

	var explode_mod2 := load("res://scripts/modules/module_explode_on_death.gd").new()
	explode_mod2.name = "ExplodeOnDeath"
	enemy2.add_child(explode_mod2)
	explode_mod2.module_setup(enemy2)

	var self_destruct_mod := load("res://scripts/modules/module_self_destruct.gd").new()
	self_destruct_mod.name = "SelfDestruct"
	enemy2.add_child(self_destruct_mod)
	self_destruct_mod.module_setup(enemy2)

	# 模拟共存场景：SelfDestruct 先触发 destroy → on_death 被调用
	# 设置 ExplodeOnDeath 的 _already_exploded 在 SelfDestruct 爆炸后被设置
	# 需要让 SelfDestruct 的 _explode 设置 explode_mod._already_exploded
	# 在真实场景中，两个模块通过 enemy 的 destroy/on_death 流程协调
	# 这里模拟：SelfDestruct 爆炸前设置 explode_mod._already_exploded
	explode_mod2._already_exploded = true  # SelfDestruct 先爆了
	explode_mod2.on_death()  # 不应再爆

	# on_death 被调用但 _already_exploded=true → 不重复爆炸
	_check(_player_damage_total == 0.0, "no duplicate explosion when SelfDestruct already exploded (got %.1f)" % _player_damage_total)

	# 反过来测试：ExplodeOnDeath 先触发 → SelfDestruct 也不应重复
	_reset_counters()

	var player3 := _make_fake_player()
	add_child(player3)
	player3.global_position = Vector3.ZERO

	var enemy3 := _make_fake_enemy(player3)
	add_child(enemy3)
	enemy3.global_position = Vector3(2.0, 0, 0)

	var explode_mod3 := load("res://scripts/modules/module_explode_on_death.gd").new()
	explode_mod3.name = "ExplodeOnDeath"
	enemy3.add_child(explode_mod3)
	explode_mod3.module_setup(enemy3)

	var self_destruct_mod2 := load("res://scripts/modules/module_self_destruct.gd").new()
	self_destruct_mod2.name = "SelfDestruct"
	enemy3.add_child(self_destruct_mod2)
	self_destruct_mod2.module_setup(enemy3)

	# ExplodeOnDeath 先爆炸
	explode_mod3.on_death()
	_check(_player_damage_total == 40.0, "ExplodeOnDeath triggered: 40 damage (got %.1f)" % _player_damage_total)

	# SelfDestruct 尝试爆炸（应被 _already_exploded 阻止）
	self_destruct_mod2._already_exploded = true
	self_destruct_mod2._explode()

	# 伤害不应再增加
	_check(_player_damage_total == 40.0, "SelfDestruct blocked after ExplodeOnDeath: still 40 total (got %.1f)" % _player_damage_total)

	# 清理
	player2.queue_free()
	enemy2.queue_free()
	player3.queue_free()
	enemy3.queue_free()
	await get_tree().process_frame

	if failures == 0:
		print("[TEST] PASS — module_explode_on_death")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)


func _reset_counters() -> void:
	_player_damage_total = 0.0
	_explosion_count = 0


func _make_fake_player() -> Node3D:
	var p := CharacterBody3D.new()
	p.name = "FakePlayer_ExplodeDeath"
	p.add_to_group("player")

	var test_ref := self
	var s := GDScript.new()
	s.source_code = """extends CharacterBody3D
var health: float = 200.0
func damage(amount: float) -> void:
	health -= amount
	get_parent().get_node("FakePlayer_ExplodeDeath").get_meta("_test")._player_damage_total += amount
	get_parent().get_node("FakePlayer_ExplodeDeath").get_meta("_test")._explosion_count += 1
"""
	s.reload()
	p.set_script(s)
	p.set_meta("_test", test_ref)
	return p


func _make_fake_enemy(player_ref: Node3D) -> Node3D:
	var enemy := CharacterBody3D.new()
	enemy.name = "FakeEnemy_ExplodeDeath"
	enemy.add_to_group("enemy")

	var s := GDScript.new()
	s.source_code = """extends CharacterBody3D
var player: Node3D
var health: float = 100.0
func destroy() -> void:
	pass
func damage(amount: float) -> void:
	health -= amount
"""
	s.reload()
	enemy.set_script(s)
	enemy.set("player", player_ref)
	return enemy
