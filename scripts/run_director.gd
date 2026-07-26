extends Node
## 竞技场运行编排器（issue 02，ADR 009 / 015）
##
## 职责：波次推进 / 难度递增 / 清场检测 / 波间手动开波 / 本局状态（金币/经验/等级/击杀/RNG）。
## 是整个循环的最高层 seam。挂在 Main 下（Monsters 的兄弟节点）。
##
## 奖励结算（issue 03）：监听每只怪物 died(monster_type) 信号，查表给金币+经验+击杀，
## 10% 概率在死亡位置掉血包；alive_count 归零 → wave_cleared。
##
## 暂停：PROCESS_MODE_PAUSABLE（默认）。商店/升级/死亡暂停期间不推进波次、不倒计时卡怪兜底。
## 触发新暂停源前检查 get_tree().paused（互斥，见 ADR 015）。

# === 配置（@export 可调）===
@export var monsters_parent: Node3D
@export var spawn_points: Array[Marker3D] = []
## 0 = 随机种子；非 0 用于测试可复现
@export var rng_seed: int = 0
## 波次超时（秒）：到点仍未清场则强制 destroy 剩余怪物，避免卡怪软锁
@export var wave_timeout: float = 120.0
## 怪物场景（过渡兼容：测试可注入假场景；正式刷怪以 ENEMY_CONFIG 为准，issue 09）
@export var monster_melee_scene: PackedScene = preload("res://objects/monster_melee.tscn")
@export var monster_ranged_scene: PackedScene = preload("res://objects/monster_ranged.tscn")
@export var enemy_scene: PackedScene = preload("res://objects/enemy.tscn")
## 血包场景（issue 03）
@export var health_pack_scene: PackedScene = preload("res://scenes/health_pack.tscn")
## 宝箱场景（issue 08 接入；为 null 则不生成宝箱）
@export var chest_scene: PackedScene
## 血包掉率
@export var health_pack_drop_chance: float = 0.10

# === 信号 ===
signal wave_started(wave_number: int)
signal wave_cleared(wave_number: int, cleared_by_timeout: bool)
signal currency_changed(copper: int)
signal xp_changed(amount: int, threshold: int)
signal level_up_offered(choices: Array)
signal game_over(stats: Dictionary)
signal kills_changed(count: int)
## issue 08：宝箱奖励选择后发射（供测试与 HUD）
signal chest_reward_selected(reward_id: StringName)
## issue 24：宝箱随机武器满槽时发射，由 chest_ui 监听以展示替换对话框
## 参数为 null 表示奖励已直接发放（空槽），chest_ui 可直接清理
signal chest_weapon_replace_offered(weapon: Weapon)

# === 本局状态 ===
var copper: int = 10000  # 初始 1 金 = 10000 铜
var xp: int = 0
var level: int = 1
var wave: int = 0
var kills: int = 0
var copper_earned_total: int = 0
var alive_count: int = 0
# issue 24：宝箱替换武器暂存（满槽时暂存待替换武器，确认后消费）
var _pending_replace_weapon: Weapon = null

var rng: RandomNumberGenerator

# === 敌人配置表（issue 09，ADR 022：数据驱动刷怪）===
# 键为怪物类型 id；条目含刷出成本 / 击杀奖励（金币 = 经验，同值）/ 解锁波次 / 场景。
# 初始仅 3 种；issue 10–14 向本表追加其余 13 种敌人条目。
# 旧的 3 个 @export 场景字段保留作测试注入与过渡兼容，优先级高于本表 scene。
#
# --- issue 27：平衡调优依据 ---
# 波次预算公式：budget(N) = 60 × 1.2^(N-1)
#   - 波 1 预算 60  → 12 只 melee（cost=5）——新手清场无压力
#   - 波 4 预算 104 → 约 8 只 ranged（cost=8）+ 5 只 melee —— 引入远程压力
#   - 波 7 预算 179 → 混合 3 种，enemy（cost=10）入场 —— 难度跃升
#   - 波 10 预算 309 → 约 30+ 只怪物，需策略性弹药管理
#   - 波 15 预算 773 → 大量精英堆叠，高手能撑但难以存活
# 奖励 = cost（金币=经验同值），单波收益约为 budget 的 1.0 倍。
# 弹药经济：初始备弹槽 100 发（13 次换弹 × 8 发弹匣）足够清前 2 波；
#           宝箱武器掉落（低档 60% 权重）不跳过经济系统；
#           高稀有度弹种（狙击/榴弹）需策略性购买。
# 耐久：blaster 120 / blaster-repeater 100，激励多枪轮换；
#       耐久归零爆枪频率适中（非每波必爆、非一把枪通关）。
const ENEMY_CONFIG: Dictionary = {
	&"monster_melee": {
		"cost": 5, "reward": 500, "min_wave": 1,
		"scene": preload("res://objects/monster_melee.tscn"),
	},
	&"monster_ranged": {
		"cost": 8, "reward": 800, "min_wave": 4,
		"scene": preload("res://objects/monster_ranged.tscn"),
	},
	&"enemy": {
		"cost": 10, "reward": 1000, "min_wave": 7,
		"scene": preload("res://objects/enemy.tscn"),
	},
	# === 以下 13 条目为 ADR 022 完整花名册（issues 16–19 待实施）===
	# 待对应 .tscn 场景创建后，逐条取消注释即可激活。
	# 波次解锁规则：1–3(近战基础) → 4–6(+远程基础) → 7–9(+中档) → 10–12(+重装) → 13+(+精英)
	#
	# 波次 1–3：基础近战 + 远程 + 骚扰
	# &"普通女": {
	# 	"cost": 5, "reward": 500, "min_wave": 1,
	# 	"scene": preload("res://objects/enemy_normal_female.tscn"),
	# },
	# &"普通黑女": {
	# 	"cost": 5, "reward": 500, "min_wave": 1,
	# 	"scene": preload("res://objects/enemy_normal_black_female.tscn"),
	# },
	# &"游戏宅": {
	# 	"cost": 8, "reward": 800, "min_wave": 1,
	# 	"scene": preload("res://objects/enemy_gamer.tscn"),
	# },
	#
	# 波次 4–6：远程 + 控制 + 支援
	# &"警察": {
	# 	"cost": 6, "reward": 600, "min_wave": 4,
	# 	"scene": preload("res://objects/enemy_police.tscn"),
	# },
	# &"律师": {
	# 	"cost": 10, "reward": 1000, "min_wave": 4,
	# 	"scene": preload("res://objects/enemy_lawyer.tscn"),
	# },
	# &"日本艺妓": {
	# 	"cost": 10, "reward": 1000, "min_wave": 4,
	# 	"scene": preload("res://objects/enemy_geisha.tscn"),
	# },
	# &"研究员-老人": {
	# 	"cost": 12, "reward": 1200, "min_wave": 4,
	# 	"scene": preload("res://objects/enemy_researcher.tscn"),
	# },
	#
	# 波次 7–9：快枪 + 狙击 + 陷阱
	# &"牛仔": {
	# 	"cost": 12, "reward": 1200, "min_wave": 7,
	# 	"scene": preload("res://objects/enemy_cowboy.tscn"),
	# },
	# &"独眼牛仔": {
	# 	"cost": 14, "reward": 1400, "min_wave": 7,
	# 	"scene": preload("res://objects/enemy_one_eye_cowboy.tscn"),
	# },
	# &"猎人": {
	# 	"cost": 14, "reward": 1400, "min_wave": 7,
	# 	"scene": preload("res://objects/enemy_hunter.tscn"),
	# },
	# &"化学人": {
	# 	"cost": 15, "reward": 1500, "min_wave": 7,
	# 	"scene": preload("res://objects/enemy_chemist.tscn"),
	# },
	#
	# 波次 10–12：坦克 + 护盾 + 自爆
	# &"健壮男": {
	# 	"cost": 16, "reward": 1600, "min_wave": 10,
	# 	"scene": preload("res://objects/enemy_strong.tscn"),
	# },
	# &"机器人-男电": {
	# 	"cost": 18, "reward": 1800, "min_wave": 10,
	# 	"scene": preload("res://objects/enemy_robot_male.tscn"),
	# },
	# &"机器人-女心": {
	# 	"cost": 20, "reward": 2000, "min_wave": 10,
	# 	"scene": preload("res://objects/enemy_robot_female.tscn"),
	# },
	#
	# 波次 13+：精英
	# &"驯兽师": {
	# 	"cost": 22, "reward": 2200, "min_wave": 13,
	# 	"scene": preload("res://objects/enemy_tamer.tscn"),
	# },
	# &"忍者": {
	# 	"cost": 25, "reward": 2500, "min_wave": 13,
	# 	"scene": preload("res://objects/enemy_ninja.tscn"),
	# },
}

var _wave_active := false
var _wave_elapsed := 0.0
var _cleared_by_timeout := false
var _monster_scenes: Dictionary = {}
var _player: Node3D
# issue 05：升级流程状态——add_xp 跨阈值时置位，apply_upgrade 后清除
var _level_up_pending := false

# issue 05：升级池（6 项，id 与 apply 逻辑匹配）
# 加法类（flat）：max_health / shield_regen / move_speed / max_reserve
# 乘法类（百分比）：damage ×1.15、reload_time ×0.9
const UPGRADE_POOL := [
	{"id": &"max_health", "name": "+20 最大血量", "desc": "最大血量 +20，并立即回复 20 血"},
	{"id": &"shield_regen", "name": "+5 护盾恢复", "desc": "护盾恢复速率 +5/s"},
	{"id": &"damage", "name": "+15% 伤害", "desc": "伤害 ×1.15"},
	{"id": &"move_speed", "name": "+0.5 移动速度", "desc": "移动速度 +0.5"},
	{"id": &"max_reserve", "name": "+1 备弹上限", "desc": "每把枪备弹上限 +1"},
	{"id": &"reload_time", "name": "-10% 换弹时间", "desc": "换弹时间 ×0.9"},
	{"id": &"backpack_weight", "name": "+10 背包负重", "desc": "背包负重上限 +10"},
]

# issue 08：宝箱奖励池（6 项，即时结算，金币/经验按波次缩放）
# issue 24：追加 random_weapon 和 grenade_supply
const CHEST_REWARD_POOL := [
	{"id": &"gold_bonus", "name": "金币大礼包", "desc": "获得 (20+5×波数) 银币"},
	{"id": &"heal_x3", "name": "血包 ×3", "desc": "立即回复 75 点生命"},
	{"id": &"xp_bonus", "name": "经验大礼包", "desc": "获得 15+3×波数 经验"},
	{"id": &"ammo_refill", "name": "备弹补给", "desc": "所有武器备弹回满"},
	{"id": &"random_weapon", "name": "随机武器", "desc": "获得一把随机武器"},
	{"id": &"grenade_supply", "name": "手雷补给", "desc": "EMP+1、破片+1"},
]

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = rng_seed if rng_seed != 0 else Time.get_ticks_usec()

	_monster_scenes[&"monster_melee"] = monster_melee_scene
	_monster_scenes[&"monster_ranged"] = monster_ranged_scene
	_monster_scenes[&"enemy"] = enemy_scene

	# 自动收集出生点 / 怪物父节点（main.tscn 约定）
	if monsters_parent == null:
		var p := get_parent()
		if p:
			monsters_parent = p.get_node_or_null("Monsters")
	if spawn_points.is_empty():
		var sp_node := get_parent().get_node_or_null("SpawnPoints") if is_inside_tree() else null
		if sp_node:
			for c in sp_node.get_children():
				if c is Marker3D:
					spawn_points.append(c)

	# 监听玩家死亡 → game_over
	_player = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if _player and _player.has_signal("died"):
		_player.died.connect(_on_player_died)

# ============================================================
# 公共方法（issue 04 商店 / issue 08 宝箱 / issue 05 升级 调用）
# ============================================================

## 加铜币（同时累加 copper_earned_total 用于结算）
func add_copper(amount: int) -> void:
	copper += amount
	copper_earned_total += amount
	currency_changed.emit(copper)

## 扣铜币；不足返回 false 不扣
func spend_copper(cost: int) -> bool:
	if copper < cost:
		return false
	copper -= cost
	currency_changed.emit(copper)
	return true

## 格式化铜币为金银铜混合显示字符串
## 1 金 = 10000 铜，1 银 = 100 铜
func format_currency(amount: int = -1) -> String:
	var total := copper if amount < 0 else amount
	var abs_total: int = absi(total)
	@warning_ignore("integer_division")
	var g: int = abs_total / 10000
	@warning_ignore("integer_division")
	var s: int = (abs_total % 10000) / 100
	var c: int = abs_total % 100
	var parts: Array[String] = []
	if g > 0:
		parts.append("%d金" % g)
	if s > 0:
		parts.append("%d银" % s)
	if c > 0 or parts.is_empty():
		parts.append("%d铜" % c)
	var result := " ".join(parts)
	if total < 0:
		result = "-" + result
	return result

## 加经验；跨阈值触发升级（issue 05：暂停 → 弹三选一 → apply → 恢复）
## 一次跨多级只弹一次三选一、升 1 级；剩余 XP 留待下次跨阈值再触发（不连弹）
func add_xp(amount: int) -> void:
	xp += amount
	var threshold := xp_to_next(level)
	xp_changed.emit(xp, threshold)
	if xp >= threshold and not _level_up_pending:
		xp -= threshold
		level += 1
		_offer_level_up()

## issue 05：触发升级流程——暂停 + 抽 3 不重复 + 发 level_up_offered(choices)
## UI（level_up.gd）监听此信号展示三卡；玩家选 1 后调用 apply_upgrade(id)
func _offer_level_up() -> void:
	_level_up_pending = true
	# 若已暂停（如商店中），记录为已知边界——当前简单处理：仍暂停并覆盖
	# （死亡优先级最高，见 ADR 015；商店/升级互斥由各 UI 自行检查）
	if is_inside_tree():
		get_tree().paused = true
	var choices := _pick_upgrades(3)
	level_up_offered.emit(choices)
	# 若无 UI 接入（测试环境），choices 仍可被测试断言；apply_upgrade 由测试/UI 调用

## issue 08：从宝箱奖励池抽 count 个不重复项（用本局 rng）
func pick_chest_rewards(count: int = 3) -> Array:
	var pool: Array = CHEST_REWARD_POOL.duplicate(true)
	_shuffle_in_place(pool)
	return pool.slice(0, mini(count, pool.size()))

## issue 08：应用宝箱奖励——由 chest_reward_selected 信号触发
func apply_chest_reward(reward_id: StringName) -> void:
	match reward_id:
		&"gold_bonus":
			var gold_bonus := (20 + 5 * wave) * 100
			add_copper(gold_bonus)
		&"heal_x3":
			if _player and is_instance_valid(_player) and _player.has_method("heal"):
				_player.heal(75)
		&"xp_bonus":
			var xp_bonus := 15 + 3 * wave
			add_xp(xp_bonus)  # 可能级联触发升级（issue 05）
		&"ammo_refill":
			if _player and is_instance_valid(_player):
				# 各弹种向背包补充一个弹匣量的弹药
				for i in range(_player.weapons.size()):
					var w: Weapon = _player.weapons[i]
					var key: StringName = w.ammo_type
					var weight_per_unit: float = _player.ITEM_WEIGHTS.get(key, 0.01)
					# 尝试添加一个弹匣量，背包满了跳过
					_player.backpack_add(key, &"ammo", w.magazine_size, weight_per_unit)
				if _player.has_method("_emit_ammo_updated"):
					_player._emit_ammo_updated()
		&"random_weapon":
			_apply_random_weapon_reward()
		&"grenade_supply":
			_apply_grenade_supply_reward()

## issue 05：从升级池抽 count 个不重复项（用本局 rng 打乱取前 N）
func _pick_upgrades(count: int) -> Array:
	var pool: Array = UPGRADE_POOL.duplicate(true)
	_shuffle_in_place(pool)
	return pool.slice(0, mini(count, pool.size()))

## issue 05：应用玩家选择的升级——由 Level Up UI 调用
## apply 后解除暂停、清 pending 标志、刷新 xp_changed（阈值已变）
func apply_upgrade(upgrade_id: StringName) -> void:
	if not _level_up_pending:
		return
	_apply_upgrade_to_player(upgrade_id)
	_level_up_pending = false
	if is_inside_tree() and get_tree().paused:
		get_tree().paused = false
	var threshold := xp_to_next(level)
	xp_changed.emit(xp, threshold)

## issue 05：把升级效果 apply 到 Player 的 bonus 字段
## 加法类线性叠加，乘法类乘法叠加（拿 3 次 +15% 伤害 = ×1.15³）
func _apply_upgrade_to_player(upgrade_id: StringName) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	match upgrade_id:
		&"max_health":
			_player.max_health += 20
			_player.health = min(_player.health + 20, _player.max_health)
			if _player.has_signal("health_updated"):
				_player.health_updated.emit(_player.health)
		&"shield_regen":
			_player.shield_regen_rate += 5.0
		&"damage":
			_player.damage_multiplier *= 1.15
		&"move_speed":
			_player.move_speed_bonus += 0.5
		&"max_reserve":
			_player.bonus_max_reserve += 1
		&"reload_time":
			_player.reload_time_multiplier *= 0.9
		&"backpack_weight":
			_player.backpack_max_weight += 10.0

## 加击杀计数
func add_kills(count: int = 1) -> void:
	kills += count
	kills_changed.emit(kills)

## 升级到下一级所需 XP（首级 20，之后 ×1.3）
func xp_to_next(lvl: int) -> int:
	return int(round(20.0 * pow(1.3, lvl - 1)))

# ============================================================
# 波次
# ============================================================

## 玩家手动开下一波（start_wave 输入动作触发）
func start_next_wave() -> void:
	if _wave_active:
		return
	if get_tree().paused:
		return  # 商店/升级/死亡暂停期间不开波
	wave += 1
	_wave_active = true
	_wave_elapsed = 0.0
	_cleared_by_timeout = false
	var types := compute_wave_composition(wave)
	alive_count = types.size()
	_spawn_all(types)
	wave_started.emit(wave)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("start_wave"):
		start_next_wave()

## 第 N 波的分数预算：60 × 1.2^(N-1)，即每波预算为上一波的 1.2 倍
func wave_budget(wave_number: int) -> int:
	return int(round(60.0 * pow(1.2, wave_number - 1)))

## 当前波次可用的怪物类型（issue 09：由 ENEMY_CONFIG 的 min_wave 驱动，
## 与旧规则一致：1–3 仅近战、4–6 加远程、7+ 全类型）
func _available_types(wave_number: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for type in ENEMY_CONFIG:
		if wave_number >= int(ENEMY_CONFIG[type]["min_wave"]):
			out.append(type)
	return out

## 分数制波次组成：从可用类型中随机选取怪物，直到总成本 >= 波次预算
## 使用本局 rng 保证测试可复现（固定 rng_seed）
func compute_wave_composition(wave_number: int) -> Array[StringName]:
	var budget := wave_budget(wave_number)
	var available := _available_types(wave_number)
	var types: Array[StringName] = []
	var total_cost := 0
	while total_cost < budget:
		var idx := rng.randi_range(0, available.size() - 1)
		var monster_type: StringName = available[idx]
		types.append(monster_type)
		total_cost += int(ENEMY_CONFIG[monster_type]["cost"])
	return types

func _spawn_all(types: Array[StringName]) -> void:
	var player_pos: Vector3 = _player.global_position if _player else Vector3.ZERO
	var positions := _find_spawn_positions(types.size(), player_pos)

	if not positions.is_empty():
		for i in types.size():
			_spawn_monster(types[i], positions[i], i)
		return

	# 兜底：NavMesh 选点失败，回退固定 SpawnPoints
	push_warning("RunDirector: NavMesh选点失败，回退固定出生点")
	if spawn_points.is_empty():
		push_warning("RunDirector: 无出生点，怪物将刷在原点")
	var pts: Array[Marker3D] = spawn_points.duplicate()
	_shuffle_in_place(pts)
	for i in types.size():
		var pos: Vector3
		if not pts.is_empty():
			var pt: Marker3D = pts[i % pts.size()]
			pos = pt.global_position
			if i >= pts.size():
				pos += Vector3(rng.randf_range(-2.0, 2.0), 0.0, rng.randf_range(-2.0, 2.0))
		else:
			pos = Vector3.ZERO
		_spawn_monster(types[i], pos, i)

func _shuffle_in_place(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func _spawn_monster(type: StringName, pos: Vector3, index: int = 0) -> Node3D:
	# 场景解析顺序：@export 注入（测试/过渡兼容）→ ENEMY_CONFIG 表（issue 09）
	var scene: PackedScene = _monster_scenes.get(type)
	if scene == null and ENEMY_CONFIG.has(type):
		scene = ENEMY_CONFIG[type]["scene"]
	if scene == null:
		push_warning("RunDirector: 未知怪物类型 %s" % str(type))
		return null
	var m: Node3D = scene.instantiate()
	# ADR 017：设置出生序号（用于错帧更新和战术散开）
	if m.has_method("set") and "spawn_index" in m:
		m.spawn_index = index
	monsters_parent.add_child(m)
	m.global_position = pos
	if m.has_signal("died"):
		# 绑定怪物实例以取死亡位置（掉血包用）
		m.died.connect(_on_monster_died.bind(m))
	return m

## 以玩家为中心在 NavMesh 上选刷怪点（近圈 15–30m，不足则远圈 30–60m）
## 返回空数组时调用方应回退固定 SpawnPoints
func _find_spawn_positions(count: int, player_pos: Vector3) -> Array[Vector3]:
	var world := monsters_parent.get_world_3d() if monsters_parent else null
	if world == null:
		return []

	var map_rid := world.navigation_map
	var space_state := world.direct_space_state

	# 近圈优先
	var near := _try_spawn_ring(count, player_pos, 15.0, 30.0, map_rid, space_state)
	if near.size() >= count:
		return near.slice(0, count)

	# 近圈不足，远圈补足
	var positions: Array[Vector3] = near.duplicate()
	var far := _try_spawn_ring(count - positions.size(), player_pos, 30.0, 60.0, map_rid, space_state)
	for p in far:
		positions.append(p)

	return positions

## 在环形区域内尝试选点（单圈），最多返回 count 个有效位置
func _try_spawn_ring(count: int, center: Vector3, min_radius: float, max_radius: float, map_rid: RID, space_state) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	const MAX_ATTEMPTS := 30

	for _slot in range(count):
		var found := false
		for _attempt in range(MAX_ATTEMPTS):
			var angle := rng.randf_range(0.0, TAU)
			var dist := rng.randf_range(min_radius, max_radius)
			var candidate := center + Vector3(cos(angle) * dist, center.y, sin(angle) * dist)

			# NavMesh 可达性
			var nav_point := NavigationServer3D.map_get_closest_point(map_rid, candidate)
			if nav_point.distance_to(candidate) > 5.0:
				continue

			candidate = nav_point

			# 向下 RayCast 验证地面
			var from_down := candidate + Vector3(0, 2.0, 0)
			var to_down := candidate + Vector3(0, -2.0, 0)
			var query_down := PhysicsRayQueryParameters3D.create(from_down, to_down)
			query_down.collision_mask = 1
			var hit_down: Dictionary = space_state.intersect_ray(query_down)
			if hit_down.is_empty():
				continue

			candidate.y = hit_down.position.y

			# 向上 RayCast 验证无天花板
			var from_up := candidate
			var to_up := candidate + Vector3(0, 5.0, 0)
			var query_up := PhysicsRayQueryParameters3D.create(from_up, to_up)
			query_up.collision_mask = 1
			var hit_up: Dictionary = space_state.intersect_ray(query_up)
			if not hit_up.is_empty():
				continue

			# 间距检查（≥ 3m）
			var too_close := false
			for existing in positions:
				var h_diff := candidate - existing
				h_diff.y = 0.0
				if h_diff.length() < 3.0:
					too_close = true
					break
			if too_close:
				continue

			positions.append(candidate)
			found = true
			break

		if not found:
			break

	return positions

## 怪物 died 信号处理：清场检测 + 奖励结算 + 血包掉落
func _on_monster_died(monster_type: StringName, monster: Node3D) -> void:
	alive_count = max(0, alive_count - 1)
	var reward := _reward_for(monster_type)
	add_copper(reward)
	add_xp(reward)
	add_kills(1)
	if monster and is_instance_valid(monster):
		_try_drop_health_pack(monster.global_position)
	if alive_count == 0 and _wave_active:
		_end_wave(_cleared_by_timeout)

func _reward_for(type: StringName) -> int:
	if ENEMY_CONFIG.has(type):
		return int(ENEMY_CONFIG[type]["reward"])
	return 0

func _end_wave(by_timeout: bool) -> void:
	_wave_active = false
	wave_cleared.emit(wave, by_timeout)
	_maybe_spawn_chest()
	_cleared_by_timeout = false

# ============================================================
# 卡怪兜底
# ============================================================

func _process(delta: float) -> void:
	if not _wave_active:
		return
	if get_tree().paused:
		return  # 暂停期间不倒计时
	_wave_elapsed += delta
	if _wave_elapsed >= wave_timeout:
		_force_clear_wave()

## 强制 destroy 场上剩余怪物（触发 died → 正常结算 + 清场）
func _force_clear_wave() -> void:
	if not _wave_active:
		return
	_cleared_by_timeout = true
	if monsters_parent == null:
		_end_wave(true)
		return
	for m in monsters_parent.get_children():
		if m is Node3D and m.has_method("destroy"):
			if not bool(m.get("_dead")):
				m.destroy()
	# 防御性兜底：若 destroy 后仍卡在 alive_count > 0（died 未触发等异常情况），直接收尾
	if _wave_active and alive_count > 0:
		alive_count = 0
		_end_wave(_cleared_by_timeout)

# ============================================================
# 血包掉落
# ============================================================

func _try_drop_health_pack(pos: Vector3) -> void:
	if rng.randf() >= health_pack_drop_chance:
		return
	var drop_pos := pos
	if drop_pos.y > 1.0:
		drop_pos = _project_to_ground(drop_pos)
	# 不堆叠：同位置 2m 内已有血包则跳过
	for p in get_tree().get_nodes_in_group("health_pack"):
		if is_instance_valid(p) and (p as Node3D).global_position.distance_to(drop_pos) < 2.0:
			return
	if health_pack_scene == null:
		return
	var pack: Node3D = health_pack_scene.instantiate()
	# 血包挂到 RunDirector 的父节点（Main）下，与怪物同级
	var parent_node: Node = get_parent()
	parent_node.add_child(pack)
	pack.global_position = drop_pos

func _project_to_ground(pos: Vector3) -> Vector3:
	if monsters_parent == null or monsters_parent.get_world_3d() == null:
		return Vector3(pos.x, 0.0, pos.z)
	var space := monsters_parent.get_world_3d().direct_space_state
	var from := Vector3(pos.x, pos.y + 1.0, pos.z)
	var to := Vector3(pos.x, -10.0, pos.z)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := space.intersect_ray(query)
	if hit and hit.has("position"):
		return Vector3(pos.x, hit.position.y, pos.z)
	return Vector3(pos.x, 0.0, pos.z)

# ============================================================
# 宝箱生成钩子（issue 08 接入）
# ============================================================

func _maybe_spawn_chest() -> void:
	if chest_scene == null:
		return  # issue 08 未接入
	# 场上已有未开宝箱则不重复生成
	for c in get_tree().get_nodes_in_group("chest"):
		if is_instance_valid(c):
			return
	var chest: Node3D = chest_scene.instantiate()
	get_parent().add_child(chest)
	# 位置：玩家前方 3m（玩家朝向），无玩家则场地中央
	if _player and is_instance_valid(_player):
		chest.global_position = _player.global_position + (_player.global_transform.basis.z * 3.0)
	else:
		chest.global_position = Vector3.ZERO
	# 连接宝箱 reward 信号（在 queue_free 前发射，确保 RunDirector 收到）
	if chest.has_signal("chest_reward_selected"):
		chest.chest_reward_selected.connect(_on_chest_reward_selected)

## issue 08：宝箱奖励选择处理——apply 奖励 + 转发信号（供测试与 HUD）
func _on_chest_reward_selected(reward_id: StringName) -> void:
	apply_chest_reward(reward_id)
	chest_reward_selected.emit(reward_id)

# ============================================================
# issue 24：宝箱奖励扩展 — 随机武器 + 手雷补给
# ============================================================

## 从 res://weapons/ 目录加载全部 .tres 武器，按稀有度加权随机抽取一把
## 低档（cost ≤ 70）：60% | 中档（71–120）：25% | 高档（>120）：15%
## 过滤已持有同款武器（issue 30 去重）
## 若玩家有空槽 → 直接装备（满耐久）
## 若 3 槽全满 → 发射 chest_weapon_replace_offered 信号，由 chest_ui 弹替换对话框
func _apply_random_weapon_reward() -> void:
	if _player == null or not is_instance_valid(_player):
		return

	var pool := WeaponUtils.load_all_weapons()
	if pool.is_empty():
		return

	# issue 30：过滤已持有同款武器（去重）
	# issue 24 spec 可选优化，提前实现——保留
	var owned_resources: Array = []
	for w in _player.weapons:
		if w != null:
			owned_resources.append(w)
	var filtered: Array = []
	for w in pool:
		if w not in owned_resources:
			filtered.append(w)
	if not filtered.is_empty():
		pool = filtered
	# 若全部已持有，仍从全池抽（降级，不做金币补偿）

	# 按 cost 分档加权（cost ÷ 10 为金币数）
	var low: Array = []
	var mid: Array = []
	var high: Array = []
	for w in pool:
		var cost_gold: int = w.weapon_cost / 10
		if cost_gold <= 7:
			low.append(w)
		elif cost_gold <= 12:
			mid.append(w)
		else:
			high.append(w)

	var chosen: Weapon = null
	var roll := rng.randf()
	if roll < 0.60:
		chosen = _pick_from_weighted(low)
	elif roll < 0.85:
		chosen = _pick_from_weighted(mid)
	else:
		chosen = _pick_from_weighted(high)

	if chosen == null:
		return

	# 有空槽 → 直接装备
	if _player.weapons.size() < _player.MAX_WEAPONS:
		_player.weapons.append(chosen)
		_player.magazine.append(chosen.magazine_size)
		_player.weapon_durability.append(chosen.durability_max)
		# 同时送一弹匣量弹药到背包
		var weight_per_unit: float = _player.ITEM_WEIGHTS.get(chosen.ammo_type, 0.01)
		_player.backpack_add(chosen.ammo_type, &"ammo", chosen.magazine_size, weight_per_unit)
		if _player.has_method("_emit_ammo_updated"):
			_player._emit_ammo_updated()
		if _player.weapon == null or _player.weapon_index < 0:
			_player.initiate_change_weapon(0)
		# 通知 chest_ui 奖励已完成（null = 无需替换）
		chest_weapon_replace_offered.emit(null)
	else:
		# 3 槽全满 → 发射替换信号，由 chest_ui 弹替换对话框
		_pending_replace_weapon = chosen
		chest_weapon_replace_offered.emit(chosen)

## 由 chest_ui 调用：确认替换宝箱武器到指定槽位
func confirm_chest_weapon_replace(slot_idx: int) -> void:
	if _pending_replace_weapon == null:
		return
	if _player == null or not is_instance_valid(_player):
		_pending_replace_weapon = null
		return
	if slot_idx < 0 or slot_idx >= _player.weapons.size():
		_pending_replace_weapon = null
		return

	var w: Weapon = _pending_replace_weapon
	_player.weapons[slot_idx] = w
	_player.weapon_durability[slot_idx] = w.durability_max
	_player.magazine[slot_idx] = w.magazine_size
	# 送一弹匣量弹药到背包
	var weight_per_unit: float = _player.ITEM_WEIGHTS.get(w.ammo_type, 0.01)
	_player.backpack_add(w.ammo_type, &"ammo", w.magazine_size, weight_per_unit)
	if _player.has_method("_emit_ammo_updated"):
		_player._emit_ammo_updated()
	_pending_replace_weapon = null

## 取消宝箱武器替换（玩家拒绝），做金币补偿（3 金 = 30000 铜）
func cancel_chest_weapon_replace() -> void:
	if _pending_replace_weapon != null:
		add_copper(30000)
		_pending_replace_weapon = null

## 返回当前各武器槽位名称列表（用于 chest_ui 渲染替换对话框）
## 返回 Array[String]：每槽返回武器 display_name，空槽返回 "（空）"
func get_weapon_slot_names() -> Array:
	var names: Array = []
	if _player == null or not is_instance_valid(_player):
		return names
	for i in range(_player.weapons.size()):
		var slot_w: Weapon = _player.weapons[i]
		names.append(slot_w.weapon_display_name if slot_w != null else "（空）")
	return names

## 手雷补给：EMP +1、破片 +1，上限 max_grenades（默认 5）
## 若两类均已到上限 → 补偿 30 金
func _apply_grenade_supply_reward() -> void:
	if _player == null or not is_instance_valid(_player):
		return

	var emp_key: StringName = &"emp"
	var frag_key: StringName = &"frag"
	var max_g: int = _player.max_grenades

	var emp_current: int = int(_player.grenades.get(emp_key, 0))
	var frag_current: int = int(_player.grenades.get(frag_key, 0))

	var emp_capped: bool = emp_current >= max_g
	var frag_capped: bool = frag_current >= max_g

	if emp_capped and frag_capped:
		add_copper(3000)
		return

	if not emp_capped:
		_player.grenades[emp_key] = mini(emp_current + 1, max_g)
	if not frag_capped:
		_player.grenades[frag_key] = mini(frag_current + 1, max_g)

## 从数组中等概率随机取一个元素（数组非空）
func _pick_from_weighted(arr: Array) -> Weapon:
	if arr.is_empty():
		return null
	return arr[rng.randi_range(0, arr.size() - 1)]

# ============================================================
# 玩家死亡 → 游戏结束
# ============================================================

func _on_player_died() -> void:
	# 暂停游戏（死亡优先级最高，接管其它暂停 UI）
	if is_inside_tree():
		get_tree().paused = true
	# 隐藏其它暂停 UI（shop/level-up），死亡优先级最高
	for n in get_tree().get_nodes_in_group("shop_ui"):
		if is_instance_valid(n):
			n.visible = false
	# LevelUp 挂在 HUD（CanvasLayer）下，HUD 是 RunDirector 的兄弟节点
	var hud_node := get_parent().get_node_or_null("HUD") if get_parent() else null
	if hud_node:
		var lu := hud_node.get_node_or_null("LevelUp")
		if lu:
			lu.visible = false
	var stats := {
		"wave": wave,
		"kills": kills,
		"copper_earned_total": copper_earned_total,
		"level": level,
	}
	game_over.emit(stats)
