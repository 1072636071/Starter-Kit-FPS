extends CharacterBody3D

# === 卡住状态机（ADR 016，issue 05）===
enum StuckState { NORMAL, STUCK, ESCAPING }

@export_subgroup("Properties")
@export var movement_speed = 5
@export_range(0, 100) var number_of_jumps: int = 2
@export var jump_strength = 8

@export_subgroup("Weapons")
@export var weapons: Array[Weapon] = []

@export_subgroup("Health & Shield")
## 最大血量（issue 03 / 05 共用，升级 +20 最大血量受此上限约束）
@export var max_health: int = 100
## 护盾最大值（ADR 010）
@export var shield_max: float = 50.0
## 最后一次受击后开始回盾的延时（秒）
@export var shield_regen_delay: float = 3.0
## 护盾恢复速率（每秒，战斗中亦可恢复）
@export var shield_regen_rate: float = 10.0

@export_subgroup("Melee")
@export var melee_damage: float = 40.0
@export var melee_cooldown: float = 0.5
@export var melee_reach: float = 2.0
@export var melee_viewmodel: PackedScene

var weapon: Weapon
var weapon_index := 0

# 弹药状态：每把枪独立的弹匣 / 备弹（与 weapons 数组同序）
# 参见 ADR 004 与 CONTEXT.md「弹药系统」。
var magazine: Array[int] = []
var reserve: Array[int] = []

# 换弹状态
var is_reloading := false
var reload_index := -1 # 当前正在换弹的武器索引（通常等于 weapon_index）
var reload_time_remaining := 0.0
var reload_tween: Tween # T5：换弹期间武器模型的 Tween

# 近战状态（参见 ADR 006 与 CONTEXT.md「近战系统」）
# viewmodel 实例化一次、挂 CameraItem 下复用；冷却用浮点累加器；命中区由 T4 接入
var melee_viewmodel_instance: Node3D
var melee_cooldown_remaining := 0.0
var melee_swing_tween: Tween
const SWING_DURATION := 0.6 # 总挥砍时长，必须 ≤ melee_cooldown（见 ADR 018）
const ACTIVE_START := 0.2   # monitoring 开启时机（前摇结束）
const ACTIVE_END := 0.4     # monitoring 关闭时机（后摇开始）
# 下劈动画相对锚点的偏移：前摇举到右上，活跃帧 = -2× 偏移划到左下形成下劈弧线
const WINDUP_ROT := Vector3(-60, 30, 60)
const WINDUP_POS := Vector3(0.2, 0.2, 0.0)
# 当前挥砍已结算的敌人集合（每次挥砍重置），用实例 id 去重
var melee_hit_targets: Dictionary = {}

var mouse_sensitivity = 700
var gamepad_sensitivity := 0.075

var mouse_captured := true

var movement_velocity: Vector3
var rotation_target: Vector3

var input_mouse: Vector2

var health: int = 100
var gravity := 0.0

# 护盾状态（issue 01，ADR 010）
# shield 当前值（float 因 regen_rate 每帧增量小于 1）
# _shield_regen_timer：受击后倒计时到 0 才开始回盾；为 0 表示"正在回盾或满盾"
# _dead：死亡守卫，died 信号只发射一次
var shield: float = 0.0
var _shield_regen_timer: float = 0.0
var _dead := false

# issue 05：升级 bonus 字段（运行时状态，随场景 reload 自然重置）
# 射击/换弹/移动/护盾/备弹代码读取"有效值" = 基础值 + bonus 或 × multiplier
# 不修改 Weapon 资源（.tres 全局共享，改会跨局污染）
var bonus_max_reserve: int = 0
var damage_multiplier: float = 1.0
var reload_time_multiplier: float = 1.0
var move_speed_bonus: float = 0.0
var shield_regen_rate_bonus: float = 0.0

var previously_floored := false

# 卡住状态机（ADR 016）
var stuck_state: StuckState = StuckState.NORMAL
var _stuck_timer: float = 0.0          # 卡住判定累加器
var _last_move_dir: Vector3 = Vector3.BACK  # 最后有效移动方向（缓存）
var _escape_distance: float = 0.0       # 已推出距离
const STUCK_DETECT_TIME := 0.5         # 卡住判定持续时间
const STUCK_SPEED_THRESHOLD := 0.3     # 低于此速度视为无有效位移
const ESCAPE_SPEED := 0.5              # 推回速度（m/s）
const ESCAPE_MAX_DISTANCE := 8.0       # 推回安全上限（m）

# 天空缓降：生成时从高处慢慢落下
const DROP_HEIGHT := 10.0   # 出生点上方偏移（米）
const DROP_SPEED := 4.0     # 缓降速度（米/秒）
var _dropping := true        # 正在缓降中

var jumps_remaining: int

var container_offset = Vector3(1.2, -1.1, -2.75)

const DEFAULT_FOV := 75.0
const AIM_FOV := 60.0
const ADS_SPEED_FACTOR := 0.7
const ADS_SPREAD_FACTOR := 0.5

# 连锁 Aggro：玩家开枪的 alert 传播半径
const SHOOT_ALERT_RADIUS := 30.0

var is_aiming := false

var tween: Tween

signal health_updated
# 护盾变化信号（参数：当前 shield / shield_max），供 HUD 绘制护盾条（issue 07）
signal shield_updated(shield: float, shield_max: float)
# 玩家死亡信号（无参数，带 _dead 守卫防重复），由 Game Over UI（issue 06）监听
signal died
# 卡住状态变迁信号（ADR 016），供 HUD 显示/隐藏提示
signal stuck_state_changed(new_state: StuckState)
# 弹药 HUD 信号 —— 由 HUD 监听以渲染右下角列表与进度条
# magazines/reserves 为当前所有武器的弹药快照（Array[int]）
signal ammo_updated(weapon_index: int, magazines: Array, reserves: Array)
signal reload_started(weapon_index: int, reload_time: float)
signal reload_ended(weapon_index: int, cancelled: bool)

@onready var camera = $Head/Camera
@onready var muzzle = $Head/Camera/SubViewportContainer/SubViewport/CameraItem/Muzzle
@onready var container = $Head/Camera/SubViewportContainer/SubViewport/CameraItem/Container
@onready var camera_item = $Head/Camera/SubViewportContainer/SubViewport/CameraItem
@onready var melee_hitbox: Area3D = $MeleeHitbox
@onready var sound_footsteps = $SoundFootsteps
@onready var blaster_cooldown = $Cooldown

@export var crosshair: TextureRect

# Functions

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# 天空缓降：从出生点上方慢慢落下
	position.y += DROP_HEIGHT
	_dropping = true

	# 护盾初值满（issue 01，ADR 010）
	shield = shield_max
	_shield_regen_timer = 0.0
	_dead = false

	# 初始化每把枪的弹匣/备弹（满弹匣 + 满备弹）
	magazine.clear()
	reserve.clear()
	for w in weapons:
		magazine.append(w.magazine_size)
		reserve.append(w.max_reserve)

	weapon = weapons[weapon_index] # Weapon must never be nil
	initiate_change_weapon(weapon_index)
	_emit_ammo_updated()

	# 近战视图模型：实例化一次，挂 CameraItem 下（与 Container 平级，不在 Container 内
	# 否则会被 change_weapon() 的 remove_child() 清掉）。初始隐藏。
	# 参见 ADR 006 后续决策「Viewmodel 生命周期」与 CONTEXT.md 同名术语条目。
	if melee_viewmodel:
		melee_viewmodel_instance = melee_viewmodel.instantiate()
		camera_item.add_child(melee_viewmodel_instance)
		melee_viewmodel_instance.visible = false
		# 与 change_weapon() 中枪械模型一致：仅武器相机可见（layer 2）
		for child in melee_viewmodel_instance.find_children("*", "MeshInstance3D"):
			child.layers = 2

	# 命中区深度跟随 melee_reach（@export，可 inspector 调参，见 PRD/CONTEXT「Melee Tuning」）
	# 复制 BoxShape3D 避免改写场景内联 sub-resource
	var hit_shape := melee_hitbox.get_node_or_null("HitShape")
	if hit_shape and hit_shape.shape is BoxShape3D:
		var box := (hit_shape.shape as BoxShape3D).duplicate()
		box.size.z = melee_reach
		hit_shape.shape = box

# 物理处理：移动、重力、碰撞 —— 必须在固定物理 tick 中运行
func _physics_process(delta):
	if not is_inside_tree(): return

	handle_gravity(delta)

	# === 卡住状态机处理（ADR 016）===
	match stuck_state:
		StuckState.STUCK:
			# STUCK：禁止移动，等待按 G
			movement_velocity = Vector3.ZERO
			velocity = Vector3(0, -gravity, 0)
			move_and_slide()
			return
		StuckState.ESCAPING:
			# ESCAPING：沿进入反方向匀速推出
			var push_dir := -_last_move_dir
			global_position += push_dir * ESCAPE_SPEED * delta
			_escape_distance += ESCAPE_SPEED * delta
			# 终止判定：推出距离超限 → 强制恢复
			if _escape_distance >= ESCAPE_MAX_DISTANCE:
				_set_stuck_state(StuckState.NORMAL)
			else:
				# test_move 检测前方是否仍有碰撞
				var result := KinematicCollision3D.new()
				var hit := test_move(global_transform, push_dir * 0.1, result)
				if not hit:
					_set_stuck_state(StuckState.NORMAL)
			# 应用重力保持贴地
			velocity = Vector3(0, -gravity, 0)
			move_and_slide()
			return
		StuckState.NORMAL:
			pass

	# Movement: 将局部输入方向转为世界方向
	movement_velocity = transform.basis * movement_velocity

	# 帧率无关的平滑加速（用 exp 衰减替代 delta * 10）
	var applied_velocity: Vector3 = velocity.lerp(movement_velocity, 1.0 - exp(-10.0 * delta))
	applied_velocity.y = -gravity

	velocity = applied_velocity
	# Auto-Step：在 move_and_slide 之前用 test_move 检测前方台阶并抬升
	_try_auto_step(delta)
	move_and_slide()

	# === 卡住检测（NORMAL 状态下）===
	_detect_stuck(delta)

func _process(delta):
	if not is_inside_tree(): return

	# 输入处理（每渲染帧读取，保证响应灵敏）
	handle_controls(delta)

	# 武器模型位置（帧率无关 lerp）
	container.position = lerp(container.position, container_offset - (basis.inverse() * velocity / 30), 1.0 - exp(-10.0 * delta))

	# 脚步声
	sound_footsteps.stream_paused = true
	if is_on_floor():
		if abs(velocity.x) > 1 or abs(velocity.z) > 1:
			sound_footsteps.stream_paused = false

	# ADS FOV 过渡
	if is_aiming:
		camera.fov = move_toward(camera.fov, AIM_FOV, delta * 150.0)
	else:
		camera.fov = move_toward(camera.fov, DEFAULT_FOV, delta * 150.0)

	# 落地相机回弹（帧率无关 lerp）
	camera.position.y = lerp(camera.position.y, 0.0, 1.0 - exp(-5.0 * delta))

	if is_on_floor() and gravity > 1 and !previously_floored:
		Audio.play("sounds/land.ogg")
		camera.position.y = -0.1

	previously_floored = is_on_floor()

	# 换弹计时
	_step_reload(delta)

	# 护盾延时恢复（issue 01，ADR 010）
	# Player 为 PROCESS_MODE_PAUSABLE，暂停期间本函数不被调用，regen 自然冻结
	_step_shield_regen(delta)

	# 近战冷却推进
	if melee_cooldown_remaining > 0.0:
		melee_cooldown_remaining = maxf(0.0, melee_cooldown_remaining - delta)

	# 近战命中结算
	_melee_process_hits()

	# 坠落检测
	if position.y < -10:
		get_tree().reload_current_scene()

# 弹药快照广播 —— 任何修改 magazine/reserve 的操作后调用
func _emit_ammo_updated() -> void:
	if not is_inside_tree(): return
	ammo_updated.emit(weapon_index, magazine.duplicate(), reserve.duplicate())

# Auto-Step：在地面+水平移动时，自动登高 ≤ step_height 的台阶。
#
# 使用 test_move（完整碰撞形状）而非 intersect_ray，精确检测前方台阶顶面。
# 在 move_and_slide 之前抬升，使 move_and_slide 的碰撞响应不再碰到台阶垂直面。
# 参考社区经典实现：https://dresswithpockets.github.io/2025/03/19/godot-stair-stepping.html
#
# 参见 ADR 003 与 CONTEXT.md "Auto-Step" 术语条目。

func _try_auto_step(delta: float) -> void:
	if not is_on_floor():
		return

	var horiz_vel := Vector3(velocity.x, 0.0, velocity.z)
	if horiz_vel.length() < 0.5:
		return

	var max_step := StepConstants.STEP_HEIGHT

	# 测试位置：当前位置 + 水平移动量 + 抬高 max_step
	var sweep_transform := global_transform.translated(
		horiz_vel * delta + Vector3(0.0, max_step, 0.0)
	)
	var down_motion := Vector3(0.0, -max_step, 0.0)
	var result := KinematicCollision3D.new()

	var hit := test_move(sweep_transform, down_motion, result)

	if not hit:
		return # 前方无地面，不抬升

	# 命中点高度 - (原高度 + max_step) = -travel.y，travel 是向下移动量
	# step_height = max_step - |travel.y| = max_step + travel.y
	var travel_y := result.get_travel().y # 负值（向下）
	var step_up := max_step + travel_y

	# 抬升量必须在 (0, max_step) 区间
	if step_up <= 0.01 or step_up >= max_step:
		return

	global_position.y += step_up

# Mouse movement

func _input(event):
	if event is InputEventMouseMotion and mouse_captured:
		input_mouse = event.relative / mouse_sensitivity
		handle_rotation(event.relative.x, event.relative.y, false)

func handle_controls(delta):
	# Mouse capture
	if Input.is_action_just_pressed("mouse_capture"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		mouse_captured = true
	
	if Input.is_action_just_pressed("mouse_capture_exit"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		mouse_captured = false
		
		input_mouse = Vector2.ZERO
	
	# === 卡住状态下的输入处理（ADR 016）===
	if stuck_state == StuckState.STUCK:
		# STUCK：只允许视角转动和射击，禁止移动/跳跃
		# 按 G 触发挣扎
		if Input.is_action_just_pressed("struggle"):
			_start_escape()
		# 射击仍允许
		action_shoot()
		# 视角转动仍允许（由 _input 处理，不在此处）
		# 换弹/近战仍允许
		if Input.is_action_just_pressed("reload"):
			action_reload(weapon_index)
		if Input.is_action_just_pressed("melee"):
			action_melee()
		movement_velocity = Vector3.ZERO
		return
	elif stuck_state == StuckState.ESCAPING:
		# ESCAPING：只允许视角/射击/换弹/近战，不可取消
		action_shoot()
		if Input.is_action_just_pressed("reload"):
			action_reload(weapon_index)
		if Input.is_action_just_pressed("melee"):
			action_melee()
		movement_velocity = Vector3.ZERO
		return

	# Movement
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	# ADS movement speed penalty
	is_aiming = Input.is_action_pressed("aim")
	if is_aiming and not mouse_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		mouse_captured = true
	var speed_multiplier = ADS_SPEED_FACTOR if is_aiming else 1.0
	
	movement_velocity = Vector3(input.x, 0, input.y).normalized() * (movement_speed + move_speed_bonus) * speed_multiplier
	
	# Handle Controller Rotation
	var rotation_input := Input.get_vector("camera_right", "camera_left", "camera_down", "camera_up")
	if rotation_input:
		handle_rotation(rotation_input.x, rotation_input.y, true, delta)
	
	# Shooting
	

	action_shoot()

	# Reload (manual via R 键)
	if Input.is_action_just_pressed("reload"):
		action_reload(weapon_index)

	# Melee (V 键) —— 独立近战入口，与换弹/射击互不阻塞（见 ADR 006）
	if Input.is_action_just_pressed("melee"):
		action_melee()

	# Jumping

	if Input.is_action_just_pressed("jump"):
		if jumps_remaining:
			action_jump()

	# Weapon switching

	action_weapon_toggle()

# Camera rotation

func handle_rotation(xRot: float, yRot: float, isController: bool, delta: float = 0.0):
	if isController:
		rotation_target -= Vector3(-yRot, -xRot, 0).limit_length(1.0) * gamepad_sensitivity
		rotation_target.x = clamp(rotation_target.x, deg_to_rad(-90), deg_to_rad(90))
		camera.rotation.x = lerp_angle(camera.rotation.x, rotation_target.x, delta * 25)
		rotation.y = lerp_angle(rotation.y, rotation_target.y, delta * 25)
	else:
		rotation_target += (Vector3(-yRot, -xRot, 0) / mouse_sensitivity)
		rotation_target.x = clamp(rotation_target.x, deg_to_rad(-90), deg_to_rad(90))
		camera.rotation.x = rotation_target.x;
		rotation.y = rotation_target.y;
	
# Handle gravity

func handle_gravity(delta):
	# 缓降阶段：以固定低速下降，不加速
	if _dropping:
		gravity = DROP_SPEED
		if is_on_floor():
			_dropping = false
			gravity = 0.0
			jumps_remaining = number_of_jumps
		return

	gravity += 20 * delta

	if gravity < 0 and is_on_ceiling():
		gravity = 0
	
	if gravity > 0 and is_on_floor():
		jumps_remaining = number_of_jumps
		gravity = 0

# Jumping

func action_jump():
	Audio.play("sounds/jump_a.ogg, sounds/jump_b.ogg, sounds/jump_c.ogg")
	gravity = - jump_strength
	jumps_remaining -= 1

# Shooting

func action_shoot():
	if Input.is_action_pressed("shoot"):
		if !blaster_cooldown.is_stopped(): return # Cooldown for shooting
		if not camera.is_inside_tree(): return # camera 在 SubViewport 中初始化或场景切换时可能离树

		# 换弹中禁射
		if is_reloading: return

		# 弹匣空：扣扳机无效（不发射、不进冷却），并自动触发换弹
		if magazine[weapon_index] <= 0:
			action_reload(weapon_index)
			return

		Audio.play(weapon.sound_shoot)

		# 连锁 Aggro：玩家开枪 emit alert（穿墙传播，惊动远处 IDLE 怪物）
		AlertSystem.emit_alert(global_position, SHOOT_ALERT_RADIUS)

		# Set muzzle flash position, play animation

		muzzle.play("default")

		muzzle.rotation_degrees.z = randf_range(-45, 45)
		muzzle.scale = Vector3.ONE * randf_range(0.40, 0.75)
		muzzle.position = container.position - weapon.muzzle_position

		# 扣减弹匣
		magazine[weapon_index] -= 1

		blaster_cooldown.start(weapon.cooldown)

		# Shoot the weapon, amount based on shot count

		for n in weapon.shot_count:
			# Calculate shoot direction with spread (halved when ADS)
			var effective_spread = weapon.spread * ADS_SPREAD_FACTOR if is_aiming else weapon.spread
			var spread_x = randf_range(-effective_spread, effective_spread) * 0.02
			var spread_y = randf_range(-effective_spread, effective_spread) * 0.02
			var shoot_direction = (camera.global_transform.basis * Vector3(spread_x, spread_y, -1)).normalized()

			# Spawn projectile
			var projectile = preload("res://objects/projectile.tscn")
			var projectile_instance = projectile.instantiate()

			projectile_instance.direction = shoot_direction
			projectile_instance.speed = weapon.projectile_speed
			projectile_instance.damage = weapon.damage * damage_multiplier
			projectile_instance.max_distance = weapon.max_distance
			projectile_instance.color = weapon.projectile_color
			projectile_instance.scale = weapon.projectile_size
			projectile_instance.shooter = self

			get_tree().root.add_child(projectile_instance)
			projectile_instance.global_position = camera.global_transform.origin + (camera.global_transform.basis * Vector3(0.15, -0.1, -0.5))

		var knockback = random_vec2(weapon.min_knockback, weapon.max_knockback)
		# print('knockback', knockback)
		container.position.z += 0.25 # Knockback of weapon visual
		camera.rotation.x += knockback.x # Knockback of camera
		rotation.y += knockback.y
		rotation_target.x += knockback.x
		rotation_target.y += knockback.y
		movement_velocity += Vector3(0, 0, weapon.knockback) # Knockback

		_emit_ammo_updated()

# Toggle between available weapons (listed in 'weapons')

func action_weapon_toggle():
	if Input.is_action_just_pressed("weapon_toggle"):
		# 切枪取消换弹（不在切换动画末尾才取消，避免新武器继承旧换弹状态）
		_cancel_reload()
		weapon_index = wrap(weapon_index + 1, 0, weapons.size())
		initiate_change_weapon(weapon_index)

		Audio.play("sounds/weapon_change.ogg")

# Initiates the weapon changing animation (tween)

func initiate_change_weapon(index):
	weapon_index = index

	tween = get_tree().create_tween()
	tween.set_ease(Tween.EASE_OUT_IN)
	tween.tween_property(container, "position", container_offset - Vector3(0, 1, 0), 0.1)
	tween.tween_callback(change_weapon) # Changes the model

# Switches the weapon model (off-screen)

func change_weapon():
	weapon = weapons[weapon_index]

	# Step 1. Remove previous weapon model(s) from container

	for n in container.get_children():
		container.remove_child(n)

	# Step 2. Place new weapon model in container

	var weapon_model = weapon.model.instantiate()
	container.add_child(weapon_model)

	weapon_model.position = weapon.position
	weapon_model.rotation_degrees = weapon.rotation

	# Step 3. Set model to only render on layer 2 (the weapon camera)

	for child in weapon_model.find_children("*", "MeshInstance3D"):
		child.layers = 2

	# Set weapon data

	# crosshair 在独立实例化（非 main.tscn 内）时可能为 null，做防御
	if crosshair:
		crosshair.texture = weapon.crosshair
	_emit_ammo_updated() # 切枪后高亮 + 数值刷新

# === 换弹机制（T4 + T5）===
# 触发：R 键手动 / 弹匣空时扣扳机自动
# 期间：禁射、切枪取消、备弹不足只装可用数
# 完成：reserve → magazine 转移，emit ammo_updated
# 视觉：复用 container Tween 让武器移出视野再归位（T5）；HUD 进度条由 HUD 自行驱动

func action_reload(index: int) -> void:
	if is_reloading: return
	if index < 0 or index >= weapons.size(): return
	var w := weapons[index]
	# 弹匣已满或备弹为零则不换弹
	if magazine[index] >= w.magazine_size: return
	if reserve[index] <= 0: return

	is_reloading = true
	reload_index = index
	# issue 05：有效换弹时间 = 基础值 × reload_time_multiplier（升级 -10% 换弹 = ×0.9）
	var effective_reload_time := w.reload_time * reload_time_multiplier
	reload_time_remaining = effective_reload_time

	# T5：武器模型换弹动画 —— 移出视野再归位（与切枪动画共享 Tween 机制但不切换模型）
	if reload_tween and reload_tween.is_valid():
		reload_tween.kill()
	reload_tween = get_tree().create_tween()
	reload_tween.set_ease(Tween.EASE_OUT_IN)
	reload_tween.tween_property(container, "position", container_offset - Vector3(0, 1, 0), effective_reload_time * 0.5)
	reload_tween.tween_property(container, "position", container_offset, effective_reload_time * 0.5)

	if is_inside_tree():
		reload_started.emit(index, effective_reload_time)

# 每帧推进换弹计时；到点完成 reserve → magazine 转移
func _step_reload(delta: float) -> void:
	if not is_reloading: return
	if not is_inside_tree(): return
	reload_time_remaining -= delta
	if reload_time_remaining > 0.0:
		return

	# 完成转移：尽量填满弹匣，备弹不足则只装可用数
	var idx := reload_index
	var w := weapons[idx]
	var needed := w.magazine_size - magazine[idx]
	var moved := mini(needed, reserve[idx])
	magazine[idx] += moved
	reserve[idx] -= moved

	_reset_reload_state(false)

# 取消换弹（切枪 / 场景切换等触发），不转移弹药
func _cancel_reload() -> void:
	if not is_reloading:
		return
	_reset_reload_state(true)

# 收尾换弹状态：复位标志、kill Tween、归位 container、emit reload_ended
# cancelled=true 表示未完成转移（切枪等），false 表示自然完成
func _reset_reload_state(cancelled: bool) -> void:
	var idx := reload_index
	is_reloading = false
	reload_index = -1
	reload_time_remaining = 0.0
	if reload_tween and reload_tween.is_valid():
		reload_tween.kill()
		container.position = container_offset
	if is_inside_tree() and idx >= 0:
		reload_ended.emit(idx, cancelled)
		if not cancelled:
			_emit_ammo_updated()

# === 近战系统（T3 + T4）===
# 独立于 weapons/magazine/reserve；与换弹/射击互不阻塞（见 ADR 006）
# 视觉：下劈（剑从右上→左下）；命中区：前方 Area3D，仅活跃帧 monitoring
# 调参初版：melee_damage=40、melee_cooldown=0.5s、reach=2.0m、宽高≈1.5m

func action_melee() -> void:
	# 冷却中：拒绝触发（不查 is_reloading——近战与换弹互不阻塞）
	if melee_cooldown_remaining > 0.0:
		return
	if melee_viewmodel_instance == null:
		return

	melee_cooldown_remaining = melee_cooldown

	# 显示 viewmodel
	melee_viewmodel_instance.visible = true

	# 杀掉旧 Tween（防连续挥砍叠加）
	if melee_swing_tween and melee_swing_tween.is_valid():
		melee_swing_tween.kill()

	# 下劈动画：剑从右上→左下，分三段对应前摇/活跃帧/后摇
	# 同时 tween rotation_degrees 与 position（见 CONTEXT.md「Swing Animation Style」）
	# 注：to_val 在 tween_property 调用时求值（非 step 启动时），故三步均以 start_* 为基准
	var tween := get_tree().create_tween()
	melee_swing_tween = tween
	var start_rotation := melee_viewmodel_instance.rotation_degrees
	var start_position := melee_viewmodel_instance.position

	# 前摇 0.1s：从锚点举到右上（蓄力）
	tween.tween_property(melee_viewmodel_instance, "rotation_degrees", start_rotation + WINDUP_ROT, 0.1)
	tween.parallel().tween_property(melee_viewmodel_instance, "position", start_position + WINDUP_POS, 0.1)
	# 活跃帧 0.2s：从右上划到左下（target = start - 2× WINDUP 形成下劈弧线）
	tween.tween_property(melee_viewmodel_instance, "rotation_degrees", start_rotation - WINDUP_ROT * 2, 0.2)
	tween.parallel().tween_property(melee_viewmodel_instance, "position", start_position - WINDUP_POS * 2, 0.2)
	# 后摇 0.1s：复位
	tween.tween_property(melee_viewmodel_instance, "rotation_degrees", start_rotation, 0.1)
	tween.parallel().tween_property(melee_viewmodel_instance, "position", start_position, 0.1)
	# 收尾：隐藏
	tween.tween_callback(func(): melee_viewmodel_instance.visible = false)

	# 命中区 monitoring 切换：用 create_timer 与挥砍 Tween 解耦
	# 理由：若用 tween_callback，挥砍 Tween 被 kill（连续挥砍）时回调不触发，monitoring 可能滞留
	# 参见 CONTEXT.md「Active Frames」对该实现的说明
	melee_hit_targets.clear()
	melee_hitbox.monitoring = false # 保险：先关再开

	# 前摇结束 → 开启 monitoring（活跃帧开始）
	get_tree().create_timer(ACTIVE_START).timeout.connect(func():
		if is_inside_tree():
			melee_hitbox.monitoring = true
	)
	# 后摇开始 → 关闭 monitoring（活跃帧结束）
	get_tree().create_timer(ACTIVE_END).timeout.connect(func():
		melee_hitbox.monitoring = false
	)

# 每帧检查命中区重叠体，按 has_method("damage") 过滤并去重结算
# 墙体 StaticBody3D 无 damage() 自然被跳过（接受薄墙穿墙边缘情况，见 CONTEXT.md）
func _melee_process_hits() -> void:
	if not melee_hitbox or not melee_hitbox.monitoring:
		return
	var bodies := melee_hitbox.get_overlapping_bodies()
	for body in bodies:
		if not is_instance_valid(body):
			continue
		# 排除玩家自身（MeleeHitbox 挂在 Player 根下，会检测到自己的 CharacterBody3D）
		if body == self:
			continue
		if not body.has_method("damage"):
			continue
		var id := body.get_instance_id()
		if melee_hit_targets.has(id):
			continue # 本次挥砍已结算过，跳过
		melee_hit_targets[id] = true
		body.damage(melee_damage) # 自动触发 HitFeedback.flash，见 ADR 005

# === 护盾与血量管线（issue 01，ADR 010）===
# damage(amount)：先减 shield，溢出才减 health；重置护盾 regen 计时器；
# health <= 0 触发 died 信号（_dead 守卫防重复），不再裸 reload_current_scene
# （Game Over UI 由 issue 06 接管）。
func damage(amount: float) -> void:
	if _dead:
		return
	# 先扣护盾，溢出扣血
	var overflow := amount - shield
	shield = maxf(0.0, shield - amount)
	if overflow > 0.0:
		# health 为 int，溢出按 int 扣减（amount 通常已是整数）
		health = max(0, health - int(round(overflow)))
	# 重置护盾 regen 倒计时（战斗中亦可恢复——只要不再受击超过 delay）
	_shield_regen_timer = shield_regen_delay
	# 广播护盾/血量变化
	shield_updated.emit(shield, shield_max)
	health_updated.emit(health)
	# 死亡判定：原 health < 0 改为 <= 0，避免 0 血不死
	if health <= 0 and not _dead:
		_dead = true
		# 死亡优先：取消卡住/推回状态（ADR 016）
		if stuck_state != StuckState.NORMAL:
			_set_stuck_state(StuckState.NORMAL)
		died.emit()

# 护盾延时恢复：受击后倒计时 delay，到点每帧按 rate 回盾（不超过 max）
# 在 _process 中调用；Player 为 PAUSABLE，暂停期间自然冻结
func _step_shield_regen(delta: float) -> void:
	if _dead:
		return
	if shield >= shield_max:
		return
	if _shield_regen_timer > 0.0:
		_shield_regen_timer = maxf(0.0, _shield_regen_timer - delta)
		return
	shield = minf(shield_max, shield + (shield_regen_rate + shield_regen_rate_bonus) * delta)
	shield_updated.emit(shield, shield_max)

# 治疗方法（issue 03 共用）：加血不超过 max_health，不影响护盾，不发 damage 管线
func heal(amount: int) -> void:
	if _dead:
		return
	health = min(health + amount, max_health)
	health_updated.emit(health)

# issue 05：有效备弹上限 = weapon.max_reserve + bonus_max_reserve（不改 Weapon 资源）
# 供 issue 04 商店购买上限检查、issue 08 宝箱备弹补给回满使用
func effective_max_reserve(weapon: Weapon) -> int:
	return weapon.max_reserve + bonus_max_reserve

# Create a random knockback vector
static func random_vec2(_min: Vector2, _max: Vector2) -> Vector2:
	var _sign = -1 if randi() % 2 == 0 else 1
	return Vector2(randf_range(_min.x, _max.x), randf_range(_min.y, _max.y) * _sign)

# === 卡住状态机辅助方法（ADR 016，issue 05）===

# 状态变迁 + 发信号
func _set_stuck_state(new_state: StuckState) -> void:
	if stuck_state == new_state:
		return
	stuck_state = new_state
	if new_state == StuckState.ESCAPING:
		_escape_distance = 0.0
	stuck_state_changed.emit(new_state)

# 卡住检测：在 NORMAL 状态下每帧调用
func _detect_stuck(delta: float) -> void:
	# 排除条件：缓降中 / 不在地面 / 已死亡
	if _dropping or _dead:
		_stuck_timer = 0.0
		return
	if not is_on_floor():
		_stuck_timer = 0.0
		return

	# 缓存最后有效移动方向（速度 > 0.5 时更新）
	var horiz_vel := Vector3(velocity.x, 0.0, velocity.z)
	if horiz_vel.length() > 0.5:
		_last_move_dir = horiz_vel.normalized()

	# 检测条件：有输入 + 速度极低
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input.length() < 0.1:
		# 无输入（靠墙站立）不触发
		_stuck_timer = 0.0
		return

	if horiz_vel.length() < STUCK_SPEED_THRESHOLD:
		_stuck_timer += delta
		if _stuck_timer >= STUCK_DETECT_TIME:
			_set_stuck_state(StuckState.STUCK)
	else:
		_stuck_timer = 0.0

# 按 G 触发挣扎：STUCK → ESCAPING
func _start_escape() -> void:
	if stuck_state != StuckState.STUCK:
		return
	# 如果 _last_move_dir 为零向量（极端情况），用玩家朝向后方
	if _last_move_dir.length() < 0.01:
		_last_move_dir = -transform.basis.z
	_set_stuck_state(StuckState.ESCAPING)
