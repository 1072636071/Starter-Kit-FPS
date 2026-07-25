# issue 21：武器地面拾取物
# Area3D 带武器模型（缩小 0.3 倍，绕 Y 轴旋转）+ 发光粒子
# body_entered 检测 player 组 → 有空槽则装填，3 槽满则留地
# 允许重复武器（不检查同款已持有）
extends Area3D

@export var weapon_resource: Weapon
@export var durability_current: int = 0

const ROTATION_SPEED := 90.0 # 度/秒

var _model: Node3D
var _glow: GPUParticles3D


func _ready() -> void:
	# 碰撞层：让 player 能检测到
	collision_layer = 0
	collision_mask = 0
	# 用 body_entered 信号
	body_entered.connect(_on_body_entered)

	# 创建模型实例
	if weapon_resource and weapon_resource.model:
		_model = weapon_resource.model.instantiate()
		_model.scale = Vector3(0.3, 0.3, 0.3)
		_model.position = Vector3.ZERO
		add_child(_model)

	# 发光粒子
	_glow = GPUParticles3D.new()
	_glow.name = "GlowParticles"
	_glow.amount = 12
	_glow.lifetime = 0.8
	_glow.one_shot = false
	_glow.explosiveness = 0.0
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3.UP
	mat.spread = 30.0
	mat.initial_velocity_min = 0.3
	mat.initial_velocity_max = 0.8
	mat.gravity = Vector3(0, 1.0, 0)
	mat.scale_min = 0.05
	mat.scale_max = 0.12
	mat.color = Color(1.0, 0.85, 0.2, 0.6)
	_glow.process_material = mat
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	_glow.draw_pass_1 = sphere
	add_child(_glow)
	_glow.position = Vector3(0, 0.5, 0)
	_glow.emitting = true

	# 碰撞形状（球形触发器）
	var collision_shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 1.5
	collision_shape.shape = sphere_shape
	add_child(collision_shape)


func _process(delta: float) -> void:
	# 绕 Y 轴旋转
	if _model:
		_model.rotation_degrees.y += ROTATION_SPEED * delta


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if not body.has_method("get_reserve"):
		return # 不是 Player

	# 检查空槽
	var player_weapons: Array = body.weapons
	if player_weapons.size() >= body.MAX_WEAPONS:
		return # 3 槽全满，不拾取

	if weapon_resource == null:
		return

	# 有空槽，装填
	var slot := player_weapons.size()
	player_weapons.append(weapon_resource)
	body.magazine.append(weapon_resource.magazine_size)
	body.weapon_durability.append(durability_current if durability_current > 0 else weapon_resource.durability_max)

	# 弹药池初始化（若该类型不存在）
	if not body.ammo_reserve.has(weapon_resource.ammo_type):
		body.ammo_reserve[weapon_resource.ammo_type] = body.INITIAL_AMMO_PER_TYPE

	# 如果是第一把武器，自动装备
	if player_weapons.size() == 1:
		body.weapon_index = 0
		body.initiate_change_weapon(0)

	body._emit_ammo_updated()
	queue_free()
