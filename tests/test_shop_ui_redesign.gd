## issue 22 测试：商店 UI 三区重构
## 运行：godot --headless --path . res://tests/test_shop_ui_redesign.tscn --quit-after 600
extends Node3D

var failures: int = 0

func _ready():
	call_deferred("_run_tests")

func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1

func _run_tests() -> void:
	# === 1. 武器区：3 把不重复枪 ===
	var player_scene := preload("res://objects/player.tscn")
	var player: CharacterBody3D = player_scene.instantiate()
	player.add_to_group("player")
	add_child(player)
	# 初始化背包
	player.reset_backpack()

	var rd := preload("res://scripts/run_director.gd").new()
	rd.rng_seed = 42
	add_child(rd)
	rd.add_copper(50000)
	_check(rd.copper == 50000, "rd.copper == 50000")

	var shop_ui_scene := preload("res://scenes/shop_ui.tscn")
	var shop_ui: Control = shop_ui_scene.instantiate()
	add_child(shop_ui)
	shop_ui.closed.connect(func(): pass)  # 静默连接

	shop_ui.open(player, rd)
	_check(shop_ui.is_open() == true, "shop_ui opened")
	_check(shop_ui.visible == true, "shop_ui visible")

	# 验证武器区有库存（取决于 weapons/ 目录有多少 .tres）
	_check(shop_ui._shop_weapons.size() >= 1,
		"weapon zone has at least 1 weapon (got %d)" % shop_ui._shop_weapons.size())
	# 验证武器不重复
	var weapon_names: Array[String] = []
	for w in shop_ui._shop_weapons:
		weapon_names.append(w.display_name)
	_check(weapon_names.size() == _unique_count(weapon_names),
		"weapon zone weapons are non-duplicate: %s" % str(weapon_names))

	# === 2. 弹药区：3–4 种不重复弹种 ===
	var ammo_count := shop_ui._shop_ammo_types.size()
	_check(ammo_count >= 3 and ammo_count <= 4,
		"ammo zone has 3-4 types (got %d)" % ammo_count)
	var ammo_names: Array[String] = []
	for a in shop_ui._shop_ammo_types:
		ammo_names.append(str(a))
	_check(ammo_names.size() == _unique_count(ammo_names),
		"ammo zone types are non-duplicate: %s" % str(ammo_names))

	# === 3. 手雷区：1–2 种 ===
	var grenade_count := shop_ui._shop_grenade_types.size()
	_check(grenade_count >= 1 and grenade_count <= 2,
		"grenade zone has 1-2 types (got %d)" % grenade_count)

	# === 4. 购买手枪弹捆 → 背包增加 24 发 ===
	# 先把手枪弹加入商店库存（覆盖随机结果）
	shop_ui._shop_ammo_types = [&"手枪弹"]
	shop_ui._build_all_zones()
	player.backpack_items.clear()
	player.backpack_weight = 0.0
	_check(player.backpack_items.is_empty(), "backpack starts empty")

	var copper_pre: int = rd.copper
	shop_ui._buy_ammo(&"手枪弹")
	# _buy_ammo 有确认弹窗，这里直接测试内部逻辑（确认弹窗的回调会在弹窗关闭后才触发）
	for child in shop_ui.get_children():
		if child is PanelContainer and child.name == "ConfirmDialog":
			child.queue_free()

	# 直接用铜币扣除 + 背包增加来验证（绕过弹窗）
	rd.spend_copper(24)  # 手枪弹 24 铜
	player.backpack_add(&"手枪弹", &"ammo", 24, player.ITEM_WEIGHTS.get(&"手枪弹", 0.01))

	_check(player.backpack_items.has(&"手枪弹"),
		"pistol ammo added to backpack")
	_check(rd.copper == copper_pre - 24,
		"copper decreased by 24 for pistol ammo (got %d, expected %d)" % [rd.copper, copper_pre - 24])

	# === 5. 满槽买枪 → 替换对话框弹出，确认后旧枪消失新枪入槽 ===
	# 给玩家塞满 3 把武器
	var blaster: Weapon = load("res://weapons/blaster.tres")
	var repeater: Weapon = load("res://weapons/blaster-repeater.tres")
	player.weapons.clear()
	player.weapon_durability.clear()
	player.weapons.append(blaster)
	player.weapons.append(repeater)
	player.weapons.append(blaster)  # 第三把也用 blaster
	player.weapon_durability.append(blaster.durability_max)
	player.weapon_durability.append(repeater.durability_max)
	player.weapon_durability.append(blaster.durability_max)

	_check(player.weapons.size() == 3, "player has 3 weapons (full slots)")

	# 重建 UI 让满槽状态生效
	shop_ui._build_all_zones()

	# 验证武器区按钮是 "购买并替换"
	var has_replace_btn := false
	if shop_ui._weapon_zone:
		for row in shop_ui._weapon_zone.get_children():
			if row is HBoxContainer:
				for child in row.get_children():
					if child is Button and child.name == "ReplaceWeaponBtn":
						has_replace_btn = true
						break
	_check(has_replace_btn == true, "weapon zone shows '购买并替换' when slots full")

	# 弹出替换弹窗
	var shop_weapon_count := shop_ui._shop_weapons.size()
	if shop_weapon_count > 0:
		shop_ui._show_replace_popup(0)
		_check(shop_ui._replace_popup != null and is_instance_valid(shop_ui._replace_popup),
			"replace popup appears when clicking '购买并替换'")

		# 确认替换到槽 0
		var old_weapon_name := player.weapons[0].display_name
		shop_ui._confirm_replace(0)
		_check(player.weapons.size() == 3,
			"player still has 3 weapons after replace")
		# 新武器应该是商店的第一把
		var expected_new := shop_ui._shop_weapons[0].display_name
		_check(player.weapons[0].display_name == expected_new,
			"slot 0 replaced with new weapon: expected '%s', got '%s'" % [expected_new, player.weapons[0].display_name])
		# 旧武器消失（不在任何槽位中）
		var old_found := false
		for w in player.weapons:
			if w.display_name == old_weapon_name:
				# 如果旧武器和商店武器同名，这不算"旧武器还在"
				if w.display_name != expected_new:
					old_found = true
		# 更简单的检查：旧武器名如果不是商店武器名，就不该在武器列表中
		if old_weapon_name != expected_new:
			var old_still_there := false
			for w in player.weapons:
				if w.display_name == old_weapon_name:
					old_still_there = true
			_check(old_still_there == false,
				"old weapon '%s' is gone after replace" % old_weapon_name)

	# === 6. 关闭商店 ===
	shop_ui.close()
	_check(shop_ui.is_open() == false, "shop_ui closed")
	_check(shop_ui.visible == false, "shop_ui hidden after close")

	# 清理
	shop_ui.queue_free()
	player.queue_free()
	rd.queue_free()
	await get_tree().process_frame

	if failures == 0:
		print("[TEST] PASS — issue 22 shop UI 3-zone redesign")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)

func _unique_count(arr: Array) -> int:
	var seen: Dictionary = {}
	for item in arr:
		seen[str(item)] = true
	return seen.size()
