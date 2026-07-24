## 小地图 T3 测试：2D blip 叠加（scripts/minimap.gd）
## 运行：godot --headless --path . res://tests/test_minimap_t3.tscn --quit-after 30
## 判定：看到 [TEST] PASS 即通过；任何 [TEST] FAIL 行即失败（exit 1 由脚本自行 quit(1)）
extends Node3D

const MINIMAP_GD := preload("res://scripts/minimap.gd")

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
	# 1. 实例化 main.tscn 整个场景
	var main_scene := preload("res://scenes/main.tscn")
	var main: Node3D = main_scene.instantiate()
	add_child(main)
	# 等一帧，让 minimap.gd 的 call_deferred("_refresh_monsters") 跑完
	await get_tree().process_frame

	# 2. HUD/Minimap/Blips 存在且挂了 minimap.gd
	var hud: CanvasLayer = main.get_node_or_null("HUD")
	var minimap: Control = hud.get_node_or_null("Minimap") if hud else null
	var blips: Control = minimap.get_node_or_null("Blips") if minimap else null
	_check(blips != null, "HUD/Minimap/Blips Control exists")
	if blips:
		var s: Script = blips.get_script()
		_check(s == MINIMAP_GD,
			"Blips script is scripts/minimap.gd (got %s)" % (
				s.resource_path if s else "null"))

		# 3. Blips 无 material（圆形裁剪改为代码内 distance 检查，边框/文字不受 shader 影响）
		var mat := blips.material
		_check(mat == null,
			"Blips.material is null (code-based clipping, got %s)" % (
				mat.get_class() if mat else "null"))

	# 4. minimap.gd 内部状态：_player 已绑定、_monsters 含 4 个怪
	if blips:
		var player: Node3D = blips.get("_player")
		_check(player != null and is_instance_valid(player),
			"minimap.gd _player bound to scene Player")
		var monsters: Array = blips.get("_monsters")
		_check(monsters.size() == 4,
			"minimap.gd _monsters has 4 entries (got %d)" % monsters.size())

	# 5. _world_to_pixel：世界中心 → 控件中心；世界角点 → 控件角点
	if blips:
		# 强制给一个已知 size，便于断言
		blips.size = Vector2(180, 180)
		var center_px: Vector2 = blips._world_to_pixel(0.0, 0.0)
		_check(abs(center_px.x - 90.0) < 0.01 and abs(center_px.y - 90.0) < 0.01,
			"_world_to_pixel(0,0) = (90,90) center (got %s)" % str(center_px))
		# 北 (z=-80) → 顶 (pixel.y=0)
		var north_px: Vector2 = blips._world_to_pixel(0.0, -80.0)
		_check(abs(north_px.y - 0.0) < 0.01,
			"_world_to_pixel(0,-80) y=0 north top (got %f)" % north_px.y)
		# 东 (x=+80) → 右 (pixel.x=180)
		var east_px: Vector2 = blips._world_to_pixel(80.0, 0.0)
		_check(abs(east_px.x - 180.0) < 0.01,
			"_world_to_pixel(80,0) x=180 east right (got %f)" % east_px.x)
		# 南 (z=+80) → 底 (pixel.y=180)
		var south_px: Vector2 = blips._world_to_pixel(0.0, 80.0)
		_check(abs(south_px.y - 180.0) < 0.01,
			"_world_to_pixel(0,80) y=180 south bottom (got %f)" % south_px.y)
		# 西 (x=-80) → 左 (pixel.x=0)
		var west_px: Vector2 = blips._world_to_pixel(-80.0, 0.0)
		_check(abs(west_px.x - 0.0) < 0.01,
			"_world_to_pixel(-80,0) x=0 west left (got %f)" % west_px.x)

	# 6. arrow_yaw_from_forward：北→0，东→+π/2，南→±π，西→-π/2
	var yaw_n: float = MINIMAP_GD.arrow_yaw_from_forward(Vector3(0, 0, -1))
	_check(abs(yaw_n - 0.0) < 0.001,
		"arrow_yaw(north -Z) = 0 (got %f)" % yaw_n)
	var yaw_e: float = MINIMAP_GD.arrow_yaw_from_forward(Vector3(1, 0, 0))
	_check(abs(yaw_e - PI / 2.0) < 0.001,
		"arrow_yaw(east +X) = +pi/2 (got %f)" % yaw_e)
	var yaw_s: float = MINIMAP_GD.arrow_yaw_from_forward(Vector3(0, 0, 1))
	_check(abs(abs(yaw_s) - PI) < 0.001,
		"arrow_yaw(south +Z) = ±pi (got %f)" % yaw_s)
	var yaw_w: float = MINIMAP_GD.arrow_yaw_from_forward(Vector3(-1, 0, 0))
	_check(abs(yaw_w + PI / 2.0) < 0.001,
		"arrow_yaw(west -X) = -pi/2 (got %f)" % yaw_w)

	# 7. enemy_color：melee 红、ranged 黄
	if blips:
		var melee_scene := preload("res://objects/monster_melee.tscn")
		var ranged_scene := preload("res://objects/monster_ranged.tscn")
		var melee_inst: CharacterBody3D = melee_scene.instantiate()
		var ranged_inst: CharacterBody3D = ranged_scene.instantiate()
		add_child(melee_inst)
		add_child(ranged_inst)
		var melee_c: Color = blips.enemy_color(melee_inst)
		var ranged_c: Color = blips.enemy_color(ranged_inst)
		_check(melee_c == blips.MELEE_COLOR,
			"enemy_color(melee) = MELEE_COLOR (got %s)" % str(melee_c))
		_check(ranged_c == blips.RANGED_COLOR,
			"enemy_color(ranged) = RANGED_COLOR (got %s)" % str(ranged_c))
		_check(melee_c != ranged_c,
			"melee color differs from ranged color (melee=%s, ranged=%s)" % [
				str(melee_c), str(ranged_c)])

	# 8. 新增视觉参数：边框 + 敌人计数 常量存在
	_check(blips.BORDER_COLOR != null,
		"BORDER_COLOR constant exists")
	_check(blips.BORDER_WIDTH > 0.0,
		"BORDER_WIDTH > 0 (got %f)" % blips.BORDER_WIDTH)
	_check(blips.ENEMY_COUNT_FONT_SIZE > 0,
		"ENEMY_COUNT_FONT_SIZE > 0 (got %d)" % blips.ENEMY_COUNT_FONT_SIZE)
	# _count_font 在 _ready 中取默认主题字体
	_check(blips.get("_count_font") != null,
		"_count_font bound to theme default font")

	# 9. 剩余敌人计数：_monsters 全部有效时 alive_count = 4
	if blips:
		var monsters: Array = blips.get("_monsters")
		var alive := 0
		for m in monsters:
			if is_instance_valid(m):
				alive += 1
		_check(alive == 4,
			"alive monster count = 4 (got %d)" % alive)
		# 模拟一个敌人被释放（死亡），alive_count 应减少
		var first_monster: Node = monsters[0]
		first_monster.queue_free()
		await get_tree().process_frame
		var alive_after: int = 0
		for m in blips.get("_monsters"):
			if is_instance_valid(m):
				alive_after += 1
		_check(alive_after == 3,
			"after freeing 1 monster, alive = 3 (got %d)" % alive_after)

	# 10. horizontal_forward：默认 rotation.y=0 → 北 (-Z)
	if blips and blips.get("_player"):
		var p: Node3D = blips.get("_player")
		# 默认玩家 rotation.y=0，forward 应为 (0,0,-1)
		var fwd: Vector3 = blips.horizontal_forward(p)
		_check(abs(fwd.x - 0.0) < 0.001 and abs(fwd.z + 1.0) < 0.001,
			"horizontal_forward(player at yaw=0) = north -Z (got %s)" % str(fwd))
		# 设置 rotation.y = -PI/2 → 朝东 (+X)
		p.rotation.y = -PI / 2.0
		var fwd_e: Vector3 = blips.horizontal_forward(p)
		_check(abs(fwd_e.x - 1.0) < 0.001 and abs(fwd_e.z - 0.0) < 0.001,
			"horizontal_forward(player at yaw=-pi/2) = east +X (got %s)" % str(fwd_e))

	# 11. 主相机与武器相机的 cull_mask 未被改动
	var player_main: CharacterBody3D = main.get_node_or_null("Player")
	if player_main:
		var main_cam: Camera3D = player_main.get_node_or_null("Head/Camera")
		if main_cam:
			_check(main_cam.cull_mask == 1048573,
				"main Camera cull_mask unchanged (got %d)" % main_cam.cull_mask)
		var weapon_cam: Camera3D = player_main.get_node_or_null("Head/Camera/SubViewportContainer/SubViewport/CameraItem")
		if weapon_cam:
			_check(weapon_cam.cull_mask == 1047554,
				"weapon CameraItem cull_mask unchanged (got %d)" % weapon_cam.cull_mask)

	if failures == 0:
		print("[TEST] PASS — minimap T3 blip overlay")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
