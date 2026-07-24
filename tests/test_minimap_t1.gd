## 小地图 T1 测试：俯视渲染基建
## 运行：godot --headless --path . res://tests/test_minimap_t1.tscn --quit-after 30
## 判定：看到 [TEST] PASS 即通过；任何 [TEST] FAIL 行即失败（exit 1 由脚本自行 quit(1)）
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
	# 实例化 main.tscn 整个场景，验证 SubViewport + Camera3D 配置
	var main_scene := preload("res://scenes/main.tscn")
	var main: Node3D = main_scene.instantiate()
	add_child(main)

	# 1. SubViewport 存在
	var vp: SubViewport = main.get_node_or_null("MinimapViewport")
	_check(vp != null, "MinimapViewport SubViewport exists")
	if vp:
		# 2. SubViewport 尺寸 > 0
		_check(vp.size.x > 0 and vp.size.y > 0, "MinimapViewport size non-zero (got %s)" % str(vp.size))
		# 3. MinimapCamera 存在且为 Camera3D
		var cam: Camera3D = vp.get_node_or_null("MinimapCamera")
		_check(cam != null, "MinimapCamera Camera3D exists")
		if cam:
			# 4. 正交投影（projection = 1）
			_check(cam.projection == Camera3D.PROJECTION_ORTHOGONAL,
				"MinimapCamera projection is ORTHOGONAL (got %d)" % cam.projection)
			# 5. cull_mask = layer 1（bit 0 = 1）
			_check(cam.cull_mask == 1, "MinimapCamera cull_mask = 1 (layer 1 only, got %d)" % cam.cull_mask)
			# 6. 正交全高 = 160m（Godot 4 中 size 为视口全高）→ 半高 80m → 覆盖 ±80 世界
			_check(abs(cam.size - 160.0) < 0.01, "MinimapCamera ortho size = 160 (full height, got %f)" % cam.size)
			# 7. 位于世界中心正上方（x≈0, z≈0, y>0）
			_check(abs(cam.global_position.x) < 0.01, "MinimapCamera x = 0 (got %f)" % cam.global_position.x)
			_check(abs(cam.global_position.z) < 0.01, "MinimapCamera z = 0 (got %f)" % cam.global_position.z)
			_check(cam.global_position.y > 50.0, "MinimapCamera y above world (got %f)" % cam.global_position.y)
			# 8. 相机朝下（本地 -Z → 世界 -Y）
			var forward := -cam.global_transform.basis.z
			_check(forward.y < -0.99, "MinimapCamera looks straight down (forward.y < -0.99, got %f)" % forward.y)
			# 9. 相机图像 up = 世界 -Z（北朝上）
			var up := cam.global_transform.basis.y
			_check(up.z < -0.99, "MinimapCamera up = world -Z (north-up, up.z < -0.99, got %f)" % up.z)

	# 10. 可取得 ViewportTexture（供 T2 绑定）
	if vp:
		var tex := vp.get_texture()
		_check(tex != null, "MinimapViewport provides a ViewportTexture")

	# 11. 怪物 mesh 节点 layers = 4（layer 3）—— 由 monster_melee.gd._ready() 运行时设置
	var melee_scene := preload("res://objects/monster_melee.tscn")
	var melee: CharacterBody3D = melee_scene.instantiate()
	add_child(melee)
	var melee_meshes := melee.find_children("*", "MeshInstance3D", true, false)
	_check(melee_meshes.size() > 0, "monster_melee has MeshInstance3D children (got %d)" % melee_meshes.size())
	var melee_all_layer3 := true
	for m in melee_meshes:
		if (m as MeshInstance3D).layers != 4:
			melee_all_layer3 = false
			print("[TEST]   monster_melee mesh '%s' layers = %d (expected 4)" % [m.name, (m as MeshInstance3D).layers])
	_check(melee_all_layer3, "all monster_melee meshes on layer 3 (layers = 4)")

	var ranged_scene := preload("res://objects/monster_ranged.tscn")
	var ranged: CharacterBody3D = ranged_scene.instantiate()
	add_child(ranged)
	var ranged_meshes := ranged.find_children("*", "MeshInstance3D", true, false)
	_check(ranged_meshes.size() > 0, "monster_ranged has MeshInstance3D children (got %d)" % ranged_meshes.size())
	var ranged_all_layer3 := true
	for m in ranged_meshes:
		if (m as MeshInstance3D).layers != 4:
			ranged_all_layer3 = false
			print("[TEST]   monster_ranged mesh '%s' layers = %d (expected 4)" % [m.name, (m as MeshInstance3D).layers])
	_check(ranged_all_layer3, "all monster_ranged meshes on layer 3 (layers = 4)")

	# 12. 主相机与武器相机的 cull_mask 未被改动
	var player: CharacterBody3D = main.get_node_or_null("Player")
	if player:
		var main_cam: Camera3D = player.get_node_or_null("Head/Camera")
		if main_cam:
			_check(main_cam.cull_mask == 1048573, "main Camera cull_mask unchanged (got %d)" % main_cam.cull_mask)
		var weapon_cam: Camera3D = player.get_node_or_null("Head/Camera/SubViewportContainer/SubViewport/CameraItem")
		if weapon_cam:
			_check(weapon_cam.cull_mask == 1047554, "weapon CameraItem cull_mask unchanged (got %d)" % weapon_cam.cull_mask)

	if failures == 0:
		print("[TEST] PASS — minimap T1 topdown render infrastructure")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
