## 测试：进入商店时小地图框应隐藏
##
## Bug：小地图的框（_minimap_frame）在进入商店后还存在，并且在商店UI前面。
## 原因：_minimap_frame 在 hud.gd::_ready() 中动态 add_child 到 HUD，
##       位于 main.tscn 静态挂载的 ShopUI 之后，z-order 在 ShopUI 之上。
##       且 shop open 时没有任何逻辑隐藏 minimap。
## 修复：shop open 时隐藏 minimap（_minimap_frame + 静态 Minimap 节点），
##       shop close 时恢复。
##
## 运行：godot --headless --path . res://tests/test_shop_minimap_visibility.tscn --quit-after 600
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
	# 1. 实例化 HUD（CanvasLayer + hud.gd 脚本）
	var hud_script := load("res://scripts/hud.gd") as GDScript
	_check(hud_script != null, "hud.gd 脚本加载成功")
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(hud_script)
	add_child(hud)
	# 等两帧，让 @onready + _ready + call_deferred 跑完
	await get_tree().process_frame
	await get_tree().process_frame

	# 2. 验证 _minimap_frame 已挂树
	var minimap_frame: Control = hud.get_node_or_null("MinimapFrame")
	_check(minimap_frame != null, "MinimapFrame 节点存在（右上小地图框）")
	if not minimap_frame:
		_fail_and_quit()
		return
	_check(minimap_frame.visible == true, "初始状态 MinimapFrame 可见")

	# 3. 实例化 ShopUI 作为 HUD 子节点（匹配 main.tscn 结构）
	var shop_ui_scene := preload("res://scenes/shop_ui.tscn")
	var shop_ui: Control = shop_ui_scene.instantiate()
	hud.add_child(shop_ui)
	shop_ui.closed.connect(func(): pass)  # 静默连接
	await get_tree().process_frame

	# 4. 准备 player + run_director（shop_ui.open 需要）
	var player_scene := preload("res://objects/player.tscn")
	var player: CharacterBody3D = player_scene.instantiate()
	player.add_to_group("player")
	add_child(player)
	player.reset_backpack()

	var rd := preload("res://scripts/run_director.gd").new()
	rd.rng_seed = 42
	add_child(rd)
	rd.add_copper(50000)

	# 5. 打开商店
	shop_ui.open(player, rd)
	await get_tree().process_frame
	_check(shop_ui.is_open() == true, "shop_ui 已打开")
	_check(shop_ui.visible == true, "shop_ui visible")

	# === 核心断言：shop 打开时 minimap_frame 应隐藏 ===
	_check(minimap_frame.visible == false,
		"shop 打开后 MinimapFrame 应隐藏（visible=false），实际 visible=%s" % str(minimap_frame.visible))

	# 6. 关闭商店
	shop_ui.close()
	await get_tree().process_frame
	_check(shop_ui.is_open() == false, "shop_ui 已关闭")

	# === 核心断言：shop 关闭后 minimap_frame 应恢复可见 ===
	_check(minimap_frame.visible == true,
		"shop 关闭后 MinimapFrame 应恢复可见（visible=true），实际 visible=%s" % str(minimap_frame.visible))

	# 7. 也验证静态 Minimap 节点（如果存在）的可见性
	#    注：纯 hud.gd 实例化不包含 main.tscn 的静态 Minimap 节点，
	#    该节点只在 main.tscn 中存在。这里仅验证 _minimap_frame。

	_finish()

func _fail_and_quit() -> void:
	print("[TEST] ===== %d FAIL(s) =====" % failures)
	get_tree().quit(1 if failures > 0 else 0)

func _finish() -> void:
	print("[TEST] ===== %d FAIL(s) =====" % failures)
	get_tree().quit(1 if failures > 0 else 0)
