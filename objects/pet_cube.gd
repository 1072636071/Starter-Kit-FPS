extends CharacterBody3D
## CubePet：召唤物，简单 AI 追玩家咬，不参与 RunDirector 奖励体系。
## 碰撞层 layer 2（同怪物），mask 只含 layer 1（地形）+ layer 3（玩家攻击）。

@export var health: float = 20.0
@export var move_speed: float = 4.0
@export var damage: float = 5.0
@export var attack_cooldown: float = 1.0

var _target: Node3D
var _dead := false
var _can_attack := true
var _attack_timer: float = 0.0

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D


func _ready():
	# 碰撞层级：layer 2（同怪物），mask layer 1（地形）+ layer 3（玩家攻击）
	collision_layer = 2
	collision_mask = 1 | 4  # layer 1 + layer 3

	if nav_agent:
		nav_agent.avoidance_enabled = true
		nav_agent.radius = 0.3
		nav_agent.max_speed = move_speed
		nav_agent.velocity_computed.connect(_on_velocity_computed)


func set_target(target: Node3D) -> void:
	_target = target


func _physics_process(delta: float) -> void:
	if _dead:
		return

	if not _target or not is_instance_valid(_target):
		return

	# 攻击冷却
	if not _can_attack:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_can_attack = true

	var to_target := _target.global_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()

	# 2m 内攻击
	if distance <= 2.0 and _can_attack:
		_can_attack = false
		_attack_timer = attack_cooldown
		if _target.has_method("damage"):
			_target.damage(damage)
		return

	# 导航追踪
	if nav_agent:
		nav_agent.target_position = _target.global_position
		var dir := _get_nav_direction()
		var desired_vel := Vector3(dir.x * move_speed, 0.0, dir.z * move_speed)
		nav_agent.velocity = desired_vel


func _get_nav_direction() -> Vector3:
	if not nav_agent or nav_agent.is_navigation_finished():
		return Vector3.ZERO
	var to_next := nav_agent.get_next_path_position() - global_position
	to_next.y = 0.0
	if to_next.length() > 0.1:
		return to_next.normalized()
	return Vector3.ZERO


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	velocity = safe_velocity
	move_and_slide()


func damage(amount: float) -> void:
	if _dead:
		return
	health -= amount
	if health <= 0.0:
		_dead = true
		# 不发 died 信号（不参与 RunDirector 奖励体系）
		queue_free()
