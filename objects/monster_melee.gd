extends "res://objects/monster_base.gd"
## 近战怪物：追踪玩家并发动骨骼攻击动画
## FSM 状态行为覆盖 + 战术散开（ADR 017）

# 预加载 MeleeVFX class_name，确保 headless 模式下全局类注册
const _MeleeVFX = preload("res://scripts/melee_vfx.gd")

const MONSTER_TYPE: StringName = &"monster_melee"

@export var attack_range: float = 2.0
## 近战武器模型（默认 Sword6.glb）；留空则空手
@export var melee_weapon_model: PackedScene = preload("res://models/melee_weapons/Sword6.glb")
## attack-melee-right 活跃帧时刻
@export var active_frame_time: float = 0.2

var weapon_instance: Node3D
# 近战剑弧粒子特效（ADR 020）
var melee_slash: GPUParticles3D

# 战术散开：环绕偏移角
var _approach_angle: float = 0.0
const SPREAD_RADIUS := 1.5

func _monster_type() -> StringName:
	return MONSTER_TYPE

func _get_attack_range() -> float:
	return attack_range

func _get_idle_anim() -> String:
	return "idle"

func _ready():
	# 覆盖基类默认值（近战特化）
	move_speed = 3.5
	chase_range = 25.0
	attack_damage = 15.0
	attack_cooldown = 1.2
	health = 120.0
	# 近战怪被动感知 8m（基类默认，显式设置以明确意图）
	awareness_range = 8.0
	super._ready()

	# 战术散开角度
	_approach_angle = spawn_index * (TAU / max(1, spawn_index + 4))

	# 挂近战武器模型
	if melee_weapon_model and arm_right:
		weapon_instance = melee_weapon_model.instantiate()
		arm_right.add_child(weapon_instance)
		weapon_instance.position = Vector3(0.0, -0.3, 0.0)
		weapon_instance.rotation_degrees = Vector3(0, 0, 0)
		weapon_instance.scale = Vector3(1.0, 1.0, 1.0)
		for child in weapon_instance.find_children("*", "MeshInstance3D", true, false):
			child.layers = 4

	# 近战剑弧粒子特效：挂在自身节点下，layer 3 主相机可见（ADR 020）
	# 位置：敌人前方 1.5m、腰部高度（attack_range + 0.8 ≈ 2.8m 命中判定的中心区域）
	melee_slash = MeleeVFX.create_slash(
		self,
		MeleeVFX.COLOR_ENEMY,
		4, # layer 3: main camera visible
		MeleeVFX.ENEMY_BOX_EXTENTS,
		Vector3(0, 0.5, -1.5)
	)

## 战术散开：追踪目标 = 玩家位置 + 环绕偏移
func _get_chase_target() -> Vector3:
	if not player:
		return global_position
	var offset := Vector3(cos(_approach_angle), 0, sin(_approach_angle)) * SPREAD_RADIUS
	return player.global_position + offset

## CHASE 状态：朝战术偏移点移动
func _tick_chase(delta: float) -> void:
	if not player:
		return
	if _path_timer <= 0.0:
		_path_timer = path_update_interval
		nav_agent.target_position = _get_chase_target()
	var dir := _get_nav_direction()
	_desired_velocity = Vector3(dir.x * move_speed, -gravity, dir.z * move_speed)
	if dir.length_squared() > 0.01:
		_face_direction(dir)

## ATTACK 状态：发动攻击
func _tick_attack(_delta: float) -> void:
	_desired_velocity = Vector3(0, -gravity, 0)
	if not _is_attacking and _can_attack:
		_start_attack()

func _start_attack():
	_is_attacking = true
	_can_attack = false
	attack_timer.start()

	Audio.play("sounds/enemy_attack.ogg")

	if anim_player and anim_player.has_animation("attack-melee-right"):
		anim_player.play("attack-melee-right")
		var clip_length := anim_player.get_animation("attack-melee-right").length
		get_tree().create_timer(clip_length).timeout.connect(_on_attack_finished)
	else:
		get_tree().create_timer(0.45).timeout.connect(_on_attack_finished)

	get_tree().create_timer(active_frame_time).timeout.connect(_deal_damage)

	# 活跃帧同步触发剑弧粒子（ADR 020）
	get_tree().create_timer(active_frame_time).timeout.connect(func():
		if melee_slash and is_instance_valid(melee_slash):
			MeleeVFX.trigger(melee_slash)
	)

func _deal_damage():
	if _dead or not player:
		return
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() <= attack_range + 0.8:
		if player.has_method("damage"):
			player.damage(attack_damage)

func _on_attack_finished():
	_is_attacking = false
	# 攻击完成后回到 CHASE 或 IDLE
	if player:
		var to_player := player.global_position - global_position
		to_player.y = 0.0
		if to_player.length() < chase_range and _has_los:
			_change_state(AIState.CHASE)
		else:
			_change_state(AIState.IDLE)
	else:
		_change_state(AIState.IDLE)
