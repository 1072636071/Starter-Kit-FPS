## 回归测试：玩家买了多个枪械以后，HUD 右下武器列表不显示
## 运行：godot --headless --path . res://tests/test_hud_weapon_purchase.tscn --quit-after 600
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
	# === 准备：实例化 player + HUD ===
	var player_scene := preload("res://objects/player.tscn")
	var player: CharacterBody3D = player_scene.instantiate()
	player.add_to_group("player")
	add_child(player)
	# 等一帧让 player._ready 跑完
	await get_tree().process_frame

	# 初始化背包
	player.reset_backpack()

	# === 关键断言：player 初始有 1 把武器 ===
	_check(player.weapons.size() == 1, "player starts with 1 weapon (got %d)" % player.weapons.size())

	# === 实例化 HUD（CanvasLayer + hud.gd 脚本）===
	var hud_script := load("res://scripts/hud.gd") as GDScript
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(hud_script)
	# 把 player 放到 HUD 的父节点下，让 _bind_player 的 get_node_or_null("../Player") 能找到
	# 这里我们直接把 HUD 也 add 到根节点下，player 也在根节点下，HUD 的父节点就是 TestRoot
	add_child(hud)
	# 等两帧让 @onready + _ready + call_deferred 跑完
	await get_tree().process_frame
	await get_tree().process_frame

	# === 1. HUD 应该已经绑定 player 并显示 1 行武器 ===
	_check(hud._player != null and is_instance_valid(hud._player), "HUD has bound player")
	_check(hud._weapons.size() == 1, "HUD _weapons has 1 entry (got %d)" % hud._weapons.size())
	_check(hud._rows.size() == 1, "HUD _rows has 1 entry (got %d)" % hud._rows.size())
	var ammo_list := hud.get_node_or_null("AmmoList")
	_check(ammo_list != null, "AmmoList node exists in HUD")
	_check(ammo_list.get_child_count() == 1, "AmmoList has 1 row child (got %d)" % ammo_list.get_child_count())

	# === 2. 模拟购买第 2 把武器 ===
	var new_weapon: Weapon = load("res://weapons/blaster-repeater.tres")
	print("[TEST-bug] before purchase: player.weapons.size()=", player.weapons.size(),
		" hud._weapons.size()=", hud._weapons.size(),
		" hud._rows.size()=", hud._rows.size())

	# 模拟 shop_ui._buy_weapon 的关键操作
	player.weapons.append(new_weapon)
	player.magazine.append(new_weapon.magazine_size)
	player.weapon_durability.append(new_weapon.durability_max)
	player._emit_ammo_updated()

	print("[TEST-bug] after purchase: player.weapons.size()=", player.weapons.size(),
		" hud._weapons.size()=", hud._weapons.size(),
		" hud._rows.size()=", hud._rows.size(),
		" AmmoList children=", ammo_list.get_child_count())

	# 等一帧让 queue_free 完成
	await get_tree().process_frame

	print("[TEST-bug] after frame: player.weapons.size()=", player.weapons.size(),
		" hud._weapons.size()=", hud._weapons.size(),
		" hud._rows.size()=", hud._rows.size(),
		" AmmoList children=", ammo_list.get_child_count())

	# === 关键断言：HUD 应该显示 2 行武器 ===
	_check(hud._weapons.size() == 2,
		"after purchase 1: HUD _weapons size == 2 (got %d)" % hud._weapons.size())
	_check(hud._rows.size() == 2,
		"after purchase 1: HUD _rows size == 2 (got %d)" % hud._rows.size())
	_check(ammo_list.get_child_count() == 2,
		"after purchase 1: AmmoList has 2 row children (got %d)" % ammo_list.get_child_count())

	# === 3. 模拟购买第 3 把武器 ===
	var third_weapon: Weapon = load("res://weapons/狙击步枪.tres")
	player.weapons.append(third_weapon)
	player.magazine.append(third_weapon.magazine_size)
	player.weapon_durability.append(third_weapon.durability_max)
	player._emit_ammo_updated()

	await get_tree().process_frame

	print("[TEST-bug] after 3rd weapon: player.weapons.size()=", player.weapons.size(),
		" hud._weapons.size()=", hud._weapons.size(),
		" hud._rows.size()=", hud._rows.size(),
		" AmmoList children=", ammo_list.get_child_count())

	_check(hud._rows.size() == 3,
		"after purchase 2: HUD _rows size == 3 (got %d)" % hud._rows.size())
	_check(ammo_list.get_child_count() == 3,
		"after purchase 2: AmmoList has 3 row children (got %d)" % ammo_list.get_child_count())

	# === 4. 验证行内的 name_label 文本与武器名匹配 ===
	for i in range(hud._rows.size()):
		var row: Dictionary = hud._rows[i]
		var name_label: Label = row["name_label"]
		var expected_name: String = (player.weapons[i] as Weapon).display_name
		_check(name_label.text == expected_name,
			"row %d name_label text matches weapon display_name: expected '%s', got '%s'" % [i, expected_name, name_label.text])

	# === 5. 通过实际 shop_ui 购买路径验证（满槽替换场景）===
	# 玩家已有 3 把武器，再买一把 → 走 _show_replace_popup → _confirm_replace 路径
	var rd := preload("res://scripts/run_director.gd").new()
	rd.rng_seed = 42
	add_child(rd)
	rd.add_copper(50000)

	var shop_ui_scene := preload("res://scenes/shop_ui.tscn")
	var shop_ui: Control = shop_ui_scene.instantiate()
	add_child(shop_ui)
	shop_ui.closed.connect(func(): pass)
	shop_ui.open(player, rd)

	# 找一把与现有武器不同的商店武器
	var replace_shop_idx := -1
	for i in range(shop_ui._shop_weapons.size()):
		var w: Weapon = shop_ui._shop_weapons[i]
		var already_has := false
		for pw in player.weapons:
			if (pw as Weapon).display_name == w.display_name:
				already_has = true
				break
		if not already_has:
			replace_shop_idx = i
			break

	if replace_shop_idx >= 0:
		# 调用 _confirm_replace 直接替换槽 0
		shop_ui._replace_weapon_idx = replace_shop_idx
		var old_name: String = (player.weapons[0] as Weapon).display_name
		shop_ui._confirm_replace(0)
		var new_name: String = (player.weapons[0] as Weapon).display_name
		_check(new_name != old_name,
			"replace slot 0: old='%s' new='%s'" % [old_name, new_name])

		await get_tree().process_frame

		# HUD 应该仍然显示 3 行（替换不改变数量）
		_check(hud._rows.size() == 3,
			"after replace: HUD _rows size == 3 (got %d)" % hud._rows.size())
		_check(ammo_list.get_child_count() == 3,
			"after replace: AmmoList has 3 row children (got %d)" % ammo_list.get_child_count())

		# 行 0 的 name_label 应该显示新武器名
		var row0: Dictionary = hud._rows[0]
		var name_label0: Label = row0["name_label"]
		_check(name_label0.text == new_name,
			"after replace: row 0 name_label = '%s' (expected '%s')" % [name_label0.text, new_name])
	else:
		print("[TEST] SKIP: no replaceable weapon in shop (all already owned)")

	# === 报告 ===
	shop_ui.queue_free()
	player.queue_free()
	rd.queue_free()
	hud.queue_free()
	await get_tree().process_frame

	if failures == 0:
		print("[TEST] PASS — HUD 武器列表随购买更新")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
