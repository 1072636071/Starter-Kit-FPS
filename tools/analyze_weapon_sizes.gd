extends SceneTree
## 分析所有近战武器 GLB 模型的原始尺寸（AABB）
## 运行：godot --headless --path . --script res://tools/analyze_weapon_sizes.gd

func _initialize():
	var dir := DirAccess.open("res://models/melee_weapons")
	if not dir:
		print("[ERROR] 无法打开 models/melee_weapons 目录")
		quit(1)
		return

	var results: Array[Dictionary] = []

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".glb"):
			var path := "res://models/melee_weapons/" + file_name
			var scene: PackedScene = load(path)
			if scene:
				var inst: Node3D = scene.instantiate()
				var aabb := _get_combined_aabb(inst)
				results.append({
					"name": file_name,
					"size": aabb.size,
					"max_axis": maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z)),
				})
				inst.free()
			else:
				print("[WARN] 无法加载: ", path)
		file_name = dir.get_next()
	dir.list_dir_end()

	# 按最大轴排序
	results.sort_custom(func(a, b): return a["max_axis"] > b["max_axis"])

	print("\n===== 近战武器模型尺寸分析 =====")
	print("（单位：Godot 世界单位/米，按最大轴降序）\n")
	print("%-28s %10s %10s %10s %10s" % ["模型文件", "X(宽)", "Y(高)", "Z(深)", "最大轴"])
	print("-".repeat(72))
	for r in results:
		var s: Vector3 = r["size"]
		print("%-28s %10.3f %10.3f %10.3f %10.3f" % [r["name"], s.x, s.y, s.z, r["max_axis"]])
	print("-".repeat(72))
	print("共 %d 个模型" % results.size())

	# 给出缩放建议（目标：世界空间中武器长约 0.6-0.8m）
	print("\n===== 缩放建议（目标世界尺寸 ≈ 0.7m）=====\n")
	print("%-28s %12s %12s" % ["模型文件", "怪物用(×0.5父级)", "玩家viewmodel用"])
	print("-".repeat(56))
	for r in results:
		var max_ax: float = r["max_axis"]
		if max_ax < 0.001:
			continue
		# 怪物：父级 CharacterModel scale=0.5，目标世界 0.7m → local_scale = 0.7 / (0.5 * max_ax)
		var monster_scale := 0.7 / (0.5 * max_ax)
		# 玩家 viewmodel：无父级缩放，目标视觉约 0.7m（viewmodel 空间）
		var player_scale := 0.7 / max_ax
		print("%-28s %12.4f %12.4f" % [r["name"], monster_scale, player_scale])

	quit(0)

func _get_combined_aabb(node: Node3D) -> AABB:
	var combined := AABB()
	var found := false
	_collect_aabb(node, Transform3D(), combined, found)
	return combined

func _collect_aabb(node: Node3D, parent_xform: Transform3D, combined: AABB, found: bool) -> void:
	var xform := parent_xform * node.transform
	if node is MeshInstance3D:
		var mesh: Mesh = node.mesh
		if mesh:
			var local_aabb := mesh.get_aabb()
			# 变换 AABB 的 8 个角点取包围盒
			for i in range(8):
				var corner := xform * local_aabb.get_endpoint(i)
				if not found:
					combined = AABB(corner, Vector3.ZERO)
					found = true
				else:
					combined = combined.expand(corner)
	for child in node.get_children():
		if child is Node3D:
			_collect_aabb(child, xform, combined, found)
