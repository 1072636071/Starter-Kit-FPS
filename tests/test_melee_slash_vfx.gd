## 近战剑弧粒子特效 测试（issue: melee-slash-vfx）
## 运行：godot --headless --path . res://tests/test_melee_slash_vfx.tscn --quit-after 900
## 判定：[TEST] PASS 即通过；任何 [TEST] FAIL 即失败（脚本自行 quit(1)）
extends Node

# 预加载 MeleeVFX class_name，确保 headless 模式下全局类注册
const _MeleeVFX = preload("res://scripts/melee_vfx.gd")

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
	# === 循环 1：MeleeVFX 静态工具类 ===
	# 来源：.scratch/melee-slash-vfx/issues/01-melee-vfx-helper.md
	_test_melee_vfx_create_slash()
	await get_tree().process_frame
	_test_melee_vfx_trigger()
	await get_tree().process_frame

	# === 循环 2：玩家剑弧创建与触发 ===
	# 来源：.scratch/melee-slash-vfx/issues/02-player-slash-vfx.md
	_test_player_slash_creation()
	await get_tree().process_frame
	_test_player_slash_trigger()
	await get_tree().process_frame

	# === 循环 3：怪物剑弧创建与触发 ===
	# 来源：.scratch/melee-slash-vfx/issues/03-monster-slash-vfx.md
	_test_monster_slash_creation()
	await get_tree().process_frame

	if failures == 0:
		print("[TEST] PASS — melee-slash-vfx all cycles")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)


# === 循环 1：MeleeVFX.create_slash() 节点配置正确性 ===
func _test_melee_vfx_create_slash() -> void:
	var parent := Node3D.new()
	parent.name = "TestParent"
	add_child(parent)

	var slash := MeleeVFX.create_slash(
		parent,
		MeleeVFX.COLOR_PLAYER,
		2,
		MeleeVFX.PLAYER_BOX_EXTENTS,
		Vector3(0, -0.5, -1.0)
	)

	_check(slash != null, "MeleeVFX.create_slash returns non-null GPUParticles3D")
	_check(slash is GPUParticles3D, "returned node is GPUParticles3D (got %s)" % slash.get_class())
	_check(slash.name == "MeleeSlash", "slash node name == MeleeSlash (got %s)" % slash.name)
	_check(slash.get_parent() == parent, "slash parent is the passed parent node")

	# 粒子基础属性
	_check(slash.amount == MeleeVFX.SLASH_AMOUNT,
		"slash.amount == %d (got %d)" % [MeleeVFX.SLASH_AMOUNT, slash.amount])
	_check(slash.lifetime == MeleeVFX.SLASH_LIFETIME,
		"slash.lifetime == %.2f (got %.2f)" % [MeleeVFX.SLASH_LIFETIME, slash.lifetime])
	_check(slash.one_shot == true, "slash.one_shot == true")
	_check(slash.explosiveness == 1.0, "slash.explosiveness == 1.0 (got %.2f)" % slash.explosiveness)
	_check(slash.emitting == false, "slash.emitting == false initially")
	_check(slash.layers == 2, "slash.layers == 2 (got %d)" % slash.layers)
	_check(slash.position.is_equal_approx(Vector3(0, -0.5, -1.0)),
		"slash.position == (0, -0.5, -1.0) (got %s)" % str(slash.position))

	# process_material 配置
	var proc_mat = slash.process_material
	_check(proc_mat is ParticleProcessMaterial,
		"process_material is ParticleProcessMaterial (got %s)" % proc_mat.get_class())
	if proc_mat is ParticleProcessMaterial:
		_check(proc_mat.emission_shape == ParticleProcessMaterial.EMISSION_SHAPE_BOX,
			"emission_shape == EMISSION_SHAPE_BOX (got %d)" % proc_mat.emission_shape)
		_check(proc_mat.emission_box_extents.is_equal_approx(MeleeVFX.PLAYER_BOX_EXTENTS),
			"emission_box_extents matches PLAYER_BOX_EXTENTS (got %s)" % str(proc_mat.emission_box_extents))
		_check(proc_mat.direction == Vector3(0, -1, 0),
			"direction == (0, -1, 0) (got %s)" % str(proc_mat.direction))
		_check(abs(proc_mat.spread - 25.0) < 0.1,
			"spread == 25.0 (got %.2f)" % proc_mat.spread)
		_check(proc_mat.color == MeleeVFX.COLOR_PLAYER,
			"color == COLOR_PLAYER (got %s)" % str(proc_mat.color))
		_check(proc_mat.color_ramp != null,
			"color_ramp is set (non-null)")

	# draw_pass_1 配置
	var dp1 = slash.draw_pass_1
	_check(dp1 is QuadMesh, "draw_pass_1 is QuadMesh (got %s)" % (dp1.get_class() if dp1 else "null"))
	if dp1 is QuadMesh:
		_check(dp1.size.is_equal_approx(MeleeVFX.QUAD_SIZE),
			"quad size matches QUAD_SIZE (got %s)" % str(dp1.size))
		var quad_mat = dp1.material
		_check(quad_mat is StandardMaterial3D,
			"quad material is StandardMaterial3D (got %s)" % (quad_mat.get_class() if quad_mat else "null"))
		if quad_mat is StandardMaterial3D:
			_check(quad_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA,
				"quad mat transparency == ALPHA")
			_check(quad_mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,
				"quad mat shading == UNSHADED")
			_check(quad_mat.blend_mode == BaseMaterial3D.BLEND_MODE_ADD,
				"quad mat blend == ADD")
			_check(quad_mat.billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED,
				"quad mat billboard == ENABLED")

	parent.queue_free()


# === 循环 1b：MeleeVFX.trigger() ===
func _test_melee_vfx_trigger() -> void:
	var parent := Node3D.new()
	parent.name = "TestParent2"
	add_child(parent)

	var slash := MeleeVFX.create_slash(
		parent,
		MeleeVFX.COLOR_ENEMY,
		4,
		MeleeVFX.ENEMY_BOX_EXTENTS,
		Vector3(0, 0.5, -1.5)
	)
	_check(slash.emitting == false, "slash.emitting == false before trigger")

	MeleeVFX.trigger(slash)
	_check(slash.emitting == true, "slash.emitting == true after trigger")

	parent.queue_free()


# === 循环 2：玩家剑弧节点创建 ===
func _test_player_slash_creation() -> void:
	var player_scene := preload("res://objects/player.tscn")
	var player: CharacterBody3D = player_scene.instantiate()
	player.set_physics_process(false)
	add_child(player)
	await get_tree().process_frame  # _ready 中的 instantiate

	var slash: GPUParticles3D = player.get("melee_slash")
	# 调试：检查 melee_viewmodel 和 camera_item
	var vm = player.get("melee_viewmodel")
	var ci = player.get("camera_item")
	print("[DEBUG] melee_viewmodel: ", vm, " camera_item: ", ci, " melee_slash: ", slash)
	_check(slash != null, "player.melee_slash is non-null after _ready")
	_check(slash is GPUParticles3D, "player.melee_slash is GPUParticles3D (got %s)" % slash.get_class())
	_check(slash.layers == 2, "player slash layers == 2 (got %d)" % slash.layers)

	# 位置应在 CameraItem 的本地空间：CameraItem 在 Head(0,1,0)，Hitbox 在 Player(0,0.5,-1.0)
	# → CameraItem 本地 = (0, -0.5, -1.0)
	_check(slash.position.is_equal_approx(Vector3(0, -0.5, -1.0)),
		"player slash position == (0, -0.5, -1.0) (got %s)" % str(slash.position))

	player.queue_free()


# === 循环 2b：玩家挥砍触发剑弧 ===
func _test_player_slash_trigger() -> void:
	var player_scene := preload("res://objects/player.tscn")
	var player: CharacterBody3D = player_scene.instantiate()
	player.set_physics_process(false)
	add_child(player)
	await get_tree().process_frame

	var slash: GPUParticles3D = player.get("melee_slash")
	_check(slash != null, "player2: melee_slash non-null")

	# 挥砍前：emitting = false
	_check(slash.emitting == false, "player2: slash.emitting == false before swing")

	# 触发挥砍
	player.action_melee()

	# t=0.1：仍在活跃帧之前（前摇），emitting 应为 false
	await get_tree().create_timer(0.1).timeout
	_check(slash.emitting == false, "player2: slash.emitting == false at t=0.1 (before active)")

	# t=0.25：活跃帧已开始（ACTIVE_START=0.2），emitting 应为 true
	await get_tree().create_timer(0.15).timeout
	_check(slash.emitting == true, "player2: slash.emitting == true at t=0.25 (active window)")

	# 等待挥砍结束
	await get_tree().create_timer(0.5).timeout

	player.queue_free()


# === 循环 3：怪物剑弧节点创建 ===
func _test_monster_slash_creation() -> void:
	var monster_scene := preload("res://objects/monster_melee.tscn")
	var monster: CharacterBody3D = monster_scene.instantiate()
	monster.set_physics_process(false)
	monster.set("player", null)  # 防止 AI 寻路报错
	add_child(monster)
	await get_tree().process_frame  # _ready 执行完成

	var slash: GPUParticles3D = monster.get("melee_slash")
	_check(slash != null, "monster.melee_slash is non-null after _ready")
	_check(slash is GPUParticles3D, "monster.melee_slash is GPUParticles3D (got %s)" % slash.get_class())
	_check(slash.layers == 4, "monster slash layers == 4 (layer 3 bitmask) (got %d)" % slash.layers)
	_check(slash.position.is_equal_approx(Vector3(0, 0.5, -1.5)),
		"monster slash position == (0, 0.5, -1.5) (got %s)" % str(slash.position))

	monster.queue_free()