## 回归测试：新武器 viewmodel 视觉对齐（issue 22）
## Bug: 微型冲锋枪等 kenney 新武器模型比爆能枪低、枪口闪光错位
## 根因：新武器 GLB 原点在模型中心（非底部），尺寸约为 blaster 的 1/2~1/3，
##       但 .tres 未配置 scale/position，muzzle_position 直接复用 blaster 值
## 修复：Weapon 新增 scale 字段；player.gd::change_weapon 应用 scale；
##       每把新武器 .tres 按 AABB 计算填入 scale + position.y，使视觉中心对齐 blaster 的 Y=0.45
## 运行：godot --headless --path . --script res://tests/test_weapon_viewmodel_align.gd
extends SceneTree

const BLASTER_RES := "res://weapons/blaster.tres"
const BLASTER_CENTER_Y := 0.45  # blaster AABB 中心 Y（原点在底部）

## 待验证的新武器 .tres（kenney 新增，原点在模型中心）
const NEW_WEAPONS: Array[String] = [
	"res://weapons/微型冲锋枪.tres",
	"res://weapons/微型冲锋枪-双枪口.tres",
	"res://weapons/短突击步枪-双枪口.tres",
	"res://weapons/机枪.tres",
	"res://weapons/半自动霰弹枪.tres",
	"res://weapons/4管霰弹枪.tres",
	"res://weapons/狙击步枪.tres",
	"res://weapons/狙击步枪-重型.tres",
	"res://weapons/双管能量枪.tres",
	"res://weapons/上下双枪口能量枪.tres",
	"res://weapons/持续射线枪.tres",
	"res://weapons/手托手枪-小口径.tres",
	"res://weapons/短柄榴弹发射器.tres",
]

var failures: int = 0
var _aabb: AABB
var _aabb_found: bool


func _initialize() -> void:
	print("\n===== test_weapon_viewmodel_align =====\n")
	_test_scale_field_exists()
	_test_change_weapon_applies_scale()
	_test_blaster_reference()
	for path in NEW_WEAPONS:
		_test_weapon_alignment(path)
	_print_summary()
	quit(1 if failures > 0 else 0)


func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1


## 1. Weapon 资源必须有 scale 字段（默认 Vector3.ONE）
func _test_scale_field_exists() -> void:
	print("--- 1. Weapon.scale 字段存在性 ---")
	var blaster: Weapon = load(BLASTER_RES)
	_check(blaster != null, "blaster.tres 加载成功")
	# Weapon.gd 声明了 scale 字段；blaster 未显式设置时应为默认值 (1,1,1)
	_check(blaster.scale == Vector3.ONE,
		"blaster.scale 默认值 = (1,1,1)（got %s）" % blaster.scale)


## 2. player.gd::change_weapon 必须把 weapon.scale 应用到模型实例
func _test_change_weapon_applies_scale() -> void:
	print("--- 2. change_weapon 应用 scale ---")
	var player_src := FileAccess.get_file_as_string("res://objects/player.gd")
	_check(player_src.find("weapon_model.scale = weapon.scale") >= 0,
		"player.gd 包含 `weapon_model.scale = weapon.scale`（issue 22 修复关键行）")


## 3. blaster 参考基准：原点在底部，中心 Y=0.45
func _test_blaster_reference() -> void:
	print("--- 3. blaster 参考基准 ---")
	var blaster: Weapon = load(BLASTER_RES)
	var model_inst: Node3D = blaster.model.instantiate()
	var aabb := _compute_aabb(model_inst)
	_check(aabb.size.y > 0.5, "blaster 模型非空（Y size=%.3f）" % aabb.size.y)
	var center_y := aabb.position.y + aabb.size.y * 0.5
	_check(absf(center_y - BLASTER_CENTER_Y) < 0.01,
		"blaster 中心 Y = %.3f（期望 %.3f，原点在底部）" % [center_y, BLASTER_CENTER_Y])
	var max_z := aabb.position.z + aabb.size.z
	print("    blaster: size=%s center_y=%.3f max_z=%.3f" % [aabb.size, center_y, max_z])
	model_inst.free()


## 4. 每把新武器：scale + position.y 应使视觉中心 Y 对齐 blaster (0.45)
##    且 muzzle_position.Z 应使枪口闪光在枪口前方（不落后于枪口）
func _test_weapon_alignment(res_path: String) -> void:
	print("--- 4. 对齐验证: ", res_path, " ---")
	var w: Weapon = load(res_path)
	_check(w != null, "%s 加载成功" % res_path)
	if w == null:
		return

	# scale 不应为默认 (1,1,1)（新武器都需要放大）
	_check(w.scale != Vector3.ONE,
		"%s scale 已配置（got %s，非默认 1,1,1）" % [res_path, w.scale])

	# 计算模型 AABB
	var model_inst: Node3D = w.model.instantiate()
	var aabb := _compute_aabb(model_inst)
	_check(aabb.size.y > 0.01, "%s 模型非空" % res_path)
	if aabb.size.y <= 0.01:
		model_inst.free()
		return

	var model_center_y := aabb.position.y + aabb.size.y * 0.5
	var model_max_z := aabb.position.z + aabb.size.z

	# 应用 scale 后的视觉中心 Y（相对原点）
	var visual_center_y := model_center_y * w.scale.y + w.position.y
	# 与 blaster 中心 Y 比较（容差 0.05，允许小数四舍五入误差）
	_check(absf(visual_center_y - BLASTER_CENTER_Y) < 0.05,
		"%s 视觉中心 Y = %.3f（期望 %.3f ± 0.05）" % [res_path, visual_center_y, BLASTER_CENTER_Y])

	# 枪口闪光位置验证：muzzle 在 container-local 的 Z = -muzzle_position.z
	# 枪口（模型 max_z 经 180° 旋转 + scale）在 container-local 的 Z = -(model_max_z * scale.z)
	# 要求 muzzle_z < barrel_tip_z（闪光在前方），即 -muzzle_pos.z < -(max_z*scale)
	# 等价于 muzzle_position.z > model_max_z * scale.z
	var barrel_tip_z := model_max_z * w.scale.z
	_check(w.muzzle_position.z > barrel_tip_z,
		"%s 枪口闪光在前方（muzzle_z=%.3f > 枪口_z=%.3f）" % [res_path, w.muzzle_position.z, barrel_tip_z])

	print("    size=%s scale=%s pos.y=%.3f → visual_center_y=%.3f barrel_tip_z=%.3f muzzle_z=%.3f" % [
		aabb.size, w.scale, w.position.y, visual_center_y, barrel_tip_z, w.muzzle_position.z
	])
	model_inst.free()


func _print_summary() -> void:
	print("\n===== 测试总结 =====")
	if failures == 0:
		print("[TEST] PASS — 新武器 viewmodel 对齐")
	else:
		print("[TEST] FAIL — %d 项断言失败" % failures)


## 递归计算 Node3D 的合并 AABB（用成员变量规避 GDScript 按值传递）
func _compute_aabb(root: Node3D) -> AABB:
	_aabb = AABB()
	_aabb_found = false
	_collect_aabb(root, Transform3D())
	return _aabb


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
