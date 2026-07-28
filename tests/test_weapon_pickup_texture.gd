## 回归测试：丢在地上的武器拾取物应有贴图
## Bug: weapon_pickup._ready() 实例化 weapon_resource.model 后未调用 _apply_texture_to_mesh，
##      而 player.gd::change_weapon 会应用 albedo_texture（GLB 导入纹理丢失的 workaround）。
##      结果：丢在地上的爆能枪没有贴图。
## 运行：godot --headless --path . res://tests/test_weapon_pickup_texture.tscn --quit-after 30
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
	# 实例化 weapon_pickup（手动调用 _ready 路径）
	var weapon_res: Weapon = load("res://weapons/blaster.tres")
	_check(weapon_res != null, "blaster.tres 加载成功")
	_check(weapon_res.albedo_texture != null,
		"blaster.tres 配置了 albedo_texture（GLB 纹理 workaround 必需）")
	_check(weapon_res.model != null, "blaster.tres 配置了 model PackedScene")

	# 通过 player.action_drop_weapon 路径生成拾取物，验证与游戏运行时一致
	var player_scene := preload("res://objects/player.tscn")
	var player := player_scene.instantiate()
	player.add_to_group("player")
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame

	# 丢枪
	var dropped_res: Weapon = player.weapons[0]
	player.action_drop_weapon()
	await get_tree().process_frame
	await get_tree().process_frame

	# 找到拾取物
	var pickup: Area3D = null
	for child in get_children():
		if child is Area3D and child.has_method("_on_body_entered"):
			pickup = child
			break
	_check(pickup != null, "拾取物节点生成")
	if pickup == null:
		_finish()
		return

	# 检查拾取物下的 model 子节点
	var model_node: Node3D = null
	for child in pickup.get_children():
		if child is Node3D and child.name != "GlowParticles":
			# 跳过 GPUParticles3D（也是 Node3D 派生）
			if not (child is GPUParticles3D):
				model_node = child
				break
	_check(model_node != null, "拾取物内含 model 子节点（武器 GLB 实例）")
	if model_node == null:
		_finish()
		return

	# 关键断言：model 的所有 MeshInstance3D 应有 override material 设置 albedo_texture
	var mesh_count := 0
	var textured_mesh_count := 0
	for mesh_inst in model_node.find_children("*", "MeshInstance3D"):
		mesh_count += 1
		var has_albedo_texture := false
		for i in range(mesh_inst.mesh.get_surface_count()):
			var mat: Material = mesh_inst.get_surface_override_material(i)
			if mat == null:
				continue
			if mat is StandardMaterial3D and mat.albedo_texture != null:
				has_albedo_texture = true
				break
		if has_albedo_texture:
			textured_mesh_count += 1

	print("[TEST] info: mesh_count=", mesh_count, " textured_mesh_count=", textured_mesh_count)
	_check(mesh_count > 0, "拾取物 model 至少含一个 MeshInstance3D（实际 %d）" % mesh_count)
	_check(textured_mesh_count == mesh_count,
		"Bug3: 拾取物所有 mesh 应被应用 albedo_texture（%d/%d 已应用）" % [textured_mesh_count, mesh_count])

	_finish()


func _finish() -> void:
	if failures == 0:
		print("[TEST] PASS — 拾取物贴图应用")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d 项断言失败" % failures)
		get_tree().quit(1)
