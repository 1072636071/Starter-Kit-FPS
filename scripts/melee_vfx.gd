class_name MeleeVFX
## 近战剑弧拖尾粒子特效（ADR 020）
## 为玩家和怪物近战攻击提供可见的攻击范围视觉反馈。
## 使用 GPUParticles3D 一次性爆发，在活跃帧期间显示弧形光效。

# 共享配置
const SLASH_LIFETIME := 0.2
const SLASH_AMOUNT := 30
const SLASH_SPEED_SCALE := 1.5
const SLASH_EXPLOSIVENESS := 1.0 # 一次性全部发射

# 玩家配色：青白冷色
const COLOR_PLAYER := Color(0.3, 0.7, 1.0, 0.85)
# 敌人配色：红橙暖色，与玩家区分
const COLOR_ENEMY := Color(1.0, 0.25, 0.15, 0.85)

# 粒子 quad 大小
const QUAD_SIZE := Vector2(0.4, 0.15)

# 命中区半尺寸（匹配 BoxShape3D(1.5, 1.5, 2.0) 的一半）
const PLAYER_BOX_EXTENTS := Vector3(0.75, 0.75, 1.0)
# 怪物近战攻击范围更大（attack_range + 0.8 ≈ 2.8m），用更大的盒子
const ENEMY_BOX_EXTENTS := Vector3(1.0, 1.0, 1.4)


## 创建配置好的剑弧粒子节点
## parent: 挂载的父节点
## color: 粒子颜色
## cull_layer: 渲染层 bit（player=2 weapon cam, enemy=4 layer 3）
## box_extents: 发射盒半尺寸
## local_pos: 相对父节点的本地位置
static func create_slash(parent: Node3D, color: Color, cull_layer: int,
	box_extents: Vector3, local_pos: Vector3) -> GPUParticles3D:
	
	var particles := GPUParticles3D.new()
	particles.name = "MeleeSlash"
	particles.amount = SLASH_AMOUNT
	particles.lifetime = SLASH_LIFETIME
	particles.one_shot = true
	particles.explosiveness = SLASH_EXPLOSIVENESS
	particles.speed_scale = SLASH_SPEED_SCALE
	particles.emitting = false
	particles.layers = cull_layer
	particles.position = local_pos

	# 粒子行为材质
	var proc_mat := ParticleProcessMaterial.new()
	proc_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc_mat.emission_box_extents = box_extents
	proc_mat.direction = Vector3(0, -1, 0)      # 下劈方向
	proc_mat.spread = 25.0                        # 扇形扩散，形成弧面
	proc_mat.flatness = 0.7                       # 压扁在 XY 平面，弧面更明显
	proc_mat.initial_velocity_min = 3.0
	proc_mat.initial_velocity_max = 8.0
	proc_mat.scale_min = 0.3
	proc_mat.scale_max = 0.8
	proc_mat.damping_min = 3.0                    # 快速减速，粒子不飞太远
	proc_mat.damping_max = 6.0
	proc_mat.gravity = Vector3(0, 3.0, 0)        # 轻微上飘，弧线更自然
	proc_mat.color = color

	# 颜色渐变：中间最亮，两端淡出
	var gradient := Gradient.new()
	# 用 set_offset 调整默认 2 个点，再添加剩余点
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, Color(color.r, color.g, color.b, 0.0))
	gradient.set_offset(1, 0.15)
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	gradient.add_point(0.3, Color(color.r, color.g, color.b, 0.8))
	gradient.add_point(0.45, Color(color.r, color.g, color.b, 0.0))
	gradient.add_point(0.6, Color(color.r, color.g, color.b, 0.0))
	gradient.add_point(0.75, Color(color.r, color.g, color.b, 0.5))
	gradient.add_point(0.9, Color(color.r, color.g, color.b, 0.0))
	gradient.add_point(1.0, Color(color.r, color.g, color.b, 0.0))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	gradient_tex.width = 256
	proc_mat.color_ramp = gradient_tex

	# 缩放曲线：快速放大再缩小
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0, 0.1))
	scale_curve.add_point(Vector2(0.3, 1.0))
	scale_curve.add_point(Vector2(0.7, 0.3))
	scale_curve.add_point(Vector2(1, 0.0))
	var curve_tex := CurveTexture.new()
	curve_tex.curve = scale_curve
	curve_tex.width = 256
	proc_mat.scale_curve = curve_tex

	particles.process_material = proc_mat

	# 粒子 quad mesh：发光扁条
	var quad := QuadMesh.new()
	quad.size = QUAD_SIZE
	quad.orientation = QuadMesh.FACE_Z
	var glow_mat := StandardMaterial3D.new()
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow_mat.albedo_color = Color.WHITE
	glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	glow_mat.billboard_keep_scale = true
	glow_mat.disable_receive_shadows = true
	quad.material = glow_mat
	particles.draw_pass_1 = quad

	parent.add_child(particles)
	return particles


## 触发一次剑弧爆发
static func trigger(particles: GPUParticles3D) -> void:
	if particles and is_instance_valid(particles):
		particles.restart()
		particles.emitting = true