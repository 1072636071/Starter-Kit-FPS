extends "res://objects/monster_base.gd"
## 远程怪物：与玩家保持距离，持枪发射弹幕攻击
## T1: 持枪模型 + 枪口开火 + 后坐/闪光反馈
## T4/T5 骨骼移动/待机/死亡动画已在基类实现

const CombatUtils = preload("res://scripts/combat_utils.gd")

@export var move_speed: float = 2.5
@export var chase_range: float = 30.0
@export var preferred_distance: float = 10.0
@export var too_close_distance: float = 5.0
@export var attack_damage: float = 8.0
@export var attack_cooldown: float = 1.8
@export var burst_count: int = 3
@export var burst_interval: float = 0.15
@export var health: float = 80.0
@export var enemy_spread: float = 0.08
## 枪模型（默认 blaster.glb）；留空则不挂枪
@export var gun_model: PackedScene = preload("res://models/weapons/blaster.glb")
## 枪口闪光帧动画（复用 burst_animation.tres）
@export var muzzle_flash_frames: SpriteFrames = preload("res://sprites/burst_animation.tres")

var muzzle: Marker3D
var gun_instance: Node3D

func _ready():
	super._ready()

	# T1: 挂枪模型 + 枪口 Marker3D + 常驻持枪姿态
	if gun_model and arm_right:
		gun_instance = gun_model.instantiate()
		arm_right.add_child(gun_instance)
		# 本地偏移：手臂远端→手掌位置；枪管朝怪物前方（-z）
		gun_instance.position = Vector3(0.0, -0.25, 0.05)
		gun_instance.rotation_degrees = Vector3(90, 0, 0)
		gun_instance.scale = Vector3(0.5, 0.5, 0.5)
		# 枪口 Marker3D：枪管前端（局部 -z 方向，即怪物前方）
		muzzle = Marker3D.new()
		muzzle.name = "Muzzle"
		muzzle.position = Vector3(0.0, 0.0, -0.45)
		gun_instance.add_child(muzzle)
		# 枪模型 layers = 4（layer 3：进主相机，不进小地图）
		for child in gun_instance.find_children("*", "MeshInstance3D", true, false):
			child.layers = 4
		# 枪口闪光 AnimatedSprite3D
		if muzzle_flash_frames:
			var flash := AnimatedSprite3D.new()
			flash.name = "MuzzleFlash"
			flash.frames = muzzle_flash_frames
			flash.position = muzzle.position
			flash.layers = 4
			flash.visible = false
			gun_instance.add_child(flash)
	# 常驻持枪姿态（0.167s 播完停在末帧）
	if anim_player:
		anim_player.play("holding-right")
		_current_anim = "holding-right"

func _physics_process(delta):
	if _dead or not player:
		return

	# 重力
	gravity += 20.0 * delta
	if gravity > 0 and is_on_floor():
		gravity = 0.0

	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()

	# 面向玩家
	_face_direction(to_player)

	# 通过 NavMesh 寻路获取朝玩家的路径方向（可绕墙、跨过 ≤ step_height 的台阶）
	nav_agent.target_position = player.global_position
	var path_dir := Vector3.ZERO
	if not nav_agent.is_navigation_finished():
		var to_next := nav_agent.get_next_path_position() - global_position
		to_next.y = 0.0
		if to_next.length() > 0.1:
			path_dir = to_next.normalized()

	# 移动逻辑：保持理想距离
	if distance < chase_range and not _is_attacking:
		var path_base := path_dir if path_dir != Vector3.ZERO else to_player.normalized()
		if distance < too_close_distance:
			# 太近了，后退
			velocity.x = -path_base.x * move_speed
			velocity.z = -path_base.z * move_speed
		elif distance > preferred_distance + 2.0:
			# 太远了，靠近
			velocity.x = path_base.x * move_speed
			velocity.z = path_base.z * move_speed
		else:
			# 在理想距离，横向游走
			var strafe := path_base.cross(Vector3.UP)
			velocity.x = strafe.x * move_speed * 0.5
			velocity.z = strafe.z * move_speed * 0.5

		# 攻击判定
		if distance < preferred_distance + 3.0 and _can_attack:
			_start_attack()
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 5)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 5)

	velocity.y = -gravity
	move_and_slide()

	# T4: 骨骼动画选择器（静止时保持持枪瞄准姿态）
	_select_animation("holding-right")

## T1: 发动攻击：保持持枪姿态 + 连射（后坐/闪光/音效在 _fire_projectile 内）
func _start_attack():
	_is_attacking = true
	_can_attack = false
	attack_timer.start()
	await _fire_burst()
	_is_attacking = false

## 连射
func _fire_burst():
	for i in burst_count:
		_fire_projectile()
		if i < burst_count - 1:
			await get_tree().create_timer(burst_interval).timeout

## T1: 发射单个弹幕（从 Muzzle 世界坐标生成，含后坐/闪光/音效）
func _fire_projectile():
	if _dead or not player:
		return

	Audio.play("sounds/enemy_attack.ogg")

	var projectile_scene = preload("res://objects/projectile.tscn")
	var projectile_instance = projectile_scene.instantiate()

	var target_pos := player.global_position + Vector3(0, 0.5, 0)
	# 从枪口 Muzzle 射出（取代身体 ShootPoint）
	var shoot_origin: Vector3
	if muzzle:
		shoot_origin = muzzle.global_position
	else:
		shoot_origin = global_position + Vector3(0, 1.0, 0)
	var shoot_direction := (target_pos - shoot_origin).normalized()

	# 距离衰减散布
	shoot_direction = CombatUtils.apply_enemy_spread(shoot_direction, enemy_spread, shoot_origin.distance_to(target_pos))

	projectile_instance.direction = shoot_direction
	projectile_instance.speed = 20.0
	projectile_instance.damage = attack_damage
	projectile_instance.max_distance = 35.0
	projectile_instance.color = Color(0.8, 0.1, 1.0) # 紫色弹幕
	projectile_instance.shooter = self

	get_tree().root.add_child(projectile_instance)
	projectile_instance.global_position = shoot_origin

	# T1: 枪模型后坐回弹
	# 枪口在局部 -z（前方），后坐沿 +z（后方）推再回位，叠加于 holding-right 骨骼姿态
	if gun_instance:
		var recoil := create_tween()
		recoil.tween_property(gun_instance, "position:z", gun_instance.position.z + 0.07, 0.05)
		recoil.tween_property(gun_instance, "position:z", gun_instance.position.z, 0.1)

	# T1: 枪口闪光一次性播放
	_play_muzzle_flash()

## T1: 枪口闪光
func _play_muzzle_flash() -> void:
	if not gun_instance:
		return
	var flash := gun_instance.get_node_or_null("MuzzleFlash") as AnimatedSprite3D
	if not flash:
		return
	flash.visible = true
	flash.frame = 0
	flash.play("default")
	# 播完后隐藏（3 帧 / 30fps ≈ 0.1s）
	get_tree().create_timer(0.12).timeout.connect(func():
		if is_instance_valid(flash):
			flash.visible = false
	)
