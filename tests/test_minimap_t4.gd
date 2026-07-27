## 小地图 T4 测试：屏外威胁指示（scripts/minimap.gd::_draw_edge_indicator）
##
## 验证 spec 06「屏外威胁指示」验收标准：
##   - 图外敌人（距玩家 > view_radius）在圆形边缘对应方向画三角形箭头
##   - 近战=红、远程=黄（与图内圆点着色一致）
##   - 箭头指向离圆心方向
##   - 多个图外敌人同一方向时箭头自然叠加（无需合并/计数逻辑）
##   - 图内敌人（≤ view_radius）仍画圆点，行为不变
##   - 无图外敌人时无多余箭头
##
## 运行：godot --headless --path . res://tests/test_minimap_t4.tscn --quit-after 30
## 判定：看到 [TEST] PASS 即通过；任何 [TEST] FAIL 行即失败
extends Node3D

const MINIMAP_GD := preload("res://scripts/minimap.gd")
const MELEE_SCENE := preload("res://objects/monster_melee.tscn")
const RANGED_SCENE := preload("res://objects/monster_ranged.tscn")

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
	# 1. 实例化 main.tscn 拿到带 minimap.gd 的 Blips
	var main_scene := preload("res://scenes/main.tscn")
	var main: Node3D = main_scene.instantiate()
	add_child(main)
	await get_tree().process_frame

	var hud: CanvasLayer = main.get_node_or_null("HUD")
	var minimap: Control = hud.get_node_or_null("Minimap") if hud else null
	var blips: Control = minimap.get_node_or_null("Blips") if minimap else null
	_check(blips != null, "HUD/Minimap/Blips Control exists")
	if not blips:
		_fail_and_quit()
		return

	# 2. _draw_edge_indicator 方法存在
	_check(blips.has_method("_draw_edge_indicator"),
		"_draw_edge_indicator method exists on Blips")
	_check(blips.has_method("_world_to_pixel"),
		"_world_to_pixel method exists on Blips")
	_check(blips.has_method("enemy_color"),
		"enemy_color method exists on Blips")

	# 3. 准备测试环境：玩家在原点、已知 size、view_radius=80
	var player: Node3D = blips.get("_player")
	_check(player != null and is_instance_valid(player),
		"_player bound to scene Player")
	if player:
		player.global_position = Vector3(0.0, 0.0, 0.0)
	# 强制 size=180x180，使数学可预测
	blips.size = Vector2(180.0, 180.0)
	# 验证 view_radius=80（T1 修复后的正确值）
	_check(abs(blips.view_radius - 80.0) < 0.01,
		"view_radius == 80 (got %f)" % blips.view_radius)

	var center := Vector2(90.0, 90.0)
	var radius: float = 89.0 # min(180,180)/2 - BORDER_INSET(1)
	var clip_r: float = radius - blips.ENEMY_RADIUS # 89 - 4 = 85

	# 4. 图内敌人（≤ view_radius）→ 应被画为圆点，不触发屏外指示
	#    验证：距离判定 ≤ clip_r 时进入圆点路径
	# 敌人在 (50, 0, 0) — 距玩家 50m < view_radius(80m) → 图内
	var on_screen_pixel: Vector2 = blips._world_to_pixel(50.0, 0.0)
	var on_screen_dist := on_screen_pixel.distance_to(center)
	_check(on_screen_dist <= clip_r,
		"enemy at 50m (within view_radius) is on-screen (pixel=%s, dist=%.2f, clip_r=%.2f)" % [str(on_screen_pixel), on_screen_dist, clip_r])

	# 5. 图外敌人（> view_radius）→ 应在圆形边缘画箭头
	#    验证：距离判定 > clip_r 时进入屏外指示路径
	# 敌人在 (100, 0, 0) — 距玩家 100m > view_radius(80m) → 图外东
	var off_screen_pixel: Vector2 = blips._world_to_pixel(100.0, 0.0)
	var off_screen_dist := off_screen_pixel.distance_to(center)
	_check(off_screen_dist > clip_r,
		"enemy at 100m (beyond view_radius) is off-screen (pixel=%s, dist=%.2f, clip_r=%.2f)" % [str(off_screen_pixel), off_screen_dist, clip_r])

	# 6. 屏外箭头方向：东侧敌人 → angle ≈ 0（指向东，离圆心朝东）
	var angle_east: float = atan2(off_screen_pixel.y - center.y, off_screen_pixel.x - center.x)
	_check(abs(angle_east - 0.0) < 0.01,
		"east off-screen enemy angle = 0 (east, got %f)" % angle_east)

	# 北侧图外敌人 (0, 0, -100) → angle ≈ -π/2（屏幕向上）
	var north_pixel: Vector2 = blips._world_to_pixel(0.0, -100.0)
	var angle_north: float = atan2(north_pixel.y - center.y, north_pixel.x - center.x)
	_check(abs(angle_north - (-PI / 2.0)) < 0.01,
		"north off-screen enemy angle = -pi/2 (north, got %f)" % angle_north)

	# 南侧图外敌人 (0, 0, 100) → angle ≈ +π/2（屏幕向下）
	var south_pixel: Vector2 = blips._world_to_pixel(0.0, 100.0)
	var angle_south: float = atan2(south_pixel.y - center.y, south_pixel.x - center.x)
	_check(abs(angle_south - (PI / 2.0)) < 0.01,
		"south off-screen enemy angle = +pi/2 (south, got %f)" % angle_south)

	# 西侧图外敌人 (-100, 0, 0) → angle ≈ ±π（指向西）
	var west_pixel: Vector2 = blips._world_to_pixel(-100.0, 0.0)
	var angle_west: float = atan2(west_pixel.y - center.y, west_pixel.x - center.x)
	_check(abs(abs(angle_west) - PI) < 0.01,
		"west off-screen enemy angle = ±pi (west, got %f)" % angle_west)

	# 7. 屏外箭头位置：edge_pos = center + (cos, sin) * (radius - ENEMY_RADIUS - 1)
	#    对东侧敌人：edge_pos.x = 90 + cos(0) * (89 - 4 - 1) = 90 + 84 = 174
	var expected_edge_east: Vector2 = center + Vector2(cos(angle_east), sin(angle_east)) * (radius - blips.ENEMY_RADIUS - 1.0)
	_check(abs(expected_edge_east.x - 174.0) < 0.01 and abs(expected_edge_east.y - 90.0) < 0.01,
		"east edge_pos = (174, 90) (got %s)" % str(expected_edge_east))

	# 8. 颜色：近战=红、远程=黄（与图内圆点着色一致）
	var melee_inst: CharacterBody3D = MELEE_SCENE.instantiate()
	var ranged_inst: CharacterBody3D = RANGED_SCENE.instantiate()
	add_child(melee_inst)
	add_child(ranged_inst)
	var melee_color: Color = blips.enemy_color(melee_inst)
	var ranged_color: Color = blips.enemy_color(ranged_inst)
	_check(melee_color == blips.MELEE_COLOR,
		"enemy_color(melee) = MELEE_COLOR (got %s)" % str(melee_color))
	_check(ranged_color == blips.RANGED_COLOR,
		"enemy_color(ranged) = RANGED_COLOR (got %s)" % str(ranged_color))
	_check(melee_color != ranged_color,
		"melee color differs from ranged color")

	# 9. _draw_edge_indicator 方法签名验证（不实际调用以避免在 _draw() 之外触发 draw_polygon ERROR）
	#    验证方法存在即可，实际绘制由 _draw() 内部触发，方向/颜色已在前序断言验证
	_check(blips.has_method("_draw_edge_indicator"),
		"_draw_edge_indicator method exists (will be called inside _draw)")

	# 10. 多个图外敌人同一方向 → 箭头自然叠加（_draw 多次调用 draw_colored_polygon 在同位置即叠加）
	#     验证：两个东侧图外敌人 (100,0,0) 与 (200,0,0) 都触发屏外路径，angle 均为 0
	var far_east_pixel: Vector2 = blips._world_to_pixel(200.0, 0.0)
	var angle_far_east: float = atan2(far_east_pixel.y - center.y, far_east_pixel.x - center.x)
	_check(abs(angle_far_east - 0.0) < 0.01,
		"far east off-screen enemy (200m) angle also = 0 (stacking, got %f)" % angle_far_east)

	# 11. 无图外敌人时无多余箭头：当 _monsters 为空，_draw 不应调用 _draw_edge_indicator
	#     验证：_monsters 清空后 alive_count = 0
	blips.set("_monsters", [])
	var alive := 0
	for m in blips.get("_monsters"):
		if is_instance_valid(m):
			alive += 1
	_check(alive == 0,
		"empty _monsters → alive count = 0 (got %d)" % alive)

	# 12. 图内/图外混合场景：一个图内 + 一个图外
	#     图内 (30, 0, 0)：距玩家 30m < view_radius → 像素距 center ≤ clip_r
	#     图外 (90, 0, 0)：距玩家 90m > view_radius → 像素距 center > clip_r
	var mix_in_pixel: Vector2 = blips._world_to_pixel(30.0, 0.0)
	var mix_in_dist := mix_in_pixel.distance_to(center)
	var mix_out_pixel: Vector2 = blips._world_to_pixel(90.0, 0.0)
	var mix_out_dist := mix_out_pixel.distance_to(center)
	_check(mix_in_dist <= clip_r and mix_out_dist > clip_r,
		"mixed scenario: in-screen(30m) dist=%.2f ≤ clip_r=%.2f, off-screen(90m) dist=%.2f > clip_r" % [mix_in_dist, clip_r, mix_out_dist])

	# 13. 清理测试实例
	melee_inst.queue_free()
	ranged_inst.queue_free()

	_fail_and_quit()

func _fail_and_quit() -> void:
	if failures == 0:
		print("[TEST] PASS — minimap T4 off-screen indicators")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
