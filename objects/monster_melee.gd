extends "res://objects/monster_base.gd"
## 近战怪物：追踪玩家并发动骨骼攻击动画
## T2: 持剑/空手 + attack-melee-right 骨骼剪辑 + 活跃帧伤害结算
## T4/T5 骨骼移动/待机/死亡动画已在基类实现

@export var move_speed: float = 3.5
@export var chase_range: float = 25.0
@export var attack_range: float = 2.0
@export var attack_damage: float = 15.0
@export var attack_cooldown: float = 1.2
@export var health: float = 120.0
## 近战武器模型（默认 Mistsplitter.glb，与玩家 Sword6.glb 不同）；留空则空手
@export var melee_weapon_model: PackedScene = preload("res://models/melee_weapons/Mistsplitter.glb")
## attack-melee-right 活跃帧时刻（约 0.2s，按剪辑实际时长微调）
@export var active_frame_time: float = 0.2

var weapon_instance: Node3D

func _ready():
	super._ready()

	# T2: 挂近战武器模型（melee_weapon_model = null 即空手变体）
	if melee_weapon_model and arm_right:
		weapon_instance = melee_weapon_model.instantiate()
		arm_right.add_child(weapon_instance)
		# 本地偏移：手臂远端→手掌位置；剑朝下竖直握持
		weapon_instance.position = Vector3(0.0, -0.3, 0.0)
		weapon_instance.rotation_degrees = Vector3(0, 0, 0)
		weapon_instance.scale = Vector3(0.4, 0.4, 0.4)
		# 武器模型 layers = 4（layer 3：进主相机，不进小地图）
		for child in weapon_instance.find_children("*", "MeshInstance3D", true, false):
			child.layers = 4

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
	elif distance <= attack_range and _can_attack and not _is_attacking:
		velocity.x = 0.0
		velocity.z = 0.0
		_face_direction(to_player)
		_start_attack()
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 5)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 5)
		_face_direction(to_player)

	velocity.y = -gravity
	move_and_slide()

	# T4: 骨骼动画选择器（近战静止播 idle）
	_select_animation("idle")

## T2: 发动攻击——播 attack-melee-right 骨骼剪辑，活跃帧结算伤害
func _start_attack():
	_is_attacking = true
	_can_attack = false
	attack_timer.start()

	Audio.play("sounds/enemy_attack.ogg")

	# T2: 播骨骼攻击剪辑（持剑=挥剑，空手=拳击），取代整体 lunge Tween
	if anim_player and anim_player.has_animation("attack-melee-right"):
		anim_player.play("attack-melee-right")
		# 用实际剪辑时长驱动 _is_attacking 恢复，不硬编码
		var clip_length := anim_player.get_animation("attack-melee-right").length
		get_tree().create_timer(clip_length).timeout.connect(_on_attack_finished)
	else:
		get_tree().create_timer(0.45).timeout.connect(_on_attack_finished)

	# T2: 伤害结算对齐活跃帧（约剪辑 0.2s 处），距离判定逻辑不变
	get_tree().create_timer(active_frame_time).timeout.connect(_deal_damage)

## T2: 伤害结算（距离判定，沿用 attack_range）
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
