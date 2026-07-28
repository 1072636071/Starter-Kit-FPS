## 回归测试：武器丢弃后自动拾取 + HUD 武器名清空
## Bug 1: 丢枪后玩家走回拾取物无法自动捡起（weapon_pickup.collision_mask=0 导致 body_entered 永不触发）
## Bug 2: 丢光所有武器后，右下 HUD 仍显示已丢武器的名字（HUD _rows 不随 weapons 数组变化重建）
## 运行：godot --headless --path . res://tests/test_weapon_pickup_after_drop.tscn --quit-after 60
extends Node3D

var player: CharacterBody3D
var hud: CanvasLayer
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
	# ── 场景搭建 ─────────────────────────────
	var player_scene := preload("res://objects/player.tscn")
	player = player_scene.instantiate()
	# main.tscn 通过 groups=["player"] 把玩家加入 player 组；这里手动补上
	player.add_to_group("player")
	add_child(player)
	# 等 player._ready 完成（@onready 字段、container 等初始化）
	await get_tree().process_frame
	await get_tree().process_frame

	# HUD 绑定 player
	var hud_script := load("res://scripts/hud.gd") as GDScript
	hud = CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(hud_script)
	add_child(hud)
	# 等 HUD._ready + call_deferred("_bind_player") 跑完
	await get_tree().process_frame
	await get_tree().process_frame

	# ── Bug 2: 丢光所有武器后 HUD 右下应清空 ──
	var initial_weapon_name: String = ""
	if player.weapons.size() > 0:
		initial_weapon_name = player.weapons[0].display_name
	print("[TEST] info: 初始武器名 = \"", initial_weapon_name, "\"")

	# 记录 HUD 初始行数
	var ammo_list := hud.get_node_or_null("AmmoList")
	_check(ammo_list != null, "HUD AmmoList 节点存在")
	var initial_rows := ammo_list.get_child_count() if ammo_list else 0
	print("[TEST] info: HUD 初始行数 = ", initial_rows)
	_check(initial_rows == player.weapons.size(),
		"HUD 初始行数 == player.weapons.size() (%d vs %d)" % [initial_rows, player.weapons.size()])

	# 丢光所有武器
	while player.weapons.size() > 0:
		player.action_drop_weapon()
	# 等若干帧让信号传播
	await get_tree().process_frame
	await get_tree().process_frame

	var rows_after_drop := ammo_list.get_child_count() if is_instance_valid(ammo_list) else -1
	print("[TEST] info: 丢光后 HUD 行数 = ", rows_after_drop, "；player.weapons.size() = ", player.weapons.size())
	# 期望：HUD 行数应同步减少到 0
	_check(rows_after_drop == player.weapons.size(),
		"Bug2: 丢光所有武器后 HUD 行数 == player.weapons.size() (%d vs %d)" % [rows_after_drop, player.weapons.size()])

	# 检查 HUD 是否还残留旧武器名（遍历所有 Label）
	var stale_name_found := false
	if is_instance_valid(ammo_list):
		for row_vbox in ammo_list.get_children():
			for labels_hbox in row_vbox.get_children():
				for ctrl in labels_hbox.get_children():
					if ctrl is Label and ctrl.text != "" and ctrl.text != "空":
						# 名字 Label 不应残留任何武器名（应为空或不存在）
						if ctrl.text == initial_weapon_name:
							stale_name_found = true
							print("[TEST] info: 残留 Label.text = \"", ctrl.text, "\"")
	_check(not stale_name_found,
		"Bug2: 丢光武器后 HUD 不应残留旧武器名 \"%s\"" % initial_weapon_name)

	# ── Bug 1: 走回拾取物应能自动捡起 ─────────
	# 场上应有拾取物（被 action_drop_weapon 创建在 player.get_parent() 下，即本 Node3D）
	# 修复后拾取物生成在玩家前方 2.5m 处（防"丢枪即捡回"），玩家不在拾取半径内
	var pickup: Area3D = null
	for child in get_children():
		if child is Area3D and child.has_method("_on_body_entered"):
			pickup = child
			break
	_check(pickup != null, "拾取物节点存在于场景中")
	if pickup == null:
		_finish()
		return

	# 验证"丢枪不会瞬间捡回"：丢枪后玩家武器数应为 0
	_check(player.weapons.size() == 0,
		"Bug1 防回归：丢枪后不应瞬间被捡回（weapons.size()=%d，期望 0）" % player.weapons.size())
	_check(is_instance_valid(pickup),
		"Bug1 防回归：丢枪后拾取物应仍存在（未被瞬间拾取）")

	# 把拾取物移到固定位置，玩家从远处走过去
	pickup.global_position = Vector3(0, 0.5, 0)
	player.global_position = Vector3(5, 0.5, 0)  # 5m 远，肯定在 1.5m 半径外
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(player.weapons.size() == 0,
		"玩家远离拾取物后 weapons 仍为空 (%d)" % player.weapons.size())
	_check(is_instance_valid(pickup),
		"玩家远离后拾取物仍存在（未被拾取）")

	# 玩家走回拾取物位置
	player.global_position = Vector3(0, 0.5, 0)
	# 多等几帧让 physics engine 处理 body_entered
	for i in 4:
		await get_tree().physics_frame

	var weapons_after_walkover: int = player.weapons.size()
	print("[TEST] info: 走过拾取物后 weapons.size() = ", weapons_after_walkover)
	# 期望：玩家走过拾取物 → 自动捡起 → weapons.size() == 1
	_check(weapons_after_walkover == 1,
		"Bug1: 玩家走过拾取物应自动捡起（期望 weapons.size()==1，实际 %d）" % weapons_after_walkover)
	_check(not is_instance_valid(pickup),
		"Bug1: 拾取物被捡起后应 queue_free（不再存在）")

	_finish()


func _finish() -> void:
	if failures == 0:
		print("[TEST] PASS — 武器拾取 & HUD 清空")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d 项断言失败" % failures)
		get_tree().quit(1)
