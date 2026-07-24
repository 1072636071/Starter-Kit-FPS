extends Node
class_name HitFeedback

## 怪物受击视觉反馈：受击瞬间把可视模型染红、~0.12s 内淡出回原色。
## 供三种怪物（monster_melee / monster_ranged / enemy）的 damage() 调用：
##     HitFeedback.flash(self)
## 见 ADR 005 与 CONTEXT.md「受击反馈」一节。

const FLASH_COLOR := Color(1.0, 0.18, 0.18)
const FLASH_DURATION := 0.12

# 每个 MeshInstance3D 的染色状态，按 instance_id 索引：
#   { mesh_id: { "tween": Tween, "original_colors": { surface_idx: Color } } }
# 用 instance_id 避免 Node 引用悬挂；mesh 释放后条目滞留为陈旧空壳（几字节，可忽略）。
static var _state: Dictionary = {}

## 触发命中变色。优先染色 target/Model，否则回退到 target 自身的 MeshInstance3D。
static func flash(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
	var visual: Node = target.get_node_or_null("Model")
	if visual == null:
		visual = target
	var meshes := visual.find_children("*", "MeshInstance3D", true, false)
	for mesh in meshes:
		_flash_mesh(mesh as MeshInstance3D)

static func _flash_mesh(mesh: MeshInstance3D) -> void:
	if mesh == null or mesh.mesh == null:
		return
	var mesh_id := mesh.get_instance_id()
	var entry: Dictionary = _state.get(mesh_id, {})
	var original_colors: Dictionary = entry.get("original_colors", {})

	# 连续快速受击：杀掉旧 tween，避免卡在中途的颜色
	var prev_tween: Tween = entry.get("tween", null)
	if prev_tween != null and prev_tween.is_valid():
		prev_tween.kill()

	var surface_count: int = mesh.mesh.get_surface_count()
	var active_tween: Tween = null
	var first := true
	for i in surface_count:
		var cur_mat: Material = mesh.get_surface_override_material(i)
		var shared_mat: Material = mesh.mesh.surface_get_material(i)
		var base_mat: Material = cur_mat if cur_mat != null else shared_mat
		if base_mat == null or not (base_mat is StandardMaterial3D):
			continue
		# 首次染色：duplicate 一次以解除 GLB 共享材质的链接，避免同类怪物串色
		var local_mat: StandardMaterial3D = cur_mat as StandardMaterial3D
		if not original_colors.has(i):
			local_mat = (base_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			original_colors[i] = local_mat.albedo_color
			mesh.set_surface_override_material(i, local_mat)
		# 强制拉回红色再 tween 到原色；连续受击也能即时复燃
		local_mat.albedo_color = FLASH_COLOR
		if active_tween == null:
			active_tween = mesh.create_tween()
		if first:
			active_tween.tween_property(local_mat, "albedo_color", original_colors[i], FLASH_DURATION)
			first = false
		else:
			active_tween.parallel().tween_property(local_mat, "albedo_color", original_colors[i], FLASH_DURATION)

	entry["original_colors"] = original_colors
	entry["tween"] = active_tween
	_state[mesh_id] = entry
