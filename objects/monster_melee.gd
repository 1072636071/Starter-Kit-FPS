extends CharacterBody3D
## 近战怪物：追踪玩家并发动冲锋攻击

@export var player: Node3D
@export var move_speed: float = 3.5
@export var chase_range: float = 25.0
@export var attack_range: float = 2.0
@export var attack_damage: float = 15.0
@export var attack_cooldown: float = 1.2
@export var health: float = 120.0

var gravity: float = 0.0
var destroyed := false
var _can_attack := true
var _is_attacking := false
var _base_position: Vector3

@onready var model: Node3D = $Model
@onready var attack_timer: Timer = $AttackTimer
@onready var hit_area: Area3D = $HitArea
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

func _ready():
	_base_position = position
	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_cooldown)
	
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

	# 追踪/攻击/待机
	if distance > attack_range and distance < chase_range and not _is_attacking:
		# 通过 NavMesh 寻路：朝下一路径点而非玩家直线方向，可绕过墙体、跨过 ≤ step_height 的台阶
		nav_agent.target_position = player.global_position
		if not nav_agent.is_navigation_finished():
			var to_next := nav_agent.get_next_path_position() - global_position
			to_next.y = 0.0
			var direction := to_next.normalized() if to_next.length() > 0.1 else Vector3.ZERO
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
			_face_direction(direction)
		else:
			# 路径走完但仍未进入攻击范围（玩家移动了），停在原地面向玩家
			velocity.x = 0.0
			velocity.z = 0.0
			_face_direction(to_player)
		_animate_walk(delta)
	elif distance <= attack_range and _can_attack and not _is_attacking:
		velocity.x = 0.0
		velocity.z = 0.0
		_face_direction(to_player)
		_start_attack()
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 5)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 5)
		_face_direction(to_player)
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
	_walk_time += delta * 8.0
	if model:
		model.rotation.x = sin(_walk_time) * 0.08
		model.position.y = abs(sin(_walk_time)) * 0.05

## 待机呼吸
var _idle_time: float = 0.0
func _animate_idle(delta: float):
	_idle_time += delta * 2.0
	if model:
		model.rotation.x = lerp(model.rotation.x, 0.0, delta * 5.0)
		model.position.y = sin(_idle_time) * 0.02

## 发动攻击：前冲 + 身体倾斜
func _start_attack():
	_is_attacking = true
	_can_attack = false
	attack_timer.start()
	
	Audio.play("sounds/enemy_attack.ogg")
	
	var tween := create_tween()
	# 蓄力后仰
	tween.tween_property(model, "rotation:x", deg_to_rad(-20), 0.15)
	# 前冲
	tween.tween_property(model, "rotation:x", deg_to_rad(30), 0.1)
	tween.parallel().tween_property(self, "position", position + (global_transform.basis * Vector3(0, 0, -0.8)), 0.1)
	# 恢复
	tween.tween_property(model, "rotation:x", 0.0, 0.2)
	tween.tween_callback(_on_attack_finished)
	
	# 攻击判定延迟
	get_tree().create_timer(0.2).timeout.connect(_deal_damage)

func _deal_damage():
	if destroyed or not player:
		return
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() <= attack_range + 0.8:
		if player.has_method("damage"):
			player.damage(attack_damage)

func _on_attack_finished():
	_is_attacking = false

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
