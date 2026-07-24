extends CharacterBody3D
## 远程怪物：与玩家保持距离，发射弹幕攻击

const CombatUtils = preload("res://scripts/combat_utils.gd")

@export var player: Node3D
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

var gravity: float = 0.0
var destroyed := false
var _can_attack := true
var _is_attacking := false

@onready var model: Node3D = $Model
@onready var attack_timer: Timer = $AttackTimer
@onready var shoot_point: Marker3D = $ShootPoint
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

func _ready():
	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_cooldown)

	# T1（minimap）：怪物真实 mesh 从默认 layer 1 挪到 layer 3（value = 4），
	# 使俯视相机（cull_mask = layer 1）不渲染其顶视 blob；主相机渲染 layers 3–20
	# 故真实 FPS 视野不受影响。与 player.gd 中武器模型 layers = 2 同模式。
	# 参见 ADR 007 与 CONTEXT.md「Minimap Enemy Layer」。
	for child in model.find_children("*", "MeshInstance3D", true, false):
		child.layers = 4

	# 如果未指定 player，自动查找
	if not player:
		player = get_tree().get_first_node_in_group("player")
	if not player:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]

func _physics_process(delta):
	if destroyed or not player:
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
		# 三种行为均沿 NavMesh 路径方向，避免台阶/墙边卡死（path_dir 不可用时回退到直线）
		var path_base := path_dir if path_dir != Vector3.ZERO else to_player.normalized()
		if distance < too_close_distance:
			# 太近了，后退（沿可行走路径反向远离玩家）
			velocity.x = -path_base.x * move_speed
			velocity.z = -path_base.z * move_speed
			_animate_walk(delta)
		elif distance > preferred_distance + 2.0:
			# 太远了，靠近（沿 NavMesh 路径，绕过墙体、跨过台阶）
			velocity.x = path_base.x * move_speed
			velocity.z = path_base.z * move_speed
			_animate_walk(delta)
		else:
			# 在理想距离，横向游走（沿可行走路径横向）
			var strafe := path_base.cross(Vector3.UP)
			velocity.x = strafe.x * move_speed * 0.5
			velocity.z = strafe.z * move_speed * 0.5
			_animate_idle(delta)
		
		# 攻击判定
		if distance < preferred_distance + 3.0 and _can_attack:
			_start_attack()
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 5)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 5)
		_animate_idle(delta)
	
	velocity.y = -gravity
	move_and_slide()

## 朝指定水平方向 look（不影响 y）
func _face_direction(direction: Vector3) -> void:
	if direction.length_squared() <= 0.01:
		return
	var look_target := global_position + direction.normalized()
	look_target.y = global_position.y
	look_at(look_target, Vector3.UP, true)

## 走路摆动
var _walk_time: float = 0.0
func _animate_walk(delta: float):
	_walk_time += delta * 7.0
	if model:
		model.rotation.x = sin(_walk_time) * 0.06
		model.position.y = abs(sin(_walk_time)) * 0.04

## 待机浮动
var _idle_time: float = 0.0
func _animate_idle(delta: float):
	_idle_time += delta * 3.0
	if model:
		model.rotation.x = lerp(model.rotation.x, 0.0, delta * 5.0)
		model.position.y = sin(_idle_time) * 0.03

## 发动攻击：抬手 + 连射弹幕
func _start_attack():
	_is_attacking = true
	_can_attack = false
	attack_timer.start()
	
	# 抬手蓄力动画
	var tween := create_tween()
	tween.tween_property(model, "rotation:x", deg_to_rad(-15), 0.2)
	tween.tween_property(model, "position:y", 0.1, 0.2)
	tween.tween_callback(_fire_burst)
	tween.tween_property(model, "rotation:x", 0.0, 0.3)
	tween.tween_property(model, "position:y", 0.0, 0.3)
	tween.tween_callback(func(): _is_attacking = false)

## 连射
func _fire_burst():
	for i in burst_count:
		_fire_projectile()
		if i < burst_count - 1:
			await get_tree().create_timer(burst_interval).timeout

## 发射单个弹幕
func _fire_projectile():
	if destroyed or not player:
		return
	
	Audio.play("sounds/enemy_attack.ogg")
	
	var projectile_scene = preload("res://objects/projectile.tscn")
	var projectile_instance = projectile_scene.instantiate()
	
	var target_pos := player.global_position + Vector3(0, 0.5, 0)
	var shoot_origin := shoot_point.global_position if shoot_point else global_position + Vector3(0, 1.0, 0)
	var shoot_direction := (target_pos - shoot_origin).normalized()
	
	# Add spread with distance scaling
	shoot_direction = CombatUtils.apply_enemy_spread(shoot_direction, enemy_spread, shoot_origin.distance_to(target_pos))
	
	projectile_instance.direction = shoot_direction
	projectile_instance.speed = 20.0
	projectile_instance.damage = attack_damage
	projectile_instance.max_distance = 35.0
	projectile_instance.color = Color(0.8, 0.1, 1.0) # 紫色弹幕
	projectile_instance.shooter = self
	
	get_tree().root.add_child(projectile_instance)
	projectile_instance.global_position = shoot_origin

func _on_attack_cooldown():
	_can_attack = true

## 受到伤害
func damage(amount: float):
	Audio.play("sounds/enemy_hurt.ogg")
	HitFeedback.flash(self)
	health -= amount

	# 受击闪烁
	if model:
		var tween := create_tween()
		model.scale = Vector3(1.1, 0.9, 1.1)
		tween.tween_property(model, "scale", Vector3.ONE, 0.15)

	if health <= 0 and not destroyed:
		destroy()

## 死亡
func destroy():
	Audio.play("sounds/enemy_destroy.ogg")
	destroyed = true
	
	# 死亡动画：缩小消失
	var tween := create_tween()
	tween.tween_property(model, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	tween.tween_property(model, "position:y", -0.5, 0.3)
	tween.tween_callback(queue_free)
