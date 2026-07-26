extends "res://objects/monster_base.gd"
## 远程怪物：与玩家保持距离，持枪发射弹幕攻击
## FSM 状态行为覆盖 + 随机 strafe（ADR 017）

const CombatUtils = preload("res://scripts/combat_utils.gd")
const MONSTER_TYPE: StringName = &"monster_ranged"

## 弹体命中玩家信号（issue 15：DebuffOnHit 模块通过此信号解耦）
signal projectile_hit_player(player)

@export var preferred_distance: float = 10.0
@export var too_close_distance: float = 5.0
@export var burst_count: int = 3
@export var burst_interval: float = 0.15
@export var enemy_spread: float = 0.08
## 枪模型（默认 blaster.glb）；留空则不挂枪
@export var gun_model: PackedScene = preload("res://models/weapons/blaster.glb")
## 枪口闪光帧动画
@export var muzzle_flash_frames: SpriteFrames = preload("res://sprites/burst_animation.tres")

var muzzle: Marker3D
var gun_instance: Node3D

# 随机 strafe
var _strafe_dir: float = 1.0
var _strafe_switch_timer: float = 0.0
const STRAFE_SWITCH_INTERVAL := 2.5

# 连锁 Aggro：怪物开枪的 alert 传播半径
const SHOOT_ALERT_RADIUS := 50.0

func _monster_type() -> StringName:
	return MONSTER_TYPE

func _get_attack_range() -> float:
	return preferred_distance + 3.0

func _get_idle_anim() -> String:
	return "holding-right"

## 只在 parent @export 未被 .tscn 覆写时才设置远程默认值
func _configure_stats() -> void:
	if move_speed == 3.0: move_speed = 2.5
	if chase_range == 50.0: chase_range = 60.0
	if attack_damage == 10.0: attack_damage = 8.0
	if attack_cooldown == 1.5: attack_cooldown = 1.8
	if health == 100.0: health = 80.0
	if awareness_range == 16.0: awareness_range = 24.0
	if jump_height == 2.0: jump_height = 2.0

func _ready():
	_configure_stats()
	super._ready()

	# 随机 strafe 方向
	_strafe_dir = [-1.0, 1.0].pick_random()
	_strafe_switch_timer = randf_range(1.5, 3.0)

	# 挂枪模型 + 枪口 + 常驻持枪姿态
	if gun_model and arm_right:
		gun_instance = gun_model.instantiate()
		arm_right.add_child(gun_instance)
		gun_instance.position = Vector3(0.0, -0.25, 0.05)
		gun_instance.rotation_degrees = Vector3(90, 0, 0)
		gun_instance.scale = Vector3(0.5, 0.5, 0.5)
		muzzle = Marker3D.new()
		muzzle.name = "Muzzle"
		muzzle.position = Vector3(0.0, 0.0, -0.45)
		gun_instance.add_child(muzzle)
		for child in gun_instance.find_children("*", "MeshInstance3D", true, false):
			child.layers = 4
		if muzzle_flash_frames:
			var flash := AnimatedSprite3D.new()
			flash.name = "MuzzleFlash"
			flash.frames = muzzle_flash_frames
			flash.position = muzzle.position
			flash.layers = 4
			flash.visible = false
			gun_instance.add_child(flash)
	# 常驻持枪姿态
	if anim_player:
		anim_player.play("holding-right")
		_current_anim = "holding-right"

# === 状态转换覆盖（远程怪特有：太近→RETREAT）===
func _evaluate_transitions() -> void:
	if not player:
		return
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()

	match _ai_state:
		AIState.IDLE:
			# IDLE → CHASE：被动感知（awareness_range 内 + 视线）或警觉传播（alert 穿墙）
			if distance < awareness_range and _has_los:
				_change_state(AIState.CHASE)
			elif AlertSystem.has_alert_nearby(global_position, chase_range):
				_change_state(AIState.CHASE)
		AIState.CHASE:
			if not _has_los:
				_change_state(AIState.LOST)
			elif distance < too_close_distance:
				_change_state(AIState.RETREAT)
			elif distance < preferred_distance + 3.0 and _can_attack and not _is_attacking:
				_change_state(AIState.ATTACK)
		AIState.ATTACK:
			pass  # 攻击完成后切回
		AIState.RETREAT:
			if not _has_los:
				_change_state(AIState.LOST)
			elif distance > too_close_distance + 2.0:
				_change_state(AIState.CHASE)
		AIState.LOST:
			if _has_los:
				var dist := (player.global_position - global_position)
				dist.y = 0.0
				if dist.length() < chase_range:
					_change_state(AIState.CHASE)

# === CHASE：保持理想距离 + 随机 strafe ===
func _tick_chase(delta: float) -> void:
	if not player:
		return
	# strafe 方向随机切换
	_strafe_switch_timer -= delta
	if _strafe_switch_timer <= 0.0:
		_strafe_switch_timer = randf_range(1.5, 3.0)
		_strafe_dir = -_strafe_dir

	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()

	# 路径更新
	if _path_timer <= 0.0:
		_path_timer = path_update_interval
		nav_agent.target_position = player.global_position

	var path_dir := _get_nav_direction()
	var path_base := path_dir if path_dir != Vector3.ZERO else to_player.normalized()

	if distance > preferred_distance + 2.0:
		# 太远，靠近
		_desired_velocity = Vector3(path_base.x * move_speed, -gravity, path_base.z * move_speed)
	else:
		# 理想距离，strafe
		var strafe := path_base.cross(Vector3.UP) * _strafe_dir
		_desired_velocity = Vector3(strafe.x * move_speed * 0.5, -gravity, strafe.z * move_speed * 0.5)

	_face_direction(to_player)

	# 攻击判定（在理想距离内）
	if distance < preferred_distance + 3.0 and _can_attack and not _is_attacking:
		_start_attack()

# === RETREAT：后退 ===
func _tick_retreat(_delta: float) -> void:
	if not player:
		return
	var to_player := player.global_position - global_position
	to_player.y = 0.0

	if _path_timer <= 0.0:
		_path_timer = path_update_interval
		nav_agent.target_position = player.global_position

	var path_dir := _get_nav_direction()
	var path_base := path_dir if path_dir != Vector3.ZERO else to_player.normalized()
	# 反方向后退
	_desired_velocity = Vector3(-path_base.x * move_speed, -gravity, -path_base.z * move_speed)
	_face_direction(to_player)

# === ATTACK：保持持枪 + 连射 ===
func _tick_attack(_delta: float) -> void:
	_desired_velocity = Vector3(0, -gravity, 0)
	if not _is_attacking and _can_attack:
		_start_attack()

func _start_attack():
	_is_attacking = true
	_can_attack = false
	attack_timer.start()
	await _fire_burst()
	_is_attacking = false
	# 攻击完成后切回 CHASE 或 RETREAT
	if player:
		var to_player := player.global_position - global_position
		to_player.y = 0.0
		if to_player.length() < too_close_distance:
			_change_state(AIState.RETREAT)
		elif _has_los:
			_change_state(AIState.CHASE)
		else:
			_change_state(AIState.IDLE)
	else:
		_change_state(AIState.IDLE)

## 连射
func _fire_burst():
	for i in burst_count:
		_fire_projectile()
		if i < burst_count - 1:
			await get_tree().create_timer(burst_interval).timeout

## 发射单个弹幕
func _fire_projectile():
	if _dead or not player:
		return

	Audio.play("sounds/enemy_attack.ogg")

	# 连锁 Aggro：怪物开枪 emit alert（穿墙）
	AlertSystem.emit_alert(global_position, SHOOT_ALERT_RADIUS)

	var projectile_scene = preload("res://objects/projectile.tscn")
	var projectile_instance = projectile_scene.instantiate()

	var target_pos := player.global_position + Vector3(0, 0.5, 0)
	var shoot_origin: Vector3
	if muzzle:
		shoot_origin = muzzle.global_position
	else:
		shoot_origin = global_position + Vector3(0, 1.0, 0)
	var shoot_direction := (target_pos - shoot_origin).normalized()

	shoot_direction = CombatUtils.apply_enemy_spread(shoot_direction, enemy_spread, shoot_origin.distance_to(target_pos))

	projectile_instance.direction = shoot_direction
	projectile_instance.speed = 20.0
	projectile_instance.damage = attack_damage
	projectile_instance.max_distance = 35.0
	projectile_instance.color = Color(0.8, 0.1, 1.0)
	projectile_instance.shooter = self

	# issue 15：连接弹体碰撞信号以检测玩家命中
	projectile_instance.body_entered.connect(_on_projectile_body_entered.bind(projectile_instance))

	get_tree().root.add_child(projectile_instance)
	projectile_instance.global_position = shoot_origin

	# 枪模型后坐
	if gun_instance:
		var recoil := create_tween()
		recoil.tween_property(gun_instance, "position:z", gun_instance.position.z + 0.07, 0.05)
		recoil.tween_property(gun_instance, "position:z", gun_instance.position.z, 0.1)

	_play_muzzle_flash()

## issue 15：弹体碰撞回调 —— 命中玩家时 emit projectile_hit_player 信号
func _on_projectile_body_entered(body: Node3D, projectile: Node3D) -> void:
	if not is_instance_valid(projectile):
		return
	# 断开信号避免重复触发
	if projectile.body_entered.is_connected(_on_projectile_body_entered):
		projectile.body_entered.disconnect(_on_projectile_body_entered)
	if body is CharacterBody3D and body.is_in_group("player"):
		projectile_hit_player.emit(body)


## 枪口闪光
func _play_muzzle_flash() -> void:
	if not gun_instance:
		return
	var flash := gun_instance.get_node_or_null("MuzzleFlash") as AnimatedSprite3D
	if not flash:
		return
	flash.visible = true
	flash.frame = 0
	flash.play("default")
	get_tree().create_timer(0.12).timeout.connect(func():
		if is_instance_valid(flash):
			flash.visible = false
	)
