## Bug 诊断 regression 测试：商店武器池不应包含配件（消音器/瞄准镜）
##
## ADR 022 line 441 明确："武器配件系统（瞄具/消音器/弹匣——GLB 有但机制暂无设计）"
## 即：消音器、瞄准镜属于"配件"，不是武器。但 weapons/ 目录下存在 5 个误建为
## Weapon 资源的 .tres 文件（消音器-小/大、瞄准镜-小/大-a/大-b），导致
## WeaponUtils.load_all_weapons() 把它们当作武器返回，商店因此把它们当作枪售卖。
##
## 运行：godot --headless --path . res://tests/test_shop_weapon_filter.tscn --quit-after 30
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
	# === 1. 加载武器池 ===
	var all_weapons: Array[Weapon] = WeaponUtils.load_all_weapons()
	_check(all_weapons.size() > 0, "weapon pool non-empty (got %d)" % all_weapons.size())

	# === 2. 核心断言：武器池中不应有任何配件（消音器/瞄准镜）===
	var attachments_found: Array[String] = []
	for w in all_weapons:
		var name: String = w.display_name
		# ADR 022 明确：消音器/瞄准镜属于"配件"分类，不应作为武器出现
		if name.begins_with("消音器") or name.begins_with("瞄准镜"):
			attachments_found.append(name)
	_check(attachments_found.is_empty(),
		"weapon pool excludes attachments (消音器/瞄准镜); offending: %s" % str(attachments_found))

	# === 3. 武器池中应保留真正的枪（sanity check，防止过滤过度）===
	var real_gun_names: Array[String] = []
	for w in all_weapons:
		real_gun_names.append(w.display_name)
	_check(real_gun_names.has("爆能枪"), "weapon pool retains real gun '爆能枪' (blaster.tres)")
	_check(real_gun_names.has("手托手枪-小口径"), "weapon pool retains real gun '手托手枪-小口径'")

	# === 4. 商店 UI 实际显示的武器也不应包含配件 ===
	# 复现用户报告的 bug：消音器出现在商店里
	var player_scene := preload("res://objects/player.tscn")
	var player: CharacterBody3D = player_scene.instantiate()
	player.add_to_group("player")
	add_child(player)
	player.reset_backpack()

	var rd := preload("res://scripts/run_director.gd").new()
	rd.rng_seed = 42
	add_child(rd)
	rd.add_copper(1000000)  # 给足铜币，避免购买力干扰

	var shop_ui_scene := preload("res://scenes/shop_ui.tscn")
	var shop_ui: Control = shop_ui_scene.instantiate()
	add_child(shop_ui)
	shop_ui.closed.connect(func(): pass)
	shop_ui.open(player, rd)

	# 验证商店当前展示的武器不包含配件
	var shop_attachment_names: Array[String] = []
	for w in shop_ui._shop_weapons:
		if w.display_name.begins_with("消音器") or w.display_name.begins_with("瞄准镜"):
			shop_attachment_names.append(w.display_name)
	_check(shop_attachment_names.is_empty(),
		"shop_ui._shop_weapons excludes attachments; offending: %s" % str(shop_attachment_names))

	# === 5. 多次刷新库存，确保随机抽样也不会抽出配件 ===
	# 用不同种子刷新 N 次，覆盖更多抽样可能
	var saw_attachment_in_shop := false
	for seed in range(1, 50):
		rd.rng_seed = seed
		rd.rng = RandomNumberGenerator.new()
		rd.rng.seed = seed
		shop_ui.force_refresh_on_next_open()
		shop_ui.close()
		shop_ui.open(player, rd)
		for w in shop_ui._shop_weapons:
			if w.display_name.begins_with("消音器") or w.display_name.begins_with("瞄准镜"):
				saw_attachment_in_shop = true
				break
		if saw_attachment_in_shop:
			break
	_check(not saw_attachment_in_shop,
		"across 49 different rng seeds, shop never shows attachments")

	# 清理
	shop_ui.queue_free()
	player.queue_free()
	rd.queue_free()
	await get_tree().process_frame

	if failures == 0:
		print("[TEST] PASS — shop weapon pool excludes attachments (消音器/瞄准镜)")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
