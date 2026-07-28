extends SceneTree
## 诊断：对比 微型冲锋枪.glb 与 blaster.glb 的模型结构、AABB、Y 偏移
## 运行：godot --headless --path . --script res://tools/diagnose_smg_model.gd

const WEAPON_PATHS: Array[String] = [
	"res://models/weapons/blaster.glb",
	"res://models/weapons/blaster-repeater.glb",
	"res://models/weapons/微型冲锋枪.glb",
	"res://models/weapons/微型冲锋枪-双枪口.glb",
	"res://models/weapons/短突击步枪-双枪口.glb",
	"res://models/weapons/机枪.glb",
	"res://models/weapons/半自动霰弹枪.glb",
	"res://models/weapons/4管霰弹枪.glb",
	"res://models/weapons/狙击步枪.glb",
	"res://models/weapons/狙击步枪-重型.glb",
	"res://models/weapons/双管能量枪.glb",
	"res://models/weapons/上下双枪口能量枪.glb",
	"res://models/weapons/持续射线枪.glb",
	"res://models/weapons/手托手枪-小口径.glb",
	"res://models/weapons/短柄榴弹发射器.glb",
]

# 用成员变量规避 GDScript 按值传递问题
var _aabb: AABB
var _aabb_found: bool

func _initialize():
	print("\n===== 武器模型诊断 =====\n")
	for path in WEAPON_PATHS:
		_analyze(path)
	print("===== 诊断结束 =====\n")
	quit(0)

func _analyze(path: String) -> void:
	print("----- ", path, " -----")
	var scene: PackedScene = load(path)
	if scene == null:
		print("[ERROR] 无法加载")
		return
	var inst: Node3D = scene.instantiate()
	if inst == null:
		print("[ERROR] 无法实例化")
		return

	# 根节点信息
	print("根节点: name=", inst.name, " type=", inst.get_class())
	print("根节点 position=", inst.position, " rotation_deg=", inst.rotation_degrees, " scale=", inst.scale)

	# 打印节点树（深度 3）
	_print_tree(inst, "", 0, 3)

	# 计算 AABB（合并所有 MeshInstance3D）—— 用成员变量收集
	_aabb = AABB()
	_aabb_found = false
	_collect_aabb(inst, Transform3D())
	if _aabb_found:
		print("合并 AABB: position=", _aabb.position, " size=", _aabb.size)
		print("  Y 范围: [", _aabb.position.y, ", ", _aabb.position.y + _aabb.size.y, "]")
		print("  X 范围: [", _aabb.position.x, ", ", _aabb.position.x + _aabb.size.x, "]")
		print("  Z 范围: [", _aabb.position.z, ", ", _aabb.position.z + _aabb.size.z, "]")
		# 关键：模型中心 Y 偏移（相对原点）
		var center_y := _aabb.position.y + _aabb.size.y * 0.5
		print("  中心 Y = ", center_y, " (相对根原点)")
		var center_z := _aabb.position.z + _aabb.size.z * 0.5
		print("  中心 Z = ", center_z, " (枪管方向，相对根原点)")
		# 各 mesh 的独立 AABB（局部坐标）
		print("  各 MeshInstance3D 局部 AABB:")
		for child in inst.find_children("*", "MeshInstance3D"):
			var mi := child as MeshInstance3D
			if mi and mi.mesh:
				var laabb := mi.mesh.get_aabb()
				# 累加父级 transform 得到相对根的坐标
				var xform := _get_accumulated_transform(mi, inst)
				var world_min := xform * laabb.position
				var world_max := xform * (laabb.position + laabb.size)
				print("    - ", mi.name, " local_aabb=", laabb.position, "+", laabb.size)
				print("      根空间 min=", world_min, " max=", world_max)
	else:
		print("[WARN] 未找到 MeshInstance3D")

	# 统计 MeshInstance3D 数量
	var mesh_count := 0
	for child in inst.find_children("*", "MeshInstance3D"):
		mesh_count += 1
	print("MeshInstance3D 数量: ", mesh_count)

	# 查找可能的枪口节点（名字含 muzzle/barrel/tip 等关键词）
	var muzzle_nodes: Array[Node] = []
	for child in inst.find_children("*"):
		var nname := child.name.to_lower()
		if nname.find("muzzle") >= 0 or nname.find("barrel") >= 0 or nname.find("tip") >= 0 or nname.find("枪口") >= 0:
			muzzle_nodes.append(child)
	if not muzzle_nodes.is_empty():
		print("疑似枪口节点:")
		for n in muzzle_nodes:
			var n3d := n as Node3D
			if n3d:
				print("  - ", n.name, " pos=", n3d.position)
			else:
				print("  - ", n.name, " (非 Node3D)")
	else:
		print("未找到名字含 muzzle/barrel/tip/枪口 的节点")

	print("")
	inst.free()

func _get_accumulated_transform(node: Node3D, root: Node3D) -> Transform3D:
	# 从 node 向上累积 transform 到 root（不含 root 自身）
	var xform := Transform3D()
	var cur: Node3D = node
	while cur != null and cur != root:
		xform = cur.transform * xform
		cur = cur.get_parent() as Node3D
	return xform

func _print_tree(node: Node, prefix: String, depth: int, max_depth: int) -> void:
	if depth > max_depth:
		return
	var n3d := node as Node3D
	if n3d:
		var info := prefix + node.name + " [" + node.get_class() + "]"
		if depth > 0:  # 根节点已单独打印
			info += " pos=" + str(n3d.position) + " rot=" + str(n3d.rotation_degrees) + " scale=" + str(n3d.scale)
		print(info)
	else:
		print(prefix + node.name + " [" + node.get_class() + "]")
	if depth < max_depth:
		for child in node.get_children():
			_print_tree(child, prefix + "  ", depth + 1, max_depth)

func _collect_aabb(node: Node3D, parent_xform: Transform3D) -> void:
	var xform := parent_xform * node.transform
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		var mesh: Mesh = mesh_inst.mesh
		if mesh:
			var local_aabb := mesh.get_aabb()
			for i in range(8):
				var corner := xform * local_aabb.get_endpoint(i)
				if not _aabb_found:
					_aabb.position = corner
					_aabb.size = Vector3.ZERO
					_aabb_found = true
				else:
					_aabb = _aabb.expand(corner)
	for child in node.get_children():
		if child is Node3D:
			_collect_aabb(child, xform)
