## 受击反馈模块测试：验证 HitFeedback.flash() 的核心行为
## 运行：godot --headless --path . res://tests/test_hit_feedback.tscn --quit-after 30
## 判定：看到 [TEST] PASS 即通过；任何 [TEST] FAIL 行即失败（exit 1 由脚本自行 quit(1)）
extends Node3D

var failures: int = 0

const FLASH_COLOR := Color(1.0, 0.18, 0.18)
const FLASH_DURATION := 0.12

func _ready():
	call_deferred("_run_tests")

func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1

func _run_tests() -> void:
	# ---- T1: Model 子节点路径 ----
	# 两个 MeshInstance3D 共享同一 surface material，模拟 GLB 共享材质场景
	var shared_mat := StandardMaterial3D.new()
	shared_mat.albedo_color = Color(0.2, 0.4, 0.8)

	var target1 := Node3D.new()
	var model1 := Node3D.new()
	model1.name = "Model"
	target1.add_child(model1)
	var mesh1 := MeshInstance3D.new()
	mesh1.mesh = BoxMesh.new()
	mesh1.mesh.surface_set_material(0, shared_mat)
	model1.add_child(mesh1)
	add_child(target1)

	# 同类另一怪物（独立 mesh 资源，但 surface material 引用同一个 shared_mat）
	var target2 := Node3D.new()
	var model2 := Node3D.new()
	model2.name = "Model"
	target2.add_child(model2)
	var mesh2 := MeshInstance3D.new()
	mesh2.mesh = BoxMesh.new()
	mesh2.mesh.surface_set_material(0, shared_mat)
	model2.add_child(mesh2)
	add_child(target2)

	HitFeedback.flash(target1)
	# 同步检查：flash 内立即把 albedo 拉到 FLASH_COLOR
	var override1 := mesh1.get_surface_override_material(0) as StandardMaterial3D
	_check(override1 != null, "T1: Model 路径下设置了 override material")
	_check(override1 != shared_mat, "T1: override 是 duplicate 出的独立资源，非 shared_mat 本体")
	if override1:
		_check(override1.albedo_color.is_equal_approx(FLASH_COLOR), "T1: flash 后 albedo = FLASH_COLOR")
	# 共享材质防串色：mesh2 不应被设置 override；shared_mat.albedo_color 应保持不变
	_check(mesh2.get_surface_override_material(0) == null, "T1: 共享 shared_mat 的同类 mesh2 未被设置 override")
	_check(shared_mat.albedo_color.is_equal_approx(Color(0.2, 0.4, 0.8)), "T1: shared_mat.albedo_color 未被污染（GLB 共享材质防串色）")

	# 等待 tween 结束（~0.12s + 余量）
	await get_tree().create_timer(0.25).timeout
	if override1:
		_check(override1.albedo_color.is_equal_approx(Color(0.2, 0.4, 0.8)), "T1: tween 结束后 albedo 恢复为原色")

	# ---- T2: 无 Model 子节点回退路径（飞行敌人 enemy） ----
	var target3 := Node3D.new()
	var mesh3 := MeshInstance3D.new()
	mesh3.mesh = BoxMesh.new()
	var mat3 := StandardMaterial3D.new()
	mat3.albedo_color = Color(0.5, 0.5, 0.5)
	mesh3.mesh.surface_set_material(0, mat3)
	target3.add_child(mesh3)
	add_child(target3)

	HitFeedback.flash(target3)
	var override3 := mesh3.get_surface_override_material(0) as StandardMaterial3D
	_check(override3 != null, "T2: 无 Model 子节点时回退到 target 自身的 MeshInstance3D")
	_check(override3 != mat3, "T2: override 是 duplicate 出的独立资源")
	if override3:
		_check(override3.albedo_color.is_equal_approx(FLASH_COLOR), "T2: flash 后 albedo = FLASH_COLOR")

	# ---- T3: 连续快速受击不卡在红色 ----
	# 第一次 flash，让 tween 启动
	HitFeedback.flash(target1)
	await get_tree().create_timer(0.04).timeout  # 进入 tween 中段（颜色应在红→原色之间）
	if override1:
		var mid_color := override1.albedo_color
		# 中段不应已经接近原色（即确实还在淡出过程中）
		_check(not mid_color.is_equal_approx(Color(0.2, 0.4, 0.8)), "T3: 第一次 flash 后 0.04s 处于淡出中段（非原色）")
	# 第二次 flash：应杀掉旧 tween，把 albedo 重新拉回 FLASH_COLOR
	HitFeedback.flash(target1)
	# 同步检查：刚 flash 完 albedo 应为 FLASH_COLOR（在下一帧 tween 推进前）
	if override1:
		_check(override1.albedo_color.is_equal_approx(FLASH_COLOR), "T3: 连续受击重新触发后 albedo 重置为 FLASH_COLOR（不卡在中段颜色）")

	# ---- 清理 ----
	target1.queue_free()
	target2.queue_free()
	target3.queue_free()
	await get_tree().create_timer(0.05).timeout

	if failures == 0:
		print("[TEST] PASS — hit feedback module (T1/T2/T3)")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
