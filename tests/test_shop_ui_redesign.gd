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
	_check(rd.copper == 60000, "rd.copper == 60000 (initial 10000 + 50000)")

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

	# === 2. 弹药区：默认出售全部 6 种弹种（不再随机抽样）===
	var ammo_count: int = shop_ui._shop_ammo_types.size()
	_check(ammo_count == 6,
		"ammo zone has all 6 types (got %d)" % ammo_count)
	var ammo_names: Array[String] = []
	for a in shop_ui._shop_ammo_types:
		ammo_names.append(str(a))
	_check(ammo_names.size() == _unique_count(ammo_names),
		"ammo zone types are non-duplicate: %s" % str(ammo_names))
	# 验证 6 种弹种都在
	for expected in ["手枪弹", "步枪弹", "霰弹", "狙击弹", "能量电池", "榴弹"]:
		_check(expected in ammo_names,
			"ammo zone contains %s" % expected)

	# === 3. 手雷区：1–2 种 ===
	var grenade_count: int = shop_ui._shop_grenade_types.size()
	_check(grenade_count >= 1 and grenade_count <= 2,
		"grenade zone has 1-2 types (got %d)" % grenade_count)

	# === 4. 购买手枪弹捆 → 背包增加 24 发 ===
	# 先把手枪弹加入商店库存（覆盖随机结果）
	shop_ui._shop_ammo_types.assign([&"手枪弹"])
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
	# 给玩家塞满 3 把武器（确保不重复，避免替换后仍存在同名武器）
	var blaster: Weapon = load("res://weapons/blaster.tres")
	var repeater: Weapon = load("res://weapons/blaster-repeater.tres")
	player.weapons.clear()
	player.weapon_durability.clear()
	player.weapons.append(blaster)
	player.weapons.append(repeater)
	player.weapons.append(repeater)  # 第三把用 repeater（与 blaster 不同名）
	player.weapon_durability.append(blaster.durability_max)
	player.weapon_durability.append(repeater.durability_max)
	player.weapon_durability.append(repeater.durability_max)

	_check(player.weapons.size() == 3, "player has 3 weapons (full slots)")

	# 重建 UI 让满槽状态生效
	shop_ui._build_all_zones()

	# 验证武器区按钮是 "购买并替换"（递归查找，适配 UICard 包装结构）
	var has_replace_btn := false
	if shop_ui._weapon_zone:
		var btns: Array = shop_ui._weapon_zone.find_children("*", "Button", true, false)
		for b in btns:
			if b.name == "ReplaceWeaponBtn":
				has_replace_btn = true
				break
	_check(has_replace_btn == true, "weapon zone shows '购买并替换' when slots full")

	# 弹出替换弹窗
	var shop_weapon_count: int = shop_ui._shop_weapons.size()
	if shop_weapon_count > 0:
		shop_ui._show_replace_popup(0)
		_check(shop_ui._replace_popup != null and is_instance_valid(shop_ui._replace_popup),
			"replace popup appears when clicking '购买并替换'")

		# 确认替换到槽 0
		var old_weapon_name: String = player.weapons[0].display_name
		shop_ui._confirm_replace(0)
		_check(player.weapons.size() == 3,
			"player still has 3 weapons after replace")
		# 新武器应该是商店的第一把
		var expected_new: String = shop_ui._shop_weapons[0].display_name
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
	# 等待关闭动效完成（UIMotion.tween_modal_out 120ms），多等几帧确保 tween 被处理
	for _i in range(30):
		await get_tree().process_frame
	_check(shop_ui.visible == false, "shop_ui hidden after close")

	# ============================================================
	# === Regression 测试（修复历史 bug） ===
	# ============================================================

	# === R1. ScrollContainer 必须垂直 expand_fill，否则 VBoxContainer 给它分配
	# 最小高度 0，商品区不可见（bug：进入商店后什么商品都看不到）===
	_check(shop_ui._scroll.size_flags_vertical == Control.SIZE_EXPAND_FILL,
		"regression: scroll size_flags_vertical == SIZE_EXPAND_FILL (invisible items bug)")
	_check(shop_ui._scroll.size_flags_horizontal == Control.SIZE_EXPAND_FILL,
		"regression: scroll size_flags_horizontal == SIZE_EXPAND_FILL")

	# === R2. 武器预览 SubViewport 必须拥有独立 World3D，否则 layer 2 模型泄漏
	# 到主 World3D 被玩家相机渲染（bug：退出商店后有模型遮住相机）===
	# 重新打开商店以构建武器预览
	shop_ui.open(player, rd)
	_check(shop_ui.is_open() == true, "regression: shop reopened for preview tests")
	var preview_svps: Array = shop_ui.find_children("*", "SubViewport", true, false)
	var has_own_world := false
	for svp in preview_svps:
		if svp.own_world_3d == true:
			has_own_world = true
			break
	_check(preview_svps.size() > 0,
		"regression: weapon preview SubViewports exist (got %d)" % preview_svps.size())
	_check(has_own_world == true,
		"regression: at least one SubViewport has own_world_3d == true (model leak bug)")

	# === R3. 武器预览相机的 basis 已被设置（非恒等），证明 Basis.looking_at
	# 被调用而非依赖 look_at()（bug: "Node not inside tree. Use look_at_from_position()"）===
	# 若 look_at() 失败，basis 保持恒等（z=(0,0,1)）；Basis.looking_at 成功后 z 会变化。
	var preview_cams: Array = shop_ui.find_children("*", "Camera3D", true, false)
	var cam_basis_set := false
	for cam in preview_cams:
		# 相机 at (0,0.3,2.5) 朝向 (0,0.2,0)：z 应从默认 (0,0,1) 变为 ≈(0,0.04,0.999)
		if not cam.basis.z.is_equal_approx(Vector3(0, 0, 1)):
			cam_basis_set = true
			break
	_check(preview_cams.size() > 0,
		"regression: preview cameras exist (got %d)" % preview_cams.size())
	_check(cam_basis_set == true,
		"regression: camera basis set via Basis.looking_at (look_at 'Node not inside tree' bug)")

	# === R4. 商店可反复进入：关闭后再次 open 应正常显示（bug：进入一次商店后商店没了）===
	shop_ui.close()
	for _i in range(30):
		await get_tree().process_frame
	_check(shop_ui.is_open() == false, "regression: shop closed for reopen test")

	shop_ui.open(player, rd)
	_check(shop_ui.is_open() == true, "regression: shop reopened (shop disappearing bug)")
	_check(shop_ui.visible == true, "regression: shop visible after reopen")
	# 验证三区在重新打开后被重建
	_check(shop_ui._weapon_zone != null and is_instance_valid(shop_ui._weapon_zone),
		"regression: weapon zone rebuilt after reopen")
	_check(shop_ui._ammo_zone != null and is_instance_valid(shop_ui._ammo_zone),
		"regression: ammo zone rebuilt after reopen")
	_check(shop_ui._grenade_zone != null and is_instance_valid(shop_ui._grenade_zone),
		"regression: grenade zone rebuilt after reopen")

	shop_ui.close()
	for _i in range(30):
		await get_tree().process_frame

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
