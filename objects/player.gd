extends CharacterBody3D

@export_subgroup("Properties")
@export var movement_speed = 5
@export_range(0, 100) var number_of_jumps: int = 2
@export var jump_strength = 8

@export_subgroup("Weapons")
@export var weapons: Array[Weapon] = []

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

var mouse_sensitivity = 700
var gamepad_sensitivity := 0.075

var mouse_captured := true

var movement_velocity: Vector3
var rotation_target: Vector3

var input_mouse: Vector2

var health: int = 100
var gravity := 0.0

var previously_floored := false

var jumps_remaining: int

var container_offset = Vector3(1.2, -1.1, -2.75)

const DEFAULT_FOV := 75.0
const AIM_FOV := 60.0
const ADS_SPEED_FACTOR := 0.7
const ADS_SPREAD_FACTOR := 0.5

var is_aiming := false

var tween: Tween

signal health_updated
# 弹药 HUD 信号 —— 由 HUD 监听以渲染右下角列表与进度条
# magazines/reserves 为当前所有武器的弹药快照（Array[int]）
signal ammo_updated(weapon_index: int, magazines: Array, reserves: Array)
signal reload_started(weapon_index: int, reload_time: float)
signal reload_ended(weapon_index: int, cancelled: bool)

@onready var camera = $Head/Camera
@onready var muzzle = $Head/Camera/SubViewportContainer/SubViewport/CameraItem/Muzzle
@onready var container = $Head/Camera/SubViewportContainer/SubViewport/CameraItem/Container
@onready var sound_footsteps = $SoundFootsteps
@onready var blaster_cooldown = $Cooldown

@export var crosshair: TextureRect

# Functions

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# 初始化每把枪的弹匣/备弹（满弹匣 + 满备弹）
	magazine.clear()
	reserve.clear()
	for w in weapons:
		magazine.append(w.magazine_size)
		reserve.append(w.max_reserve)

	weapon = weapons[weapon_index] # Weapon must never be nil
	initiate_change_weapon(weapon_index)
	_emit_ammo_updated()

func _process(delta):
	if not is_inside_tree(): return # 场景重载/节点离树时跳过所有逻辑
	
	# Handle functions
	handle_controls(delta)
	handle_gravity(delta)
	
	# Movement
	
	var applied_velocity: Vector3
	
	movement_velocity = transform.basis * movement_velocity # Move forward
	
	applied_velocity = velocity.lerp(movement_velocity, delta * 10)
	applied_velocity.y = - gravity

	velocity = applied_velocity
	_try_auto_step() # 在 move_and_slide 之前尝试自动登高 ≤ step_height 的台阶
	move_and_slide()
	
	# Rotation 
	container.position = lerp(container.position, container_offset - (basis.inverse() * applied_velocity / 30), delta * 10)
	
	# Movement sound
	
	sound_footsteps.stream_paused = true
	
	if is_on_floor():
		if abs(velocity.x) > 1 or abs(velocity.z) > 1:
			sound_footsteps.stream_paused = false
	
	# ADS FOV transition (frame-independent linear interpolation)
	if is_aiming:
		camera.fov = move_toward(camera.fov, AIM_FOV, delta * 150.0)
	else:
		camera.fov = move_toward(camera.fov, DEFAULT_FOV, delta * 150.0)
	
	# Landing after jump or falling
	
	camera.position.y = lerp(camera.position.y, 0.0, delta * 5)
	
	if is_on_floor() and gravity > 1 and !previously_floored: # Landed
		Audio.play("sounds/land.ogg")
		camera.position.y = -0.1
	
	previously_floored = is_on_floor()

	# 换弹计时：在 _process 中累加，归零时完成转移 reserve→magazine
	_step_reload(delta)

	# Falling/respawning

	if position.y < -10:
		get_tree().reload_current_scene()

# 弹药快照广播 —— 任何修改 magazine/reserve 的操作后调用
func _emit_ammo_updated() -> void:
	if not is_inside_tree(): return
	ammo_updated.emit(weapon_index, magazine.duplicate(), reserve.duplicate())

# Auto-Step：在地面+水平移动时，自动登高 ≤ step_height 的台阶。
#
# 实现：从角色脚上方 step_height 处朝前下方 cast，命中点即为前方台阶顶。
# 抬升量必须严格小于 step_height，否则视为 Wall 不抬升。
# 抬升前检查头顶净空，避免在低矮通道里撞头。
#
# 参见 ADR 003 与 CONTEXT.md "Auto-Step" 术语条目。

func _try_auto_step() -> void:
	if not is_on_floor():
		return

	var horiz_dir := Vector3(movement_velocity.x, 0.0, movement_velocity.z)
	if horiz_dir.length() < 0.5:
		return
	var direction := horiz_dir.normalized()

	var collider := $Collider as CollisionShape3D
	if collider == null:
		return
	var shape := collider.shape as CapsuleShape3D
	if shape == null:
		return
	var capsule_half_height := shape.height * 0.5 + shape.radius
	var foot_global := collider.global_position + Vector3(0.0, -capsule_half_height, 0.0)

	var step := StepConstants.STEP_HEIGHT
	var forward_distance := 0.4 # 略大于 capsule radius(0.3)，确保 ray 越过当前 capsule
	var epsilon := 0.02

	# 前方 step 检测：从脚上方 step 高度处朝前下方 cast
	var ray_start := foot_global + Vector3(0.0, step, 0.0) + direction * forward_distance
	var ray_end := ray_start + Vector3(0.0, -step - epsilon, 0.0)

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)

	if result.is_empty():
		return

	var step_up: float = result.position.y - foot_global.y
	# 抬升量必须在 (0, step_height) 区间，否则视为同高度或 Wall
	if step_up <= epsilon or step_up >= step:
		return

	# 头顶净空检查：从 capsule 顶部向上 cast step_up + epsilon
	var head_global := collider.global_position + Vector3(0.0, capsule_half_height, 0.0)
	var head_query := PhysicsRayQueryParameters3D.create(
		head_global,
		head_global + Vector3(0.0, step_up + epsilon, 0.0)
	)
	head_query.exclude = [get_rid()]
	if not space_state.intersect_ray(head_query).is_empty():
		return # 头顶有障碍，不抬升

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
	
	# Movement
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	# ADS movement speed penalty
	is_aiming = Input.is_action_pressed("aim")
	if is_aiming and not mouse_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		mouse_captured = true
	var speed_multiplier = ADS_SPEED_FACTOR if is_aiming else 1.0
	
	movement_velocity = Vector3(input.x, 0, input.y).normalized() * movement_speed * speed_multiplier
	
	# Handle Controller Rotation
	var rotation_input := Input.get_vector("camera_right", "camera_left", "camera_down", "camera_up")
	if rotation_input:
		handle_rotation(rotation_input.x, rotation_input.y, true, delta)
	
	# Shooting
	

	action_shoot()

	# Reload (manual via R 键)
	if Input.is_action_just_pressed("reload"):
		action_reload(weapon_index)

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
			projectile_instance.damage = weapon.damage
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
	reload_time_remaining = w.reload_time

	# T5：武器模型换弹动画 —— 移出视野再归位（与切枪动画共享 Tween 机制但不切换模型）
	if reload_tween and reload_tween.is_valid():
		reload_tween.kill()
	reload_tween = get_tree().create_tween()
	reload_tween.set_ease(Tween.EASE_OUT_IN)
	reload_tween.tween_property(container, "position", container_offset - Vector3(0, 1, 0), w.reload_time * 0.5)
	reload_tween.tween_property(container, "position", container_offset, w.reload_time * 0.5)

	if is_inside_tree():
		reload_started.emit(index, w.reload_time)

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

func damage(amount):
	health -= amount
	health_updated.emit(health) # Update health on HUD
	
	if health < 0:
		get_tree().reload_current_scene() # Reset when out of health

# Create a random knockback vector
static func random_vec2(_min: Vector2, _max: Vector2) -> Vector2:
	var _sign = -1 if randi() % 2 == 0 else 1
	return Vector2(randf_range(_min.x, _max.x), randf_range(_min.y, _max.y) * _sign)
