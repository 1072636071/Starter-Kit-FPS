## 敌人 AI 系统重构测试（ADR 017, issue 06）
## 运行：godot --headless --path . res://tests/test_enemy_ai.tscn --quit-after 600
## 判定：[TEST] PASS 即通过；任何 [TEST] FAIL 即失败
extends Node

var failures: int = 0

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

	# === T1: monster_melee 碰撞层验证 ===
	var melee_scene := preload("res://objects/monster_melee.tscn")
	var melee: CharacterBody3D = melee_scene.instantiate()
	add_child(melee)
	_check(melee.collision_layer == 2, "monster_melee collision_layer == 2 (got %d)" % melee.collision_layer)
	_check(melee.collision_mask == 1, "monster_melee collision_mask == 1 (got %d)" % melee.collision_mask)

	# === T2: monster_melee RVO 配置验证 ===
	var nav_agent: NavigationAgent3D = melee.get_node("NavigationAgent3D")
	_check(nav_agent.avoidance_enabled == true, "monster_melee avoidance_enabled == true")
	_check(abs(nav_agent.radius - 0.5) < 0.01, "monster_melee nav radius == 0.5 (got %f)" % nav_agent.radius)
	_check(abs(nav_agent.neighbor_distance - 5.0) < 0.01, "monster_melee neighbor_distance == 5.0 (got %f)" % nav_agent.neighbor_distance)
	_check(nav_agent.max_neighbors == 8, "monster_melee max_neighbors == 8 (got %d)" % nav_agent.max_neighbors)

	# === T3: monster_melee FSM 初始状态 ===
	_check(melee.get("_ai_state") == 0, "monster_melee initial _ai_state == IDLE(0) (got %d)" % int(melee.get("_ai_state")))

	# === T4: monster_ranged 碰撞层验证 ===
	var ranged_scene := preload("res://objects/monster_ranged.tscn")
	var ranged: CharacterBody3D = ranged_scene.instantiate()
	add_child(ranged)
	_check(ranged.collision_layer == 2, "monster_ranged collision_layer == 2 (got %d)" % ranged.collision_layer)
	_check(ranged.collision_mask == 1, "monster_ranged collision_mask == 1 (got %d)" % ranged.collision_mask)

	# === T5: monster_ranged RVO 配置验证 ===
	var ranged_nav: NavigationAgent3D = ranged.get_node("NavigationAgent3D")
	_check(ranged_nav.avoidance_enabled == true, "monster_ranged avoidance_enabled == true")

	# === T6: enemy（飞行）碰撞层验证 ===
	var enemy_scene := preload("res://objects/enemy.tscn")
	var enemy: Area3D = enemy_scene.instantiate()
	enemy.set("player", dummy_player)
	add_child(enemy)
	_check(enemy.collision_layer == 2, "enemy collision_layer == 2 (got %d)" % enemy.collision_layer)
	_check(enemy.collision_mask == 0, "enemy collision_mask == 0 (got %d)" % enemy.collision_mask)

	# === T7: enemy 追踪行为（缓降结束后 position 朝玩家变化）===
	# 等待缓降结束
	for i in 200:
		await get_tree().process_frame
	var enemy_pos_after_drop := enemy.position
	# 再等几帧让 AI 追踪
	for i in 60:
		await get_tree().process_frame
	var enemy_pos_tracking := enemy.position
	# 水平距离应该减小（朝玩家移动）
	var dist_after_drop := Vector2(enemy_pos_after_drop.x - dummy_player.position.x, enemy_pos_after_drop.z - dummy_player.position.z).length()
	var dist_tracking := Vector2(enemy_pos_tracking.x - dummy_player.position.x, enemy_pos_tracking.z - dummy_player.position.z).length()
	_check(dist_tracking < dist_after_drop or dist_tracking < 9.0,
		"enemy tracks player: dist decreased or within preferred (before=%.1f, after=%.1f)" % [dist_after_drop, dist_tracking])

	# === T8: enemy 悬停高度验证 ===
	_check(abs(enemy.position.y - 4.0) < 1.5, "enemy hover height ~4.0 (got %f)" % enemy.position.y)

	# === T9: projectile 碰撞 mask 验证 ===
	var proj_scene := preload("res://objects/projectile.tscn")
	var proj: Area3D = proj_scene.instantiate()
	add_child(proj)
	_check(proj.collision_mask == 7, "projectile collision_mask == 7 (layers 1+2+3) (got %d)" % proj.collision_mask)
	proj.queue_free()

	# === T10: NavMesh 参数验证 ===
	var nav_region_script := preload("res://scripts/nav_region.gd")
	var nav_region := NavigationRegion3D.new()
	nav_region.set_script(nav_region_script)
	add_child(nav_region)
	# 等 _ready 执行
	await get_tree().process_frame
	var nav_mesh: NavigationMesh = nav_region.navigation_mesh
	if nav_mesh:
		_check(abs(nav_mesh.agent_radius - 0.5) < 0.01, "navmesh agent_radius == 0.5 (got %f)" % nav_mesh.agent_radius)
		_check(abs(nav_mesh.agent_height - 1.5) < 0.01, "navmesh agent_height == 1.5 (got %f)" % nav_mesh.agent_height)
		_check(abs(nav_mesh.cell_size - 0.25) < 0.01, "navmesh cell_size == 0.25 (got %f)" % nav_mesh.cell_size)
	else:
		_check(false, "navmesh is null after _ready")
	nav_region.queue_free()

	# === T11: monster_melee died 信号仍正常（回归）===
	var melee2: CharacterBody3D = melee_scene.instantiate()
	add_child(melee2)
	var died_count := 0
	melee2.died.connect(func(_t: StringName): died_count += 1)
	melee2.damage(9999.0)
	_check(died_count == 1, "monster_melee died signal still works (got %d)" % died_count)
	_check(bool(melee2.get("_dead")) == true, "monster_melee _dead set after lethal damage")

	# === T12: monster_ranged died 信号仍正常（回归）===
	var ranged2: CharacterBody3D = ranged_scene.instantiate()
	add_child(ranged2)
	var died_count2 := 0
	ranged2.died.connect(func(_t: StringName): died_count2 += 1)
	ranged2.damage(9999.0)
	_check(died_count2 == 1, "monster_ranged died signal still works (got %d)" % died_count2)

	# === T13: enemy died 信号仍正常（回归）===
	var enemy2: Area3D = enemy_scene.instantiate()
	enemy2.set("player", dummy_player)
	add_child(enemy2)
	var died_count3 := 0
	enemy2.died.connect(func(_t: StringName): died_count3 += 1)
	enemy2.damage(9999.0)
	_check(died_count3 == 1, "enemy died signal still works (got %d)" % died_count3)

	# 等一帧让延迟 queue_free 不报错
	await get_tree().process_frame

	if failures == 0:
		print("[TEST] PASS — enemy AI overhaul (ADR 017)")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
