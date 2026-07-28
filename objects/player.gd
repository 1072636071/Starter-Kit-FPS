extends CharacterBody3D

# 预加载 MeleeVFX class_name，确保 headless 模式下全局类注册
const _MeleeVFX = preload("res://scripts/melee_vfx.gd")

# === 卡住状态机（ADR 016，issue 05）===
enum StuckState { NORMAL, STUCK, ESCAPING }

@export_subgroup("Properties")
@export var movement_speed = 5
@export_range(0, 100) var number_of_jumps: int = 2
@export var jump_strength = 8

@export_subgroup("Weapons")
## 已装备武器列表；上限 MAX_WEAPONS（issue 09，超出截断）
@export var weapons: Array[Weapon] = []:
	set(value):
		weapons = value
		if weapons.size() > MAX_WEAPONS:
			weapons.resize(MAX_WEAPONS)

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
@export var melee_cooldown: float = 0.7
@export var melee_reach: float = 2.0
@export var melee_viewmodel: PackedScene

var weapon: Weapon
var weapon_index := 0

# 武器数量上限（issue 09，ADR 022）
const MAX_WEAPONS := 3
# 弹药池初始值（issue 09）：每种弹药类型初始 36 发（旧系统，供测试兼容）
# 实际开局可用备弹由下方 ammo_slots 初始化提供（100 发）
const INITIAL_AMMO_PER_TYPE := 36
# 保底弹药类型：弹药池至少包含手枪弹（issue 09）
const AMMO_TYPE_PISTOL: StringName = &"手枪弹"

# 弹药状态：弹匣按武器独立（与 weapons 数组同序）；
# 备弹为按弹药类型（Weapon.ammo_type）共享的弹药池（issue 09，ADR 022）。
# 参见 ADR 004 / 022 与 CONTEXT.md「弹药系统」。
var magazine: Array[int] = []
## 弹药池：键为 StringName 弹药类型，值为剩余备弹数；同类弹药武器共享同一池
var ammo_reserve: Dictionary = {}
# 武器耐久（issue 09，ADR 022）：与 weapons 数组同序，初始 = durability_max；
# durability_max <= 0 表示无限耐久（跳过追踪）
var weapon_durability: Array[int] = []

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
# 近战剑弧粒子特效（ADR 020，GPUParticles3D 一次性爆发）
var melee_slash: GPUParticles3D
# 过渡动画期间为 true，_process 的 container lerp 跳过以让 Tween 完全控制（ADR 019）
var _melee_active := false
# 剑初始变换（_ready 缓存，action_melee 重置基准，防连续挥砍残留）
var _melee_sword_init_pos: Vector3
var _melee_sword_init_rot: Vector3
var _melee_sword_init_scale: Vector3
const SWING_DURATION := 0.6 # 总挥砍时长，必须 ≤ melee_cooldown（见 ADR 019）
const ACTIVE_START := 0.2   # monitoring 开启时机（前摇结束）
const ACTIVE_END := 0.4     # monitoring 关闭时机（后摇开始）
# 下劈动画相对锚点的偏移：前摇举到右上，活跃帧 = -2× 偏移划到左下形成下劈弧线
const WINDUP_ROT := Vector3(-60, 30, 60)
const WINDUP_POS := Vector3(0.2, 0.2, 0.0)
# 过渡动画偏移（ADR 019）：剑从屏外起点滑入到 windup 终点，outro 反向
const INTRO_POS_OFFSET := Vector3(0.5, 0.5, 0.0)
const INTRO_ROT_OFFSET := Vector3(-30, 0, 30)
const GUN_DROP_Y := -1.0 # 枪 Container 下沉量（相对其初始 y）
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
const SHOOT_ALERT_RADIUS := 60.0

var is_aiming := false

var tween: Tween

# 近战命中震屏衰减值（每帧 lerp 到 0，命中时置为峰值）
var _melee_hit_shake := 0.0

# issue 15：beam 武器持续射击状态
var _beam_active := false              # 是否正在持续发射 beam
var _beam_tick_accumulator := 0.0      # beam tick 累加器（秒）
var _beam_current_index := -1          # 当前 beam 对应的武器索引（防并发切枪）

# issue 23：手雷系统
var grenades: Dictionary = {&"emp": 0, &"frag": 0}
var max_grenades: int = 5
var selected_grenade_type: StringName = &"emp"
var is_charging_grenade: bool = false
var grenade_charge_time: float = 0.0
@export var grenade_min_speed := 8.0
@export var grenade_max_speed := 18.0
@export var grenade_charge_max := 1.5 # 最大蓄力时间（秒）

# issue 03：手雷抛物线预览
var _arc_preview_mesh: MeshInstance3D
var _arc_preview_material: StandardMaterial3D
var _arc_landing_mesh: MeshInstance3D
var _arc_landing_material: StandardMaterial3D
@export var arc_preview_steps := 20
@export var arc_preview_dt := 0.05

# === 背包系统（ADR 023，issue 03/04/05）===

# 背包物品：{item_key: {type: StringName, count: int, weight_per_unit: float}}
var backpack_items: Dictionary = {}

# 当前总重量和上限
var backpack_weight: float = 0.0
var backpack_max_weight: float = 80.0

# 物品重量常量（每单位）
const ITEM_WEIGHTS: Dictionary = {
	&"pistol_ammo": 0.01,
	&"rifle_ammo": 0.02,
	&"shotgun_ammo": 0.04,
	&"sniper_ammo": 0.08,
	&"energy_cell": 0.03,
	&"grenade_ammo": 0.10,
	&"health_pack": 1.5,
}

# 枪械重量按 weapon_cost 分档
func _weapon_backpack_weight(w: Weapon) -> float:
	if w.weapon_cost <= 5:
		return 3.0
	elif w.weapon_cost <= 10:
		return 5.0
	else:
		return 8.0

# 背包操作接口
func backpack_add(item_key: StringName, type: StringName, count: int, weight_per_unit: float) -> bool:
	var total_weight := weight_per_unit * count
	if not backpack_can_add(total_weight):
		return false
	if backpack_items.has(item_key):
		var entry: Dictionary = backpack_items[item_key]
		entry["count"] += count
	else:
		backpack_items[item_key] = {"type": type, "count": count, "weight_per_unit": weight_per_unit}
	backpack_weight += total_weight
	return true

func backpack_remove(item_key: StringName, count: int) -> int:
	if not backpack_items.has(item_key):
		return 0
	var entry: Dictionary = backpack_items[item_key]
	var removed := mini(count, entry["count"])
	entry["count"] -= removed
	backpack_weight -= entry["weight_per_unit"] * removed
	if entry["count"] <= 0:
		backpack_items.erase(item_key)
	return removed

func backpack_get_weight(item_key: StringName) -> float:
	if not backpack_items.has(item_key):
		return 0.0
	var entry: Dictionary = backpack_items[item_key]
	return entry["weight_per_unit"] * entry["count"]

func backpack_can_add(weight: float) -> bool:
	return (backpack_weight + weight) <= backpack_max_weight

func add_backpack_capacity(amount: float) -> void:
	backpack_max_weight += amount

## 重置背包和备弹槽到初始状态（供测试和重开使用）
func reset_backpack() -> void:
	backpack_items.clear()
	backpack_weight = 0.0
	backpack_max_weight = 80.0
	ammo_slots.clear()
	for _i in range(AMMO_SLOT_COUNT):
		ammo_slots.append({"ammo_type": &"", "remaining": 0, "capacity": 0})

# === 备弹槽系统（ADR 023，issue 04）===

const AMMO_SLOT_COUNT := 10
var ammo_slots: Array[Dictionary] = []

# 整理动画状态
var _is_packing := false

signal health_updated
# 护盾变化信号（参数：当前 shield / shield_max），供 HUD 绘制护盾条（issue 07）
signal shield_updated(shield: float, shield_max: float)
# 护盾冷却计时变化信号（参数：当前倒计时秒数），供 HUD 显示冷却倒计时
signal shield_cooldown_changed(timer: float)
# 玩家死亡信号（无参数，带 _dead 守卫防重复），由 Game Over UI（issue 06）监听
signal died
# 卡住状态变迁信号（ADR 016），供 HUD 显示/隐藏提示
signal stuck_state_changed(new_state: StuckState)
# 弹药 HUD 信号 —— 由 HUD 监听以渲染右下角列表与进度条
# magazines/reserves 为当前所有武器的弹药快照（Array[int]）
signal ammo_updated(weapon_index: int, magazines: Array, reserves: Array)
signal reload_started(weapon_index: int, reload_time: float)
signal reload_ended(weapon_index: int, cancelled: bool)
# issue 23：手雷数量变化信号，HUD 信号驱动而非每帧轮询
signal grenades_changed(grenades: Dictionary, selected_type: StringName)

@onready var camera: Camera3D = $Head/Camera
@onready var muzzle: Node3D = $Head/Camera/SubViewportContainer/SubViewport/CameraItem/Muzzle
@onready var container: Node3D = $Head/Camera/SubViewportContainer/SubViewport/CameraItem/Container
@onready var camera_item: Node3D = $Head/Camera/SubViewportContainer/SubViewport/CameraItem
@onready var melee_hitbox: Area3D = $MeleeHitbox
@onready var sound_footsteps: AudioStreamPlayer = $SoundFootsteps
@onready var blaster_cooldown: Timer = $Cooldown

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

	# 初始化弹药状态（issue 08，三层弹药流重构）：
	# 弹匣按武器独立（满弹匣）；备弹统一走三层流：
	# backpack_items（背包仓库）→ ammo_slots（备弹槽）→ magazine（弹匣）
	# 旧 ammo_reserve 不再作为数据源，保留字段但清空
	magazine.clear()
	ammo_reserve.clear()
	weapon_durability.clear()
	for w in weapons:
		magazine.append(w.magazine_size)
		weapon_durability.append(w.durability_max)

	if not weapons.is_empty():
		weapon = weapons[weapon_index]
		initiate_change_weapon(weapon_index)
	_emit_ammo_updated()

	# 初始化背包弹药：100 发首把武器弹种写入背包层（issue 08）
	# ammo_slots 初始全空，玩家按 B 打开背包手动分配到备弹槽
	backpack_items.clear()
	backpack_weight = 0.0
	if not weapons.is_empty():
		var init_ammo_type: StringName = weapons[0].ammo_type
		var init_weight: float = ITEM_WEIGHTS.get(init_ammo_type, 0.01)
		backpack_add(init_ammo_type, &"ammo", 100, init_weight)
	# 备弹槽初始化：全空
	ammo_slots.clear()
	for _i in range(AMMO_SLOT_COUNT):
		ammo_slots.append({"ammo_type": &"", "remaining": 0, "capacity": 0})

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
		# 缓存剑初始变换（ADR 019 防漂移/连续挥砍重置基准，挥砍中不被动）
		_melee_sword_init_pos = melee_viewmodel_instance.position
		_melee_sword_init_rot = melee_viewmodel_instance.rotation_degrees
		_melee_sword_init_scale = melee_viewmodel_instance.scale

		# 近战剑弧粒子特效：挂在 CameraItem 下，layer 2 仅武器相机可见（ADR 020）
		# 位置映射：MeleeHitbox 在 Player 本地 (0, 0.5, -1.0)，CameraItem 在 Head (0, 1, 0)
		# → CameraItem 本地 = (0, -0.5, -1.0)，即玩家前方 1m 腰部高度
		melee_slash = _MeleeVFX.create_slash(
			camera_item,
			_MeleeVFX.COLOR_PLAYER,
			2, # layer 2: weapon camera only
			_MeleeVFX.PLAYER_BOX_EXTENTS,
			Vector3(0, -0.5, -1.0)
		)

	# 命中区深度跟随 melee_reach（@export，可 inspector 调参，见 PRD/CONTEXT「Melee Tuning」）
	# 复制 BoxShape3D 避免改写场景内联 sub-resource
	var hit_shape := melee_hitbox.get_node_or_null("HitShape")
	if hit_shape and hit_shape.shape is BoxShape3D:
		var box := (hit_shape.shape as BoxShape3D).duplicate()
		box.size.z = melee_reach
		hit_shape.shape = box

	# issue 23：手雷初始数量（开局赠送，避免按 G 无反应）
	grenades = {&"emp": 3, &"frag": 3}

	# issue 03：手雷抛物线预览 Mesh —— 挂在 CameraItem 下，仅武器相机可见（layer 2）
	_arc_preview_mesh = MeshInstance3D.new()
	_arc_preview_mesh.name = "ArcPreview"
	_arc_preview_mesh.layers = 2
	camera_item.add_child(_arc_preview_mesh)
	_arc_preview_material = StandardMaterial3D.new()
	_arc_preview_material.albedo_color = Color.WHITE
	_arc_preview_material.flags_unshaded = true
	_arc_preview_material.flags_no_depth_test = true
	_arc_preview_mesh.visible = false

	# issue 03：落点指示器 —— 小球标记抛物线落地点
	_arc_landing_mesh = MeshInstance3D.new()
	_arc_landing_mesh.name = "ArcLanding"
	_arc_landing_mesh.layers = 2
	var landing_sphere := SphereMesh.new()
	landing_sphere.radius = 0.15
	landing_sphere.height = 0.3
	_arc_landing_mesh.mesh = landing_sphere
	_arc_landing_material = StandardMaterial3D.new()
	_arc_landing_material.albedo_color = Color(1.0, 1.0, 0.0, 0.8)
	_arc_landing_material.flags_unshaded = true
	_arc_landing_material.flags_no_depth_test = true
	_arc_landing_mesh.material_override = _arc_landing_material
	_arc_landing_mesh.visible = false
	camera_item.add_child(_arc_landing_mesh)

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
	# 近战挥砍期间跳过 lerp，让过渡 Tween 完全控制 container.position（ADR 019）
	if not _melee_active:
		container.position = lerp(container.position, container_offset - (basis.inverse() * velocity / 30), 1.0 - exp(-10.0 * delta))

	# 脚步声
	sound_footsteps.stream_paused = true
	if is_on_floor():
		if abs(velocity.x) > 1 or abs(velocity.z) > 1:
			sound_footsteps.stream_paused = false

	# ADS FOV 过渡（挥砍期间轻微扩张 FOV 增加速度感）
	var fov_target := DEFAULT_FOV
	if is_aiming:
		fov_target = AIM_FOV
	elif _melee_active:
		fov_target = DEFAULT_FOV + 5.0
	camera.fov = move_toward(camera.fov, fov_target, delta * 150.0)

	# 落地相机回弹（帧率无关 lerp）
	camera.position.y = lerp(camera.position.y, 0.0, 1.0 - exp(-5.0 * delta))

	# 近战命中震屏衰减（帧率无关 lerp），叠加在落地回弹之上
	if _melee_hit_shake > 0.001:
		camera.position.x += randf_range(-_melee_hit_shake, _melee_hit_shake)
		camera.position.y += randf_range(-_melee_hit_shake, _melee_hit_shake)
		_melee_hit_shake = lerp(_melee_hit_shake, 0.0, 1.0 - exp(-25.0 * delta))

	if is_on_floor() and gravity > 1 and !previously_floored:
		Audio.play("sounds/land.ogg")
		camera.position.y = -0.1

	previously_floored = is_on_floor()

	# 换弹计时
	_step_reload(delta)

	# beam 持续射击 tick（issue 15）：每 tick_interval 扣弹药 + 耐久 + 射线伤害
	_step_beam(delta)

	# 护盾延时恢复（issue 01，ADR 010）
	# Player 为 PROCESS_MODE_PAUSABLE，暂停期间本函数不被调用，regen 自然冻结
	_step_shield_regen(delta)

	# 近战冷却推进
	if melee_cooldown_remaining > 0.0:
		melee_cooldown_remaining = maxf(0.0, melee_cooldown_remaining - delta)

	# 近战命中结算
	_melee_process_hits()

	# issue 03：手雷抛物线预览 —— 蓄力期间每帧更新
	_update_arc_preview()

	# 坠落检测
	if position.y < -10:
		get_tree().reload_current_scene()

# 弹药快照广播 —— 任何修改 magazine/ammo_reserve 的操作后调用
# reserves 为按武器展开的备弹快照（同类弹药武器会显示同一池余量），
# 保持信号签名不变以兼容 HUD / 检视 UI（issue 09）
func _emit_ammo_updated() -> void:
	if not is_inside_tree(): return
	ammo_updated.emit(weapon_index, magazine.duplicate(), get_reserves_snapshot())

## @deprecated（issue 08）：从备弹槽汇总计算某武器的备弹发数（= 换弹次数 × 弹匣容量）
## 过渡期保留 API 兼容，内部改读 ammo_slots
func get_reserve(w: Weapon) -> int:
	if w == null:
		return 0
	return get_available_reloads(w.ammo_type) * w.magazine_size

## @deprecated（issue 08）：向背包补充弹药（过渡期兼容，内部改走 backpack_add）
func add_reserve(w: Weapon, amount: int) -> void:
	if w == null:
		return
	var weight_per_unit: float = ITEM_WEIGHTS.get(w.ammo_type, 0.01)
	if amount > 0:
		backpack_add(w.ammo_type, &"ammo", amount, weight_per_unit)
	elif amount < 0:
		backpack_remove(w.ammo_type, -amount)

## 按武器展开当前备弹快照（与 weapons 同序），返回实际发数（issue 08：从弹匣次数换算为发数）
func get_reserves_snapshot() -> Array[int]:
	var out: Array[int] = []
	for w in weapons:
		out.append(get_available_reloads(w.ammo_type) * w.magazine_size)
	return out

## 查询备弹槽中各弹种还能换弹的次数
func get_available_reloads(ammo_type: StringName) -> int:
	var total := 0
	for slot in ammo_slots:
		if slot["ammo_type"] == ammo_type:
			total += slot["remaining"]
	return total

## 返回 10 个槽的摘要
func get_slot_status() -> Array:
	var out: Array = []
	for slot in ammo_slots:
		out.append({"ammo_type": slot["ammo_type"], "remaining": slot["remaining"], "capacity": slot["capacity"]})
	return out

## 由背包 UI 调用，设置某个备弹槽
func set_ammo_slot(slot_idx: int, ammo_type: StringName, remaining: int, capacity: int) -> void:
	if slot_idx < 0 or slot_idx >= ammo_slots.size():
		return
	ammo_slots[slot_idx] = {"ammo_type": ammo_type, "remaining": remaining, "capacity": capacity}

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

	# issue 21：丢弃武器（X 键）
	if Input.is_action_just_pressed("drop_weapon"):
		action_drop_weapon()

	# issue 23：手雷投掷（G 键蓄力）
	if Input.is_action_just_pressed("throw_grenade"):
		if grenades.get(selected_grenade_type, 0) > 0:
			is_charging_grenade = true
			grenade_charge_time = 0.0

	# 背包（B 键打开）
	if Input.is_action_just_pressed("backpack"):
		if not _is_packing:
			action_backpack()

	if Input.is_action_just_released("throw_grenade") and is_charging_grenade:
		_throw_grenade()
		is_charging_grenade = false

	# 蓄力期间：累计时间 + 切换手雷类型
	if is_charging_grenade:
		grenade_charge_time = minf(grenade_charge_time + delta, grenade_charge_max)
		if Input.is_action_just_pressed("grenade_switch"):
			selected_grenade_type = &"frag" if selected_grenade_type == &"emp" else &"emp"

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
		if not camera.is_inside_tree(): return # camera 在 SubViewport 中初始化或场景切换时可能离树
		if weapon == null: return # 空手（武器全部损毁）不可射击（issue 09）

		# 整理中禁射
		if _is_packing: return

		# 换弹中禁射
		if is_reloading: return

		# === beam 模式（issue 15）：持续射线，不依赖 cooldown/弹体 ===
		if weapon.weapon_mode == "beam":
			# 守卫：weapon 必须仍在 weapons 数组中（爆枪后 weapon 引用可能已过时）
			if weapon_index < 0 or weapon_index >= weapons.size() or weapons[weapon_index] != weapon:
				return
			# 弹匣空：不发射，自动换弹
			if magazine[weapon_index] <= 0:
				_stop_beam_active()
				action_reload(weapon_index)
				return
			# 开始/继续 beam；beam tick 在 _process 中处理
			if not _beam_active:
				_beam_active = true
				_beam_tick_accumulator = 0.0
				_beam_current_index = weapon_index
				Audio.play(weapon.sound_shoot)
				AlertSystem.emit_alert(global_position, SHOOT_ALERT_RADIUS)
				muzzle.play("default")
			return

		# === 常规弹体模式 ===
		if !blaster_cooldown.is_stopped(): return # Cooldown for shooting

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

		# 武器耐久（issue 09，ADR 022）：每次成功击发 -1，归零触发武器损毁；
		# durability_max <= 0 为无限耐久，跳过追踪
		var shot_weapon_index := weapon_index
		var weapon_broke := false
		if weapon.durability_max > 0:
			weapon_durability[shot_weapon_index] = maxi(0, weapon_durability[shot_weapon_index] - 1)
			weapon_broke = weapon_durability[shot_weapon_index] <= 0

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

		# 耐久归零：武器损毁——碎裂粒子 + 移除 + 自动切换/空手（issue 09）
		if weapon_broke:
			_on_weapon_broken(shot_weapon_index)
	else:
		# 松开扳机：beam 模式停止持续射击
		if _beam_active:
			_stop_beam_active()

# === beam 持续射击系统（issue 15）===

## 停止 beam 持续射击，重置状态
func _stop_beam_active() -> void:
	_beam_active = false
	_beam_tick_accumulator = 0.0
	_beam_current_index = -1

## 每帧推进 beam tick：按 tick_interval 间隔扣弹药 + 耐久 + 射线伤害
func _step_beam(delta: float) -> void:
	if not _beam_active:
		return
	if weapon == null or weapon.weapon_mode != "beam":
		_stop_beam_active()
		return
	# 守卫：weapon 必须仍在 weapons 数组中（爆枪后引用已过时）
	if weapon_index < 0 or weapon_index >= weapons.size() or weapons[weapon_index] != weapon:
		_stop_beam_active()
		return
	# 切枪/换弹/弹匣空 → 停止 beam
	if weapon_index != _beam_current_index or is_reloading:
		_stop_beam_active()
		return
	if magazine[weapon_index] <= 0:
		_stop_beam_active()
		action_reload(weapon_index)
		return

	_beam_tick_accumulator += delta
	var interval := weapon.tick_interval
	if interval <= 0.0:
		interval = 0.1 # 保底默认 0.1s

	while _beam_tick_accumulator >= interval:
		_beam_tick_accumulator -= interval

		# 再次检查弹药（可能在上一 tick 耗尽）
		if magazine[weapon_index] <= 0:
			_stop_beam_active()
			action_reload(weapon_index)
			return

		# 扣弹药
		magazine[weapon_index] -= 1
		_emit_ammo_updated()

		# 扣耐久（issue 01：beam 武器耐久按 tick 递减）
		var beam_index := weapon_index
		var weapon_broke := false
		if weapon.durability_max > 0:
			weapon_durability[beam_index] = maxi(0, weapon_durability[beam_index] - 1)
			weapon_broke = weapon_durability[beam_index] <= 0

		# 射线伤害：从相机向前做 raycast，命中 enemy 则结算
		_beam_deal_damage()

		# 耐久归零 → 爆枪（与普通武器相同流程）
		if weapon_broke:
			_stop_beam_active()
			_on_weapon_broken(beam_index)
			return

## beam 单 tick 射线伤害：从相机沿视线方向 raycast，命中带 damage() 方法的对象则结算
func _beam_deal_damage() -> void:
	if weapon == null or not is_inside_tree():
		return
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return
	var origin := camera.global_position
	var direction := -camera.global_transform.basis.z.normalized()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * weapon.max_distance)
	query.collision_mask = 1  # 默认碰撞层
	query.exclude = [self]
	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		return
	var collider: Variant = result.get("collider")
	if collider == null or not is_instance_valid(collider):
		return
	if collider.has_method("damage"):
		collider.damage(weapon.damage * damage_multiplier)

# === 武器耐久归零处理 ===
# 播放 0.3s 碎裂粒子 → 从 weapons/magazine/weapon_durability 移除 →
# 自动切到下一把武器；无武器则进入空手状态（weapon=null, weapon_index=-1）
func _on_weapon_broken(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return
	_stop_beam_active()
	_cancel_reload()
	_spawn_weapon_break_vfx()
	Audio.play("sounds/weapon_change.ogg")
	weapons.remove_at(index)
	weapon_durability.remove_at(index)
	magazine.remove_at(index)
	if weapons.is_empty():
		weapon = null
		weapon_index = -1
		for n in container.get_children():
			container.remove_child(n)
		if crosshair:
			crosshair.texture = null
	else:
		initiate_change_weapon(mini(index, weapons.size() - 1))
	_emit_ammo_updated()

# 武器碎裂粒子（issue 09）：0.3s 一次性爆发，世界空间播放后自动释放
func _spawn_weapon_break_vfx() -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 24
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.explosiveness = 1.0
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3.UP
	mat.spread = 90.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, -9.8, 0)
	particles.process_material = mat
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, 0.06)
	particles.draw_pass_1 = mesh
	var parent := get_parent()
	if parent == null:
		parent = self
	parent.add_child(particles)
	particles.global_position = global_position + Vector3(0, 1.2, 0)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)

# Toggle between available weapons (listed in 'weapons')

func action_weapon_toggle():
	if Input.is_action_just_pressed("weapon_toggle"):
		if weapons.is_empty(): return # 空手无可切（issue 09）
		# 切枪取消换弹（不在切换动画末尾才取消，避免新武器继承旧换弹状态）
		_cancel_reload()
		_stop_beam_active()
		weapon_index = wrap(weapon_index + 1, 0, weapons.size())
		initiate_change_weapon(weapon_index)

		Audio.play("sounds/weapon_change.ogg")

# 背包（B 键，ADR 023）
# 暂停时 / 死亡 / 商店 / 升级中不可打开
func action_backpack() -> void:
	if get_tree().paused:
		return
	if _dead:
		return
	# 通知 HUD 打开背包 UI
	var hud_node := get_tree().get_first_node_in_group("hud")
	if hud_node and hud_node.has_method("show_backpack_ui"):
		hud_node.show_backpack_ui(self)

# issue 21：丢弃当前武器（X 键）
# 在玩家位置生成 weapon_pickup，从武器数组中移除，自动切换或空手
func action_drop_weapon() -> void:
	if weapons.is_empty():
		return
	if weapon_index < 0 or weapon_index >= weapons.size():
		return

	_stop_beam_active()
	var idx := weapon_index
	var dropped_weapon: Weapon = weapons[idx]
	var dropped_durability := weapon_durability[idx] if idx < weapon_durability.size() else 0

	# 生成拾取物
	var pickup_scene: PackedScene = load("res://scenes/weapon_pickup.tscn")
	if pickup_scene == null:
		return
	# 注意：export 字段（weapon_resource / durability_current）必须在 add_child 前设置，
	# 因为 weapon_pickup._ready() 依赖 weapon_resource 来创建模型；
	# 但 global_position 必须在 add_child 后设置——节点未入树时访问 global_transform 会触发
	# "!is_inside_tree()" 警告（见 player.gd:1016 旧行为）。
	# issue 21 regression fix：拾取物必须生成在玩家身体外（>1.5m 半径 + 0.3m 玩家半径），
	# 否则 mask=1 时 body_entered 会在下一物理帧瞬间触发，导致"丢枪即捡回"。
	# 朝玩家面向方向（相机前方水平投影）抛出 2.5m，留 0.7m 安全余量。
	var forward: Vector3 = -camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var pickup: Node3D = pickup_scene.instantiate()
	pickup.weapon_resource = dropped_weapon
	pickup.durability_current = dropped_durability
	get_parent().add_child(pickup)
	pickup.global_position = global_position + Vector3(0, 0.3, 0) + forward * 2.5

	# 从数组中移除
	weapons.remove_at(idx)
	weapon_durability.remove_at(idx)
	magazine.remove_at(idx)

	# 取消换弹
	_cancel_reload()

	# 自动切换或空手
	if weapons.is_empty():
		weapon = null
		weapon_index = -1
		for n in container.get_children():
			container.remove_child(n)
		if crosshair:
			crosshair.texture = null
	else:
		initiate_change_weapon(mini(idx, weapons.size() - 1))

	_emit_ammo_updated()

# issue 23：投掷手雷

## 计算投掷起点：玩家身体位置 + 视线前方 0.5m + 胸部高度
func _get_throw_origin() -> Vector3:
	var cam_forward := -camera.global_transform.basis.z
	cam_forward.y = 0.0
	cam_forward = cam_forward.normalized()
	return global_position + cam_forward * 0.5 + Vector3(0, 1.0, 0)

## 计算投掷方向：相机视线方向 + 略微上扬
func _get_throw_direction() -> Vector3:
	return (camera.global_transform.basis * Vector3(0, 0.15, -1)).normalized()

func _throw_grenade() -> void:
	if grenades.get(selected_grenade_type, 0) <= 0:
		return

	# 扣减手雷数量
	grenades[selected_grenade_type] -= 1

	# 计算投掷速度（蓄力线性插值）
	var charge_ratio := clampf(grenade_charge_time / grenade_charge_max, 0.1, 1.0)
	var throw_speed := lerpf(grenade_min_speed, grenade_max_speed, charge_ratio)

	var throw_dir := _get_throw_direction()
	var throw_origin := _get_throw_origin()

	# 实例化手雷弹丸
	var grenade_scene: PackedScene = load("res://scenes/grenade_projectile.tscn")
	if grenade_scene == null:
		return
	var grenade: RigidBody3D = grenade_scene.instantiate()
	grenade.grenade_type = selected_grenade_type
	# 必须先 add_child 再设 global_position（未入树时全局坐标无效）
	get_parent().add_child(grenade)
	grenade.global_position = throw_origin
	grenade.linear_velocity = throw_dir * throw_speed
	# 碰撞豁免：手雷不撞投掷者
	grenade.add_collision_exception_with(self)

	grenade_charge_time = 0.0

	# 通知 HUD 手雷数量已变化（信号驱动，避免每帧轮询）
	grenades_changed.emit(grenades, selected_grenade_type)

# Initiates the weapon changing animation (tween)

func initiate_change_weapon(index):
	if index < 0 or index >= weapons.size(): return # 越界/空手守卫（issue 09）
	weapon_index = index

	tween = get_tree().create_tween()
	tween.set_ease(Tween.EASE_OUT_IN)
	tween.tween_property(container, "position", container_offset - Vector3(0, 1, 0), 0.1)
	tween.tween_callback(change_weapon) # Changes the model

# Switches the weapon model (off-screen)

func change_weapon():
	if weapon_index < 0 or weapon_index >= weapons.size(): return # 空手/越界守卫（issue 09：武器损毁后切枪动画可能仍在途）
	weapon = weapons[weapon_index]

	# Step 1. Remove previous weapon model(s) from container

	for n in container.get_children():
		container.remove_child(n)

	# Step 2. Place new weapon model in container

	var weapon_model = weapon.model.instantiate()
	container.add_child(weapon_model)

	weapon_model.position = weapon.position
	weapon_model.rotation_degrees = weapon.rotation
	weapon_model.scale = weapon.scale # issue 22：kenney 新武器模型尺寸偏小，按资源 scale 放大

	# Step 3. Set model to only render on layer 2 (the weapon camera)

	for child in weapon_model.find_children("*", "MeshInstance3D"):
		child.layers = 2
	# Apply weapon texture if configured (workaround for GLB import texture loss)
	# issue 21 regression：拾取物丢地上无贴图——逻辑提取为 Weapon.apply_texture_to_model 静态方法共用
	if weapon.albedo_texture:
		Weapon.apply_texture_to_model(weapon_model, weapon.albedo_texture)

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
	if _is_packing: return  # 整理中不可换弹
	if index < 0 or index >= weapons.size(): return
	var w := weapons[index]
	# 弹匣已满则不换弹
	if magazine[index] >= w.magazine_size: return
	# 从备弹槽找可用换弹次数
	if get_available_reloads(w.ammo_type) <= 0:
		print("[备弹槽] 备弹槽已空，按 T 从背包补货")
		return

	# 消耗一个备弹槽
	var found := false
	for slot in ammo_slots:
		if slot["ammo_type"] == w.ammo_type and slot["remaining"] > 0:
			slot["remaining"] -= 1
			found = true
			break
	if not found:
		return

	_stop_beam_active()
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

	# 完成转移：填满弹匣（备弹槽已扣 remaining，此处将弹匣填到 magazine_size）
	var idx := reload_index
	var w := weapons[idx]
	magazine[idx] = w.magazine_size

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

	# 杀掉旧 Tween（防连续挥砍叠加）
	if melee_swing_tween and melee_swing_tween.is_valid():
		melee_swing_tween.kill()

	# 缓存挥砍前变换（防漂移基准，ADR 019 防漂移保障）
	# 用 _ready 缓存的剑初始值（非当前值，防连续挥砍 kill 后残留）
	var sword_start_rot: Vector3 = _melee_sword_init_rot
	var sword_start_pos: Vector3 = _melee_sword_init_pos
	# 枪归位目标用 container_offset（_process lerp 的目标，挥砍结束后维持）
	var gun_start_pos: Vector3 = container_offset

	# 强制重置到初始值（防连续挥砍残留：kill 后剑/枪可能停在过渡中途）
	# 同时预设剑 scale 为 0.01（出场缩放动画的起点）
	melee_viewmodel_instance.rotation_degrees = sword_start_rot
	melee_viewmodel_instance.position = sword_start_pos
	melee_viewmodel_instance.scale = Vector3(0.01, 0.01, 0.01)
	container.position = gun_start_pos

	# 过渡动画 Tween 链（ADR 019）：
	# 段1 前摇(0.2s 并行)：枪下沉 + 剑从屏外滑入 + scale 0→1
	# 段2 活跃帧(0.2s)：剑下劈（枪保持下沉位）
	# 段3 后摇(0.2s 并行)：剑滑出屏外 + 枪回升 + scale 1→0
	# 收尾：剑隐藏 + _melee_active=false + 剑变换复位
	tween = get_tree().create_tween()
	melee_swing_tween = tween

	# 屏外起点（windup 终点再往右上方推）
	var intro_pos := sword_start_pos + WINDUP_POS + INTRO_POS_OFFSET
	var intro_rot := sword_start_rot + WINDUP_ROT + INTRO_ROT_OFFSET
	# windup 终点
	var windup_pos := sword_start_pos + WINDUP_POS
	var windup_rot := sword_start_rot + WINDUP_ROT
	# 下劈终点（活跃帧）
	var slash_pos := sword_start_pos - WINDUP_POS * 2
	var slash_rot := sword_start_rot - WINDUP_ROT * 2
	var init_scale: Vector3 = _melee_sword_init_scale

	# 段1：前摇 0.2s（并行：枪下沉 + 剑从屏外滑入 + scale 0.01→1.0）
	# 缓动：SINE + EASE_IN，缓慢蓄力逐渐加速，模拟举剑的物理重量感
	# 瞬移到屏外起点发生在 visible=true 之前，避免可见跳跃
	melee_viewmodel_instance.position = intro_pos
	melee_viewmodel_instance.rotation_degrees = intro_rot
	melee_viewmodel_instance.visible = true
	_melee_active = true
	tween.tween_property(container, "position",
		Vector3(gun_start_pos.x, gun_start_pos.y + GUN_DROP_Y, gun_start_pos.z), 0.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(melee_viewmodel_instance, "position", windup_pos, 0.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(melee_viewmodel_instance, "rotation_degrees", windup_rot, 0.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(melee_viewmodel_instance, "scale", init_scale, 0.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# 段2：活跃帧 0.2s（剑下劈，枪保持）
	# 缓动：QUART + EASE_OUT，快速劈下末尾减速，打击感利落
	tween.tween_property(melee_viewmodel_instance, "position", slash_pos, 0.2) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(melee_viewmodel_instance, "rotation_degrees", slash_rot, 0.2) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	# 段3：后摇 0.2s（并行：剑滑出屏外 + 枪回升 + scale 1.0→0.01）
	# 缓动：QUAD + EASE_IN，收刀逐渐加速离场，自然过渡
	tween.tween_property(container, "position", gun_start_pos, 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(melee_viewmodel_instance, "position", intro_pos, 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(melee_viewmodel_instance, "rotation_degrees", intro_rot, 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(melee_viewmodel_instance, "scale", Vector3(0.01, 0.01, 0.01), 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 收尾：隐藏剑 + 释放 _melee_active + 复位剑变换/scale 到 start
	tween.tween_callback(func():
		melee_viewmodel_instance.visible = false
		melee_viewmodel_instance.position = sword_start_pos
		melee_viewmodel_instance.rotation_degrees = sword_start_rot
		melee_viewmodel_instance.scale = init_scale
		_melee_active = false
	)

	# 命中区 monitoring 切换：用 create_timer 与挥砍 Tween 解耦
	# 理由：若用 tween_callback，挥砍 Tween 被 kill（连续挥砍）时回调不触发，monitoring 可能滞留
	# 参见 CONTEXT.md「Active Frames」对该实现的说明
	melee_hit_targets.clear()
	melee_hitbox.monitoring = false # 保险：先关再开

	# 前摇结束 → 开启 monitoring（活跃帧开始）
	get_tree().create_timer(ACTIVE_START).timeout.connect(func():
		if is_inside_tree():
			melee_hitbox.monitoring = true
			if melee_slash:
				_MeleeVFX.trigger(melee_slash)
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
		# 命中反馈：顿帧 + 震屏，增强打击感
		_apply_hit_stop()
		_melee_hit_shake = 0.04

# 近战命中顿帧：短暂冻结时间刻度（~3 帧），模拟"砍中实体"的阻滞感
# 使用 Engine.time_scale + ignore_time_scale 计时器，不影响物理 tick
func _apply_hit_stop() -> void:
	Engine.time_scale = 0.05
	get_tree().create_timer(0.06, true, false, true).timeout.connect(
		func(): Engine.time_scale = 1.0
	)

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
		shield_cooldown_changed.emit(0.0)
		return
	if _shield_regen_timer > 0.0:
		_shield_regen_timer = maxf(0.0, _shield_regen_timer - delta)
		shield_cooldown_changed.emit(_shield_regen_timer)
		return
	shield = minf(shield_max, shield + (shield_regen_rate + shield_regen_rate_bonus) * delta)
	shield_updated.emit(shield, shield_max)
	shield_cooldown_changed.emit(0.0)

# 治疗方法（issue 03 共用）：加血不超过 max_health，不影响护盾，不发 damage 管线
func heal(amount: int) -> void:
	if _dead:
		return
	health = min(health + amount, max_health)
	health_updated.emit(health)

# issue 05：有效备弹上限 = weapon.max_reserve + bonus_max_reserve（不改 Weapon 资源）
# 供 issue 04 商店购买上限检查、issue 08 宝箱备弹补给回满使用
func effective_max_reserve(w: Weapon) -> int:
	return w.max_reserve + bonus_max_reserve

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
	# 排除条件：缓降中 / 已死亡
	# 注意：不检查 is_on_floor()——玩家可能被卡在几何体缝隙中（如房子内部），
	# 碰撞解算可能使角色不贴地，此时仍应触发卡住检测（ADR 016）。
	if _dropping or _dead:
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

# === issue 03：手雷抛物线预览 ===

## 计算抛物线采样点（世界坐标），返回 Array[Vector3]
func _get_arc_points(origin: Vector3, direction: Vector3, speed: float, steps: int = arc_preview_steps, dt: float = arc_preview_dt) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var vel := direction * speed
	var pos := origin
	var grav := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var gravity_vec := Vector3(0, -grav, 0)
	for _i in range(steps):
		pos += vel * dt
		vel += gravity_vec * dt
		points.append(pos)
		if pos.y <= 0:
			break
	return points

## 每帧更新抛物线预览：蓄力中 → 绘制弧线+落点；否则 → 隐藏
func _update_arc_preview() -> void:
	if not is_charging_grenade:
		if _arc_preview_mesh.visible:
			_arc_preview_mesh.visible = false
			_arc_preview_mesh.mesh = null
		if _arc_landing_mesh.visible:
			_arc_landing_mesh.visible = false
		return

	# 计算当前蓄力对应的投掷速度
	var charge_ratio := clampf(grenade_charge_time / grenade_charge_max, 0.1, 1.0)
	var throw_speed := lerpf(grenade_min_speed, grenade_max_speed, charge_ratio)
	var throw_dir := _get_throw_direction()

	# 起点：与 _throw_grenade 一致的投掷点（世界坐标）
	var origin := _get_throw_origin()

	# 计算抛物线点（世界坐标），转为 CameraItem 本地坐标
	var world_points := _get_arc_points(origin, throw_dir, throw_speed)
	if world_points.is_empty():
		if _arc_landing_mesh.visible:
			_arc_landing_mesh.visible = false
		return

	var local_points: Array[Vector3] = []
	for wp in world_points:
		local_points.append(camera_item.to_local(wp))

	# 构建 ImmediateMesh 绘制弧线（LINE_STRIP，白色可见线条）
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _arc_preview_material)
	for lp in local_points:
		im.surface_add_vertex(lp)
	im.surface_end()

	_arc_preview_mesh.mesh = im
	_arc_preview_mesh.visible = true

	# 落点指示器：放在最后一个弧线点位置
	if local_points.size() > 0:
		_arc_landing_mesh.position = local_points[local_points.size() - 1]
		_arc_landing_mesh.visible = true
	else:
		_arc_landing_mesh.visible = false
