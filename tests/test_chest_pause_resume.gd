## 回归测试：宝箱选完奖励后必须恢复 get_tree().paused = false
## Bug：chest_ui.gd::_on_card_pressed 选完奖励后未恢复 paused，
##      玩家选完卡后游戏仍处于暂停状态，"卡住不动"。
## 运行：godot --headless --path . res://tests/test_chest_pause_resume.tscn --quit-after 600
extends Node3D

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
	# === 准备：player + run_director + chest_ui + chest ===
	var player_scene := preload("res://objects/player.tscn")
	var player: CharacterBody3D = player_scene.instantiate()
	player.add_to_group("player")
	add_child(player)
	player.reset_backpack()

	var rd := preload("res://scripts/run_director.gd").new()
	rd.rng_seed = 42
	add_child(rd)
	rd.add_to_group("run_director")
	rd._player = player
	rd.wave = 5

	var chest_ui_scene := preload("res://scenes/chest_ui.tscn")
	var chest_ui: Control = chest_ui_scene.instantiate()
	add_child(chest_ui)

	var chest_scene := preload("res://scenes/chest.tscn")

	# === Test 1: 非 random_weapon（gold_bonus）选择后应恢复 paused = false ===
	var chest1: Area3D = chest_scene.instantiate()
	add_child(chest1)
	chest1._player_in_range = true
	chest1._open_chest()
	_check(get_tree().paused == true, "T1 开箱后游戏应暂停 (paused=true)")
	_check(chest_ui.visible == true, "T1 chest_ui 应可见")

	# 模拟玩家选 gold_bonus（_on_card_pressed 内部 await tween.finished）
	var gold_choice := {"id": &"gold_bonus", "name": "金币", "desc": "+金币"}
	chest_ui._on_card_pressed(gold_choice)
	# 等待 tween_modal_out(120ms) + 一帧余量
	await get_tree().create_timer(0.3).timeout

	_check(get_tree().paused == false,
		"T1 选完 gold_bonus 后应恢复 paused=false（核心断言：bug 修复前此处失败）")
	_check(chest_ui.visible == false, "T1 chest_ui 应隐藏")

	# === Test 2: random_weapon 流程走完 _finish_chest_reward 后应恢复 paused = false ===
	# 重新创建 chest（chest1 已 queue_free）
	var chest2: Area3D = chest_scene.instantiate()
	add_child(chest2)
	chest2._player_in_range = true
	chest2._open_chest()
	_check(get_tree().paused == true, "T2 二次开箱后游戏应暂停 (paused=true)")

	# 给 player 加满武器槽，使 random_weapon 走"满槽替换"分支
	while player.weapons.size() < 3:
		var w := Weapon.new()
		w.display_name = "填充枪"
		w.ammo_type = &"手枪弹"
		w.weapon_cost = 30
		w.durability_max = 50
		w.magazine_size = 10
		w.max_reserve = 30
		w.model = load("res://models/weapons/blaster.glb")
		w.cooldown = 0.3
		w.damage = 15.0
		player.weapons.append(w)
		player.magazine.append(w.magazine_size)
		player.weapon_durability.append(w.durability_max)

	var rw_choice := {"id": &"random_weapon", "name": "随机武器", "desc": "随机一把枪"}
	chest_ui._on_card_pressed(rw_choice)
	await get_tree().create_timer(0.3).timeout

	# random_weapon 流程：_on_card_pressed 完成后弹替换对话框，paused 应保持 true
	# （替换对话框期间游戏需要暂停，避免怪物移动）
	_check(get_tree().paused == true,
		"T2 替换对话框期间应保持 paused=true（对话框未关闭时不应恢复）")

	# 模拟玩家点确认/取消：调用 _finish_chest_reward
	chest_ui._finish_chest_reward()
	await get_tree().create_timer(0.2).timeout

	_check(get_tree().paused == false,
		"T2 _finish_chest_reward 后应恢复 paused=false（核心断言）")

	# 清理
	chest_ui.queue_free()
	player.queue_free()
	rd.queue_free()
	await get_tree().process_frame

	# 不立即 quit：保活以便 MCP get_debug_output 抓输出，外部用 stop_project 终止
	# （headless 命令行跑法可改回 get_tree().quit(0/1)）
	if failures == 0:
		print("[TEST] PASS — chest pause/resume regression")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
