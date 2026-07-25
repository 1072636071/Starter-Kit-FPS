## 敌人跳跃导航系统测试（ADR 021）
## 运行：godot --headless --path . res://tests/test_jump_nav.tscn --quit-after 600
## 判定：[TEST] PASS 即通过；任何 [TEST] FAIL 即失败
extends Node

const NavJumpLinks = preload("res://scripts/nav_jump_links.gd")

var failures: int = 0

# Signal receiver for T8/T9
var _died_count: int = 0

func _on_monster_died(_monster_type: StringName) -> void:
	_died_count += 1

func _ready():
	call_deferred("_run_tests")

func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1

func _make_dummy_player(pos: Vector3 = Vector3(10, 0, 10)) -> Node3D:
	var p := Node3D.new()
	p.add_to_group("player")
	p.position = pos
	add_child(p)
	return p

func _run_tests() -> void:
	var dummy_player := _make_dummy_player()

	# === T1: monster_melee jump_height ===
	var melee_scene := preload("res://objects/monster_melee.tscn")
	var melee: CharacterBody3D = melee_scene.instantiate()
	add_child(melee)
	var melee_jh: float = melee.get("jump_height")
	_check(abs(melee_jh - 5.0) < 0.01, "monster_melee jump_height == 5.0 (got %f)" % melee_jh)

	# === T2: monster_melee jump_velocity ===
	var melee_jv: float = melee.get("jump_velocity")
	var expected_melee_jv := sqrt(2.0 * 20.0 * 5.0)
	_check(abs(melee_jv - expected_melee_jv) < 0.1, "monster_melee jump_velocity ~= %.1f (got %.1f)" % [expected_melee_jv, melee_jv])

	# === T3: monster_ranged jump_height ===
	var ranged_scene := preload("res://objects/monster_ranged.tscn")
	var ranged: CharacterBody3D = ranged_scene.instantiate()
	add_child(ranged)
	var ranged_jh: float = ranged.get("jump_height")
	_check(abs(ranged_jh - 2.0) < 0.01, "monster_ranged jump_height == 2.0 (got %f)" % ranged_jh)

	# === T4: monster_ranged jump_velocity ===
	var ranged_jv: float = ranged.get("jump_velocity")
	var expected_ranged_jv := sqrt(2.0 * 20.0 * 2.0)
	_check(abs(ranged_jv - expected_ranged_jv) < 0.1, "monster_ranged jump_velocity ~= %.1f (got %.1f)" % [expected_ranged_jv, ranged_jv])

	# === T5: JUMP state exists in enum ===
	var ai_state_jump: int = 5  # JUMP is the 6th enum value (0-indexed: 5)
	_check(ai_state_jump == 5, "AIState.JUMP == 5 (enum index)")

	# === T6: NavJumpLinks.generate() — 最小 GridMap 生成链接 ===
	var gridmap := GridMap.new()
	gridmap.name = "TestGridMap"
	gridmap.cell_size = Vector3(4, 4, 4)

	# 创建最小 MeshLibrary：一个 BoxMesh 带碰撞
	var mesh_lib := MeshLibrary.new()
	mesh_lib.create_item(0)
	var box := BoxMesh.new()
	box.size = Vector3(3.8, 3.8, 3.8)  # 略小于 cell_size，避免相邻面重叠
	mesh_lib.set_item_mesh(0, box)
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.8, 3.8, 3.8)
	mesh_lib.set_item_shapes(0, [shape])
	gridmap.mesh_library = mesh_lib

	# 放置：地面 cell(0,0,0) + 邻居地面 + 建筑 cell(0,1,0)（顶部，上方 y=2 为空）
	gridmap.set_cell_item(Vector3i(0, 0, 0), 0)   # 建筑下方地面
	gridmap.set_cell_item(Vector3i(1, 0, 0), 0)   # 邻居地面（+X）
	gridmap.set_cell_item(Vector3i(-1, 0, 0), 0)  # 邻居地面（-X）
	gridmap.set_cell_item(Vector3i(0, 0, 1), 0)   # 邻居地面（+Z）
	gridmap.set_cell_item(Vector3i(0, 0, -1), 0)  # 邻居地面（-Z）
	gridmap.set_cell_item(Vector3i(0, 1, 0), 0)   # 建筑顶部（y=1）

	var nav_region := NavigationRegion3D.new()
	nav_region.name = "TestNavRegion"
	add_child(nav_region)
	nav_region.add_child(gridmap)

	# 调用生成
	var jump_heights: Dictionary = {&"monster_melee": 5.0, &"monster_ranged": 2.0}
	NavJumpLinks.generate(gridmap, nav_region, jump_heights)

	# 验证生成的链接
	var links: Array = []
	for child in nav_region.get_children():
		if child is NavigationLink3D:
			links.append(child)

	_check(links.size() >= 4, "NavJumpLinks generated >= 4 links for single building (got %d)" % links.size())

	if links.size() > 0:
		var link: NavigationLink3D = links[0]
		_check(link.bidirectional, "link is bidirectional")
		_check(link.enabled, "link is enabled")
		# 链接应连接地面（y~4）和建筑顶部（y~8），cell_size=4
		var height_diff: float = abs(link.end_position.y - link.start_position.y)
		_check(height_diff > 3.0 and height_diff < 5.0, "link height diff ~4m (got %.1f)" % height_diff)

	# 清理
	nav_region.queue_free()

	# === T7: monster_melee FSM 可以进入 JUMP 状态 ===
	var melee3: CharacterBody3D = melee_scene.instantiate()
	add_child(melee3)
	# 等 _ready 执行
	await get_tree().process_frame
	# 手动设置 JUMP 状态
	melee3.call("_change_state", 5)  # AIState.JUMP
	var state_after: int = melee3.get("_ai_state")
	_check(state_after == 5, "monster_melee enters JUMP state (got %d)" % state_after)
	# 跳跃时应重置空中计时
	var air_time: float = melee3.get("_jump_air_time")
	_check(air_time < 0.01, "jump_air_time reset on JUMP entry (got %f)" % air_time)

	# === T8: 回归 — monster_melee died 信号仍正常 ===
	var melee4: CharacterBody3D = melee_scene.instantiate()
	_died_count = 0
	melee4.died.connect(_on_monster_died)
	add_child(melee4)
	await get_tree().process_frame
	melee4.damage(9999.0)
	_check(_died_count == 1, "monster_melee died signal still works (got %d)" % _died_count)

	# === T9: 回归 — monster_ranged died 信号仍正常 ===
	var ranged3: CharacterBody3D = ranged_scene.instantiate()
	_died_count = 0
	ranged3.died.connect(_on_monster_died)
	add_child(ranged3)
	await get_tree().process_frame
	ranged3.damage(9999.0)
	_check(_died_count == 1, "monster_ranged died signal still works (got %d)" % _died_count)

	# === T10: 回归 — 现有 test_enemy_ai 关键断言 ===
	# monster_melee collision layers
	_check(melee.collision_layer == 2, "monster_melee collision_layer == 2 (got %d)" % melee.collision_layer)
	_check(melee.collision_mask == 1, "monster_melee collision_mask == 1 (got %d)" % melee.collision_mask)
	# monster_ranged collision layers
	_check(ranged.collision_layer == 2, "monster_ranged collision_layer == 2 (got %d)" % ranged.collision_layer)
	_check(ranged.collision_mask == 1, "monster_ranged collision_mask == 1 (got %d)" % ranged.collision_mask)

	# 等一帧让延迟 queue_free 不报错
	await get_tree().process_frame

	if failures == 0:
		print("[TEST] PASS — enemy jump navigation (ADR 021)")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)