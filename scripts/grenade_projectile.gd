# issue 23：手雷弹丸
# RigidBody3D 抛物线飞行 → 落地 body_entered 引爆
# 两种类型：EMP（减速+沉默）和破片（AOE 伤害）
extends RigidBody3D

@export var grenade_type: StringName = &"emp"

# EMP 参数
const EMP_DELAY := 0.5
const EMP_RADIUS := 6.0
const EMP_DURATION := 3.0
const EMP_SLOW_FACTOR := 0.3

# 破片参数
const FRAG_DELAY := 0.8
const FRAG_RADIUS := 5.0
const FRAG_DAMAGE_CENTER := 40.0
const FRAG_DAMAGE_EDGE := 10.0

var _detonated := false


func _ready() -> void:
	# 碰撞检测：监听 body_entered
	body_entered.connect(_on_body_entered)
	# 初始旋转让手雷有点随机感
	angular_velocity = Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))


func _on_body_entered(_body: Node) -> void:
	if _detonated:
		return
	_detonated = true

	match grenade_type:
		&"emp":
			_detonate_emp()
		&"frag":
			_detonate_frag()
		_:
			queue_free()


func _detonate_emp() -> void:
	# 延迟引爆（EMP 先等延迟再播放视觉+施加效果，保证视觉与逻辑同步）
	await get_tree().create_timer(EMP_DELAY).timeout
	if not is_inside_tree():
		return

	# 视觉：蓝色球形粒子
	_spawn_explosion_vfx(Color(0.2, 0.5, 1.0, 0.8), EMP_RADIUS)

	# 检测范围内所有怪物
	var monsters := _get_monsters_in_radius(EMP_RADIUS)
	for m in monsters:
		if not is_instance_valid(m):
			continue
		_apply_emp_effect(m)

	queue_free()


func _detonate_frag() -> void:
	# 视觉：橙红色球形粒子
	_spawn_explosion_vfx(Color(1.0, 0.3, 0.1, 0.9), FRAG_RADIUS)

	# 延迟引爆
	await get_tree().create_timer(FRAG_DELAY).timeout
	if not is_inside_tree():
		return

	# 检测范围内所有怪物
	var monsters := _get_monsters_in_radius(FRAG_RADIUS)
	for m in monsters:
		if not is_instance_valid(m):
			continue
		var dist := global_position.distance_to(m.global_position)
		# 线性衰减：中心 40 → 边缘 10
		var ratio := clampf(1.0 - (dist / FRAG_RADIUS), 0.0, 1.0)
		var dmg := lerpf(FRAG_DAMAGE_EDGE, FRAG_DAMAGE_CENTER, ratio)
		if m.has_method("damage"):
			m.damage(dmg)

	queue_free()


func _get_monsters_in_radius(radius: float) -> Array[Node]:
	var result: Array[Node] = []
	# 使用 Area3D 一次性检测
	var space := get_world_3d().direct_space_state
	if space == null:
		return result

	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position)
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var hits := space.intersect_shape(query)
	for hit in hits:
		var collider := hit.get("collider")
		if collider and is_instance_valid(collider) and collider.is_in_group("monster"):
			result.append(collider)
	return result


func _apply_emp_effect(target: Node) -> void:
	# 减速：移速 ×0.3
	if "speed" in target:
		var original := target.speed
		target.speed = original * EMP_SLOW_FACTOR
		# 3 秒后恢复
		await get_tree().create_timer(EMP_DURATION).timeout
		if is_instance_valid(target) and "speed" in target:
			target.speed = original

	# 禁用 ATTACK：若怪物有 attack_disabled 属性则设为 true
	if "attack_disabled" in target:
		target.attack_disabled = true
		await get_tree().create_timer(EMP_DURATION).timeout
		if is_instance_valid(target) and "attack_disabled" in target:
			target.attack_disabled = false
	# 若怪物使用 FSM 且 state 为 ATTACK，尝试 set_state
	elif target.has_method("set_state"):
		# 通过模块系统禁用攻击：若怪物有 modules，查找是否有 disable_attack 方法
		if "modules" in target:
			var mods = target.modules
			if mods is Array:
				for mod in mods:
					if is_instance_valid(mod) and mod.has_method("disable_attack"):
						mod.disable_attack(EMP_DURATION)
						break


func _spawn_explosion_vfx(color: Color, radius: float) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 48
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 1.0
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3.UP
	mat.spread = 180.0
	mat.initial_velocity_min = radius * 0.5
	mat.initial_velocity_max = radius * 1.2
	mat.gravity = Vector3(0, 0, 0)
	mat.scale_min = 0.3
	mat.scale_max = 0.8
	mat.color = color
	particles.process_material = mat
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	particles.draw_pass_1 = sphere
	var parent := get_parent()
	if parent == null:
		parent = self
	parent.add_child(particles)
	particles.global_position = global_position
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
