## Issue 26：集成烟雾测试 — 交互系统（商店/宝箱/手雷/丢枪/检视）
## 运行：godot --headless --path . res://tests/test_smoke_interactive.tscn --quit-after 30
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

func _load_weapon_tres_files() -> Array:
	var pool: Array = []
	var dir := DirAccess.open("res://weapons/")
	if dir == null:
		return pool
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var res := load("res://weapons/" + fname)
			if res is Weapon:
				pool.append({"path": fname, "weapon": res})
		fname = dir.get_next()
	dir.list_dir_end()
	return pool


func _run_tests() -> void:
	# === 1. 武器检视 UI 可创建不崩溃 ===
	var wi_ui_script := load("res://scripts/weapon_inspect_ui.gd")
	_check(wi_ui_script != null, "weapon_inspect_ui.gd loadable")
	var wi_ui_tscn := load("res://scenes/weapon_inspect_ui.tscn")
	if wi_ui_tscn is PackedScene:
		_check(wi_ui_tscn.can_instantiate(), "weapon_inspect_ui.tscn can instantiate")
		var wi_inst: Node = wi_ui_tscn.instantiate()
		add_child(wi_inst)
		_check(wi_inst.has_method("close"), "weapon inspect ui has close method")
		wi_inst.queue_free()

	# === 2. 商店 UI 可创建不崩溃 ===
	var shop_ui_tscn := load("res://scenes/shop_ui.tscn")
	if shop_ui_tscn is PackedScene:
		_check(shop_ui_tscn.can_instantiate(), "shop_ui.tscn can instantiate")

	var shop_tscn := load("res://scenes/shop.tscn")
	if shop_tscn is PackedScene:
		_check(shop_tscn.can_instantiate(), "shop.tscn (ShopStation) can instantiate")
		var shop_inst: Node = shop_tscn.instantiate()
		add_child(shop_inst)
		_check(shop_inst.has_signal("body_entered"), "shop has body_entered signal")
		shop_inst.queue_free()

	# === 3. 宝箱可创建不崩溃 ===
	var chest_tscn := load("res://scenes/chest.tscn")
	if chest_tscn is PackedScene:
		_check(chest_tscn.can_instantiate(), "chest.tscn can instantiate")
		var chest_inst: Node = chest_tscn.instantiate()
		add_child(chest_inst)
		_check(chest_inst.has_signal("body_entered") or chest_inst.has_method("activate"),
			"chest has body_entered or activate")
		chest_inst.queue_free()

	var chest_ui_tscn := load("res://scenes/chest_ui.tscn")
	if chest_ui_tscn is PackedScene:
		_check(chest_ui_tscn.can_instantiate(), "chest_ui.tscn can instantiate")

	# === 4. 手雷弹体可创建不崩溃 ===
	var grenade_tscn := load("res://scenes/grenade_projectile.tscn")
	if grenade_tscn is PackedScene:
		_check(grenade_tscn.can_instantiate(), "grenade_projectile.tscn can instantiate")
		var grenade_inst: Node = grenade_tscn.instantiate()
		add_child(grenade_inst)
		_check(grenade_inst.has_method("_detonate_emp") or grenade_inst.has_method("_detonate_frag"),
			"grenade projectile has _detonate_emp or _detonate_frag")
		grenade_inst.queue_free()

	# === 5. 武器拾取可创建不崩溃 ===
	var pickup_tscn := load("res://scenes/weapon_pickup.tscn")
	if pickup_tscn is PackedScene:
		_check(pickup_tscn.can_instantiate(), "weapon_pickup.tscn can instantiate")

	# === 6. 验证所有 .tres 武器与 Weapon 资源类型一致 ===
	var weapons := _load_weapon_tres_files()
	_check(weapons.size() >= 2, "at least 2 weapon .tres files (got %d)" % weapons.size())
	for entry in weapons:
		var w: Weapon = entry["weapon"]
		_check(w is Weapon, "%s is Weapon resource" % entry["path"])

	# === 7. 验证手雷槽相关属性存在 ===
	# 通过检查 grenade_projectile 的关键参数间接验证
	var gp_script := load("res://scripts/grenade_projectile.gd")
	if gp_script is GDScript:
		# 检查脚本源码中是否有 grenade_type 相关定义
		var src: String = gp_script.source_code
		_check(src.contains("grenade_type") or src.contains("emp") or src.contains("frag"),
			"grenade_projectile.gd has grenade_type or emp/frag logic")

	# === 8. 验证 droppable weapon 相关逻辑 ===
	var player_script := load("res://objects/player.gd")
	if player_script is GDScript:
		var src: String = player_script.source_code
		_check(src.contains("action_drop_weapon") or src.contains("drop_weapon"),
			"player.gd has drop weapon logic")

	if failures == 0:
		print("[TEST] PASS — issue 26 smoke interactive")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
