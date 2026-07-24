extends CharacterBody3D
## 人形怪物基类：共享骨骼动画/死亡/受击/寻路逻辑
## 子类：monster_ranged.gd（远程持枪）、monster_melee.gd（近战持剑/空手）
## 消除两怪之间 _select_animation / destroy / damage / _ready 骨骼初始化的重复代码

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

# issue 03：怪物死亡信号（携带类型标识），由 RunDirector（issue 02）监听做清场检测与奖励结算。
# 在 destroy() 内、queue_free() 前发射，含延迟 queue_free() 分支（die 动画期间仍发射）。
signal died(monster_type: StringName)

# 骨骼动画引用（T1/T2/T4/T5 共用）
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

	_setup_animation_refs()
	_setup_locomotion_loops()
	_set_model_mesh_layers()
	_auto_find_player()

## 定位骨骼节点（arm-right 挂武器；AnimationPlayer 播剪辑）
func _setup_animation_refs() -> void:
	character_model = $Model/CharacterModel
	anim_player = character_model.find_child("AnimationPlayer", true, false)
	arm_right = character_model.find_child("arm-right", true, false)

## T4: 将移动/待机剪辑设为循环（GLB 默认不循环）
func _setup_locomotion_loops() -> void:
	if anim_player:
		for n in ["walk", "run", "sprint", "idle"]:
			if anim_player.has_animation(n):
				anim_player.get_animation(n).loop = true

## T1（minimap）：怪物真实 mesh layers = 4（layer 3，不进小地图）
## 参见 ADR 007 与 CONTEXT.md「Minimap Enemy Layer」
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

## T4: 按状态选择移动/待机骨骼剪辑。
## idle_anim 区分近战(idle)/远程(holding-right)。
## 怪物速度被钳制在 move_speed（chase/back）或 move_speed*0.5（strafe），
## 故只有 walk（慢）/ run（快）两档可达；sprint 剪辑保留但不在此选取（无 sprint 速度源）。
func _select_animation(idle_anim: String) -> void:
	if not anim_player:
		return
	# 攻击 one-shot 期间让位，不干预
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

## 朝指定水平方向 look（不影响 y）
func _face_direction(direction: Vector3) -> void:
	if direction.length_squared() <= 0.01:
		return
	var look_target := global_position + direction.normalized()
	look_target.y = global_position.y
	look_at(look_target, Vector3.UP, true)

func _on_attack_cooldown():
	_can_attack = true

## 受到伤害（死亡后不再响应）。
## T5: _dead 守卫是"已 _dead 的实体跳过受击"的最小实现；
## "不改动 damage()"指不改受击反馈机制（HitFeedback.flash + scale 挤压），非排斥守卫。
func damage(amount: float):
	if _dead:
		return
	Audio.play("sounds/enemy_hurt.ogg")
	HitFeedback.flash(self)
	health -= amount
	# 受击挤压
	if model:
		var tween := create_tween()
		model.scale = Vector3(1.1, 0.9, 1.1)
		tween.tween_property(model, "scale", Vector3.ONE, 0.15)
	if health <= 0 and not _dead:
		destroy()

## issue 03：返回本怪物的硬编码类型标识（默认空，子类覆盖）。
## 用虚方法而非直接读 const：GDScript const 在基类方法中按词法作用域静态绑定到基类，
## 子类 shadow 的同名 const 不会被基类 destroy() 看到；虚方法走动态分派可正确取到子类值。
func _monster_type() -> StringName:
	return &""

## T5: 死亡——播 die 骨骼剪辑，播完 queue_free。
## _dead 标志使 _physics_process 提前返回，避免与 die 剪辑抢动画轨道。
## issue 03：在 _dead 置位后、queue_free() 前发射 died(monster_type)，
## 确保 die 动画期间的延迟 queue_free() 分支也能让 RunDirector 收到信号并正确减 alive_count。
func destroy():
	Audio.play("sounds/enemy_destroy.ogg")
	_dead = true
	died.emit(_monster_type())
	if anim_player and anim_player.has_animation("die"):
		anim_player.play("die")
		# 用实际剪辑时长驱动 queue_free，不硬编码
		var die_length := anim_player.get_animation("die").length
		get_tree().create_timer(die_length).timeout.connect(queue_free)
	else:
		queue_free()
