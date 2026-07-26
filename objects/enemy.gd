extends Area3D
## 飞行敌人：追踪玩家 + 悬停高度 + 环绕 strafing（ADR 017）
## 不使用 NavMesh（飞行无视地形），纯向量计算

const CombatUtils = preload("res://scripts/combat_utils.gd")
const MONSTER_TYPE: StringName = &"enemy"

@export var player: Node3D
@export var enemy_spread: float = 0.08
@export var fly_speed: float = 4.0
## 缓行速度（未进入追逐时缓慢靠近玩家）。=0 时自动设为 fly_speed * 0.35
@export var drift_speed: float = 0.0
@export var hover_height: float = 4.0
@export var preferred_distance: float = 8.0
@export var chase_range: float = 70.0

@onready var muzzle_a = $MuzzleA
@onready var muzzle_b = $MuzzleB

var health := 100
var _dead := false

# 天空缓降
const DROP_HEIGHT := 8.0
const DROP_SPEED := 3.5
var _dropping := true
var _hover_position: Vector3

# 环绕 strafing
var _orbit_dir: float = 1.0  # 1=顺时针, -1=逆时针
var _orbit_angle: float = 0.0

# 视线检测
var _los_timer: float = 0.0
const LOS_INTERVAL := 0.25
var _has_los: bool = true

# issue 03：死亡信号
signal died(monster_type: StringName)

func _ready():
	_hover_position = position
	position.y += DROP_HEIGHT
	_dropping = true
	_orbit_dir = [-1.0, 1.0].pick_random()
	_orbit_angle = randf() * TAU
	# 碰撞层：layer 2（怪物层），mask 0（Area3D 不需要物理碰撞）
	collision_layer = 2
	collision_mask = 0
	# 自动查找玩家
	if not player:
		player = get_tree().get_first_node_in_group("player")
	# 双速模型：drift_speed = 0 时自动计算
	if drift_speed <= 0.0:
		drift_speed = fly_speed * 0.35

func _process(delta):
	# 坠落安全网
	if not _dead and position.y < -10.0:
		destroy()
		return
	if _dead:
		return

	# 缓降阶段
	if _dropping:
		position.y = move_toward(position.y, _hover_position.y + hover_height, DROP_SPEED * delta)
		if abs(position.y - (_hover_position.y + hover_height)) < 0.1:
			_dropping = false
		return

	if not player:
		return

	# 视线检测（节流）
	_los_timer -= delta
	if _los_timer <= 0.0:
		_los_timer = LOS_INTERVAL
		_update_los()

	# AI 行为
	var to_player := player.global_position - global_position
	var horizontal_dist := Vector2(to_player.x, to_player.z).length()

	# 目标高度：悬停高度（相对地面 0）
	var target_y := hover_height

	# 水平移动
	var target_pos := global_position
	if horizontal_dist < chase_range:
		if horizontal_dist > preferred_distance + 1.0:
			# 太远：靠近
			var dir := Vector3(to_player.x, 0, to_player.z).normalized()
			target_pos = global_position + dir * fly_speed * delta
		elif horizontal_dist < preferred_distance - 2.0:
			# 太近：后退
			var dir := Vector3(to_player.x, 0, to_player.z).normalized()
			target_pos = global_position - dir * fly_speed * delta * 0.7
		else:
			# 理想距离：环绕 strafing
			_orbit_angle += _orbit_dir * delta * 0.8
			var orbit_offset := Vector3(cos(_orbit_angle), 0, sin(_orbit_angle)) * preferred_distance
			var desired := player.global_position + orbit_offset
			target_pos = global_position.lerp(desired, delta * 1.5)

	# 被墙挡时升高（简单检测）
	if _is_wall_ahead():
		target_y = hover_height + 2.0

	# IDLE：玩家超出 chase_range，缓行靠近
	if horizontal_dist >= chase_range:
		var dir := Vector3(to_player.x, 0, to_player.z).normalized()
		target_pos = global_position + dir * drift_speed * delta

	# 平滑移动
	target_pos.y = target_y
	position = position.lerp(target_pos, delta * 3.0)

	# 面向玩家
	if horizontal_dist > 0.5:
		var look_target := player.global_position + Vector3(0, 0.5, 0)
		look_at(look_target, Vector3.UP, true)

## 视线检测
func _update_los() -> void:
	if not player:
		_has_los = false
		return
	var from := global_position
	var to := player.global_position + Vector3(0, 0.5, 0)
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	query.collision_mask = 1  # 只检测地形
	var result := space_state.intersect_ray(query)
	_has_los = (result.is_empty())

## 前向墙壁检测
func _is_wall_ahead() -> bool:
	var space_state := get_world_3d().direct_space_state
	var from := global_position
	var to := global_position + Vector3(0, 0, -3.0)  # 前方 3m
	# 使用全局朝向
	var forward := -global_transform.basis.z
	to = global_position + forward * 3.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	query.collision_mask = 1
	var result := space_state.intersect_ray(query)
	return not result.is_empty()

# === 受击/死亡 ===
func damage(amount):
	if _dead:
		return
	Audio.play("sounds/enemy_hurt.ogg")
	HitFeedback.flash(self)
	health -= amount
	if health <= 0 and not _dead:
		destroy()

func destroy():
	if _dead:
		return
	Audio.play("sounds/enemy_destroy.ogg")
	_dead = true
	died.emit(MONSTER_TYPE)
	queue_free()

# === 射击 ===
func _on_timer_timeout():
	if _dead or _dropping or not player:
		return
	if not _has_los:
		return

	muzzle_a.frame = 0
	muzzle_a.play("default")
	muzzle_a.rotation_degrees.z = randf_range(-45, 45)

	muzzle_b.frame = 0
	muzzle_b.play("default")
	muzzle_b.rotation_degrees.z = randf_range(-45, 45)

	Audio.play("sounds/enemy_attack.ogg")

	var projectile = preload("res://objects/projectile.tscn")
	var projectile_instance = projectile.instantiate()

	var shoot_direction = (player.global_position + Vector3(0, 0.5, 0) - global_position).normalized()
	shoot_direction = CombatUtils.apply_enemy_spread(shoot_direction, enemy_spread, global_position.distance_to(player.global_position))

	projectile_instance.direction = shoot_direction
	projectile_instance.speed = 30.0
	projectile_instance.damage = 5.0
	projectile_instance.max_distance = 30.0
	projectile_instance.color = Color(1, 0.2, 0.2)
	projectile_instance.shooter = self

	get_tree().root.add_child(projectile_instance)
	projectile_instance.global_position = global_position
