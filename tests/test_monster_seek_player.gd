## 诊断测试：怪物落地后是否主动寻找玩家
## 复现用户报告："怪物刷新降落以后，还是不会主动去找玩家"
##
## 场景：地板 + NavigationRegion3D（运行时烘焙）+ monster_melee + 假玩家
## 断言：落地后 3 秒内
##   1) 怪物进入 CHASE 状态（_ai_state == 1）OR 至少向玩家移动（距离减少）
##   2) 视线检测正常（_has_los == true）
##
## 运行：
##   "G:\work\游戏蔬菜\Godot\Godot_v4.7.1-stable_win64.exe" --headless --path . res://tests/test_monster_seek_player.tscn --quit-after 600
extends Node

var failures: int = 0

func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1

func _ready():
	call_deferred("_run_tests")

func _run_tests() -> void:
	# === 构建测试场景 ===
	# 1. 大地板（40x40m），layer 1（地形），怪物会缓降落到 y=0
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0, -0.5, 0)

	# 2. NavigationRegion3D（运行时烘焙，复用项目脚本）
	# 关键：地板必须先挂到 NavigationRegion3D 子树下，再 add_child 到场景，
	# 这样 _ready 触发 bake_navigation_mesh 时 floor 已在子树中
	var nav_region_script := preload("res://scripts/nav_region.gd")
	var nav_region := NavigationRegion3D.new()
	nav_region.set_script(nav_region_script)
	nav_region.name = "NavigationRegion3D"
	nav_region.add_child(floor_body)  # 先挂子节点
	add_child(nav_region)  # 再加入场景树触发 _ready 烘焙
	# 等待 _ready 烘焙完成（多帧保险）
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# 2.5 诊断：NavMesh 烘焙是否成功？
	var nav_mesh: NavigationMesh = nav_region.navigation_mesh
	if nav_mesh:
		print("[DEBUG] nav_mesh present, agent_radius=", nav_mesh.agent_radius, " agent_height=", nav_mesh.agent_height)
		# 检查 navmesh 是否有可导航区域：查询 (0,0,0) 和 (10,0,0) 的最近点
		var map_rid: RID = nav_region.get_world_3d().navigation_map
		var origin_closest := NavigationServer3D.map_get_closest_point(map_rid, Vector3(0, 0, 0))
		var target_closest := NavigationServer3D.map_get_closest_point(map_rid, Vector3(10, 0, 0))
		print("[DEBUG] map_get_closest_point(0,0,0)=", origin_closest)
		print("[DEBUG] map_get_closest_point(10,0,0)=", target_closest)
		# 尝试计算路径
		var path := NavigationServer3D.map_get_path(map_rid, Vector3(0, 0, 0), Vector3(10, 0, 0), true)
		print("[DEBUG] map_get_path size=", path.size())
		for i in range(mini(path.size(), 5)):
			print("[DEBUG]   path[", i, "]=", path[i])
		# 检查 NavigationServer 是否有注册的 region
		var regions := NavigationServer3D.map_get_regions(map_rid)
		print("[DEBUG] map regions count=", regions.size())
		for r in regions:
			print("[DEBUG]   region rid=", r, " enabled=", NavigationServer3D.region_get_enabled(r))
	else:
		print("[DEBUG] nav_mesh is NULL!")

	# 3. 假玩家（在 player 组里，让 _auto_find_player 能找到）
	var player := Node3D.new()
	player.name = "Player"
	player.add_to_group("player")
	player.position = Vector3(10, 0, 0)  # 距离怪物 10m，在 awareness_range=16m 内
	add_child(player)

	# 4. 生成 monster_melee（恢复 y=0 复现 bug，验证修复）
	var melee_scene := preload("res://objects/monster_melee.tscn")
	var melee: CharacterBody3D = melee_scene.instantiate()
	add_child(melee)
	melee.global_position = Vector3(0, 0, 0)
	# 注入玩家引用，避免 _auto_find_player 时序问题
	melee.set("player", player)
	# 测试诊断：打印 path_desired_distance
	print("[DEBUG] nav_agent path_desired_distance=", melee.get_node("NavigationAgent3D").path_desired_distance)

	# 等待 monster _ready + 缓降落地（8m 高度 / 3.5 m/s ≈ 2.3s + 余量）
	# 实测 DROP_SPEED=3.5，落地需 ~2.3s，等 4s 保险
	print("[DEBUG] waiting for landing...")
	for i in 240:  # 4 秒 @ 60fps
		await get_tree().physics_frame
		if not bool(melee.get("_dropping")):
			print("[DEBUG] landed at frame ", i, ", pos=", melee.global_position)
			break

	var dropped := not bool(melee.get("_dropping"))
	_check(dropped, "monster landed within 4s (dropping=%s)" % str(melee.get("_dropping")))

	# 5. 落地后等 3 秒看 FSM 是否进入 CHASE
	print("[DEBUG] post-landing, waiting 3s for FSM to chase...")
	var entered_chase := false
	var chase_frame := -1
	for i in 180:  # 3 秒
		await get_tree().physics_frame
		var state: int = int(melee.get("_ai_state"))
		if state == 1:  # CHASE
			entered_chase = true
			chase_frame = i
			break

	# 打印诊断信息
	var final_state: int = int(melee.get("_ai_state"))
	var final_pos: Vector3 = melee.global_position
	var has_los: bool = bool(melee.get("_has_los"))
	var distance := Vector2(final_pos.x - player.position.x, final_pos.z - player.position.z).length()
	var initial_distance := 10.0
	print("[DEBUG] state enum: 0=IDLE,1=CHASE,2=ATTACK,3=RETREAT,4=LOST,5=JUMP")
	print("[DEBUG] final_state=", final_state, " entered_chase=", entered_chase, " chase_frame=", chase_frame)
	print("[DEBUG] final_pos=", final_pos, " distance=", distance, " initial=", initial_distance)
	print("[DEBUG] has_los=", has_los)
	print("[DEBUG] nav_agent avoidance_enabled=", melee.get_node("NavigationAgent3D").avoidance_enabled)
	print("[DEBUG] nav_agent is_navigation_finished=", melee.get_node("NavigationAgent3D").is_navigation_finished())
	print("[DEBUG] nav_agent get_next_path_position=", melee.get_node("NavigationAgent3D").get_next_path_position())
	print("[DEBUG] gravity=", melee.get("gravity"), " velocity=", melee.velocity)

	# === 断言 ===
	_check(has_los, "line of sight to player (10m open floor)")
	_check(entered_chase, "monster entered CHASE state within 3s of landing (state=%d)" % final_state)
	_check(distance < initial_distance, "monster moved toward player (distance %f -> %f)" % [initial_distance, distance])

	# 等一帧让延迟 queue_free 不报错
	await get_tree().process_frame

	if failures == 0:
		print("[TEST] PASS — monster seeks player after landing")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — ", failures, " assertion(s) failed")
		get_tree().quit(1)
