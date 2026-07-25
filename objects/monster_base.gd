extends CharacterBody3D
## 人形怪物基类：FSM 状态机 + RVO 避障 + 视线检测 + 路径节流
## 子类：monster_ranged.gd（远程持枪）、monster_melee.gd（近战持剑/空手）
## 参见 ADR 017 与 CONTEXT.md「敌人 AI 系统」

# === AI 状态机 ===
enum AIState { IDLE, CHASE, ATTACK, RETREAT, LOST }

@export var player: Node3D
@export var move_speed: float = 3.0
@export var chase_range: float = 25.0
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.5
@export var health: float = 100.0

var gravity: float = 0.0
var _dead := false
var _can_attack := true
var _is_attacking := false

# FSM 状态
var _ai_state: AIState = AIState.IDLE

# 天空缓降
const DROP_HEIGHT := 8.0
const DROP_SPEED := 3.5
var _dropping := true

# 视线检测
var _los_timer: float = 0.0
const LOS_INTERVAL := 0.2
var _has_los: bool = false
var _last_known_player_pos: Vector3 = Vector3.ZERO

# LOST 状态
var _look_timer: float = 0.0
const LOOK_DURATION := 2.0
var _look_yaw_dir: float = 1.0

# 路径节流
var _path_timer: float = 0.0
var path_update_interval: float = 0.3
var _path_timer_offset: float = 0.0

# 出生序号（由 RunDirector 刷怪时设置，用于错帧和战术散开）
var spawn_index: int = 0

# RVO 期望速度（_physics_process 中计算，回调中使用）
var _desired_velocity: Vector3 = Vector3.ZERO

# issue 03：怪物死亡信号
signal died(monster_type: StringName)

# 骨骼动画引用
var character_model: Node3D
var anim_player: AnimationPlayer
var arm_right: Node3D
var _current_anim: String = ""

@onready var model: Node3D = $Model
@onready var attack_timer: Timer = $AttackTimer
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

func _ready():
	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_cooldown)

	# 天空缓降
	position.y += DROP_HEIGHT
	_dropping = true

	_setup_animation_refs()
	_setup_locomotion_loops()
	_set_model_mesh_layers()
	_auto_find_player()
	_setup_rvo()
	_setup_collision_layers()

	# 错帧偏移
	_path_timer_offset = (spawn_index % 6) * 0.05
	_path_timer = _path_timer_offset

## 配置 RVO 避障（缓降期间禁用，落地后启用）
func _setup_rvo() -> void:
	if not nav_agent:
		return
	nav_agent.avoidance_enabled = false  # 缓降期间不参与避障
	nav_agent.radius = 0.5
	nav_agent.neighbor_distance = 5.0
	nav_agent.max_neighbors = 8
	nav_agent.max_speed = move_speed
	nav_agent.avoidance_layers = 1
	nav_agent.avoidance_mask = 1
	nav_agent.velocity_computed.connect(_on_velocity_computed)

## 碰撞层隔离：怪物 layer=2, mask=1（只撞地形，不撞其他怪物）
func _setup_collision_layers() -> void:
	collision_layer = 2
	collision_mask = 1

## 定位骨骼节点
func _setup_animation_refs() -> void:
	character_model = $Model/CharacterModel
	anim_player = character_model.find_child("AnimationPlayer", true, false)
	arm_right = character_model.find_child("arm-right", true, false)

## 将移动/待机剪辑设为循环
func _setup_locomotion_loops() -> void:
	if anim_player:
		for n in ["walk", "run", "sprint", "idle"]:
			if anim_player.has_animation(n):
				anim_player.get_animation(n).loop = true

## 怪物 mesh layers = 4（layer 3，不进小地图）
func _set_model_mesh_layers() -> void:
	for child in model.find_children("*", "MeshInstance3D", true, false):
		child.layers = 4

func _auto_find_player() -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player")
	if not player:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]

# === 主物理循环 ===
func _physics_process(delta: float) -> void:
	if _dead:
		return
	# 坠落安全网
	if position.y < -10.0:
		destroy()
		return
	# 缓降阶段
	if _dropping:
		gravity = DROP_SPEED
		velocity.y = -gravity
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		if is_on_floor():
			_dropping = false
			gravity = 0.0
			# 落地后启用 RVO
			if nav_agent:
				nav_agent.avoidance_enabled = true
		return

	# 重力
	gravity += 20.0 * delta
	if gravity > 0 and is_on_floor():
		gravity = 0.0

	# 视线检测（节流）
	_los_timer -= delta
	if _los_timer <= 0.0:
		_los_timer = LOS_INTERVAL
		_update_los()

	# 状态转换评估
	_evaluate_transitions()

	# 当前状态 tick
	_tick_state(delta)

	# 路径更新节流
	_path_timer -= delta

	# 设定期望速度给 RVO（回调中执行 move_and_slide）
	nav_agent.velocity = _desired_velocity

	# 骨骼动画选择
	_select_animation(_get_idle_anim())

# === 视线检测 ===
func _update_los() -> void:
	if not player:
		_has_los = false
		return
	var from := global_position + Vector3(0, 1.2, 0)
	var to := player.global_position + Vector3(0, 0.8, 0)
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	query.collision_mask = 1  # 只检测地形（layer 1），不被其他怪物挡视线
	var result := space_state.intersect_ray(query)
	if result:
		var collider = result["collider"]
		# 命中玩家 = 视线通畅
		_has_los = (collider == player or collider.is_ancestor_of(player) or player.is_ancestor_of(collider))
	else:
		# 无命中 = 视线通畅（无遮挡）
		_has_los = true
	if _has_los:
		_last_known_player_pos = player.global_position

# === 状态转换 ===
func _evaluate_transitions() -> void:
	if not player:
		return
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()

	match _ai_state:
		AIState.IDLE:
			# IDLE → CHASE：只用距离触发，不要求视线（竞技场设计：怪物感知到玩家就追）
			if distance < chase_range:
				_change_state(AIState.CHASE)
		AIState.CHASE:
			if not _has_los:
				_change_state(AIState.LOST)
			elif distance <= _get_attack_range() and _can_attack:
				_change_state(AIState.ATTACK)
		AIState.ATTACK:
			pass  # 攻击完成后由 _on_attack_finished 切回 CHASE/IDLE
		AIState.RETREAT:
			if not _has_los:
				_change_state(AIState.LOST)
			elif distance > _get_attack_range():
				_change_state(AIState.CHASE)
		AIState.LOST:
			if _has_los:
				var dist := (player.global_position - global_position)
				dist.y = 0.0
				if dist.length() < chase_range:
					_change_state(AIState.CHASE)

## 子类覆盖：返回攻击范围（基类默认 2.0）
func _get_attack_range() -> float:
	return 2.0

## 子类覆盖：返回 idle 动画名
func _get_idle_anim() -> String:
	return "idle"

# === 状态机框架 ===
func _change_state(new_state: AIState) -> void:
	if _ai_state == new_state:
		return
	_ai_state = new_state
	match new_state:
		AIState.LOST:
			_look_timer = LOOK_DURATION
			_look_yaw_dir = [-1.0, 1.0].pick_random()
			path_update_interval = 0.6
		AIState.CHASE:
			path_update_interval = 0.3
		AIState.IDLE:
			_desired_velocity = Vector3.ZERO
		_:
			pass

func _tick_state(delta: float) -> void:
	match _ai_state:
		AIState.IDLE:
			_tick_idle(delta)
		AIState.CHASE:
			_tick_chase(delta)
		AIState.ATTACK:
			_tick_attack(delta)
		AIState.RETREAT:
			_tick_retreat(delta)
		AIState.LOST:
			_tick_lost(delta)

# === 子类覆盖的状态行为 ===
func _tick_idle(_delta: float) -> void:
	_desired_velocity = Vector3.ZERO

func _tick_chase(delta: float) -> void:
	if not player:
		return
	# 路径更新（节流）
	if _path_timer <= 0.0:
		_path_timer = path_update_interval
		nav_agent.target_position = _get_chase_target()
	# 朝下一路径点移动
	var dir := _get_nav_direction()
	_desired_velocity = Vector3(dir.x * move_speed, -gravity, dir.z * move_speed)
	if dir.length_squared() > 0.01:
		_face_direction(dir)

func _tick_attack(_delta: float) -> void:
	_desired_velocity = Vector3(0, -gravity, 0)

func _tick_retreat(delta: float) -> void:
	# 远程怪覆盖
	_desired_velocity = Vector3(0, -gravity, 0)

func _tick_lost(delta: float) -> void:
	# 移动到最后已知位置
	if _path_timer <= 0.0:
		_path_timer = path_update_interval
		nav_agent.target_position = _last_known_player_pos
	var dir := _get_nav_direction()
	if dir.length_squared() > 0.01:
		_desired_velocity = Vector3(dir.x * move_speed, -gravity, dir.z * move_speed)
		_face_direction(dir)
	else:
		_desired_velocity = Vector3(0, -gravity, 0)
		# 到达后环顾
		_look_timer -= delta
		if _look_timer <= 0.0:
			_change_state(AIState.IDLE)
		else:
			# 缓慢转向扫描
			rotate_y(_look_yaw_dir * 1.5 * delta)

## 子类覆盖：返回追踪目标点（基类=玩家位置，近战怪加偏移）
func _get_chase_target() -> Vector3:
	return player.global_position

## 获取 NavMesh 方向（朝下一路径点）
func _get_nav_direction() -> Vector3:
	if nav_agent.is_navigation_finished():
		return Vector3.ZERO
	var to_next := nav_agent.get_next_path_position() - global_position
	to_next.y = 0.0
	if to_next.length() > 0.1:
		return to_next.normalized()
	return Vector3.ZERO

# === RVO 回调 ===
func _on_velocity_computed(safe_velocity: Vector3) -> void:
	velocity = safe_velocity
	velocity.y = -gravity
	move_and_slide()

# === 动画 ===
func _select_animation(idle_anim: String) -> void:
	if not anim_player:
		return
	if _is_attacking or _dead:
		return
	var h_speed := Vector2(velocity.x, velocity.z).length()
	var target: String
	if h_speed > move_speed * 0.8:
		target = "run"
	elif h_speed > 0.2:
		target = "walk"
	else:
		target = idle_anim
	if target != _current_anim:
		anim_player.play(target)
		_current_anim = target

## 朝指定水平方向 look
func _face_direction(direction: Vector3) -> void:
	if direction.length_squared() <= 0.01:
		return
	var look_target := global_position + direction.normalized()
	look_target.y = global_position.y
	look_at(look_target, Vector3.UP, true)

# === 攻击冷却 ===
func _on_attack_cooldown():
	_can_attack = true

# === 受击/死亡 ===
func damage(amount: float):
	if _dead:
		return
	Audio.play("sounds/enemy_hurt.ogg")
	HitFeedback.flash(self)
	health -= amount
	if model:
		var tween := create_tween()
		model.scale = Vector3(1.1, 0.9, 1.1)
		tween.tween_property(model, "scale", Vector3.ONE, 0.15)
	if health <= 0 and not _dead:
		destroy()

func _monster_type() -> StringName:
	return &""

func destroy():
	Audio.play("sounds/enemy_destroy.ogg")
	_dead = true
	# 关闭 RVO（避免死亡后仍参与避障）
	if nav_agent:
		nav_agent.avoidance_enabled = false
	died.emit(_monster_type())
	if anim_player and anim_player.has_animation("die"):
		anim_player.play("die")
		var die_length := anim_player.get_animation("die").length
		get_tree().create_timer(die_length).timeout.connect(queue_free)
	else:
		queue_free()
