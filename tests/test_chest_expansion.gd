extends Node
## issue 24：宝箱奖励池扩展测试
##
## 验证 random_weapon 和 grenade_supply 两种新奖励类型。

var _run_director: Node
var _player: Node3D
var _mock_weapon: Resource

func before_each() -> void:
	# 构造 mock weapon 资源用于扫描
	_mock_weapon = Weapon.new()
	_mock_weapon.display_name = "测试枪"
	_mock_weapon.ammo_type = &"手枪弹"
	_mock_weapon.weapon_cost = 50
	_mock_weapon.durability_max = 100
	_mock_weapon.magazine_size = 12
	_mock_weapon.max_reserve = 48
	_mock_weapon.model = load("res://models/weapons/blaster.glb")
	_mock_weapon.cooldown = 0.25
	_mock_weapon.damage = 20.0

	# 构造 player
	_player = Node3D.new()
	_player.set_script(load("res://objects/player.gd"))
	# 只给 1 把武器（留 2 个空槽）
	_player.weapons = [_mock_weapon]
	_player.magazine = [_mock_weapon.magazine_size]
	_player.ammo_reserve = {&"手枪弹": 36}  # deprecated field, kept for compat
	# issue 08：设置背包弹药以便测试
	_player.backpack_items = {&"手枪弹": {"type": &"ammo", "count": 36, "weight_per_unit": 0.01}}
	_player.weapon_durability = [_mock_weapon.durability_max]
	_player.grenades = {&"emp": 1, &"frag": 0}
	_player.max_grenades = 5
	_player.weapon = _mock_weapon
	_player.weapon_index = 0
	# 初始化背包和备弹槽
	_player.reset_backpack()
	add_child(_player)

	# 构造 RunDirector
	_run_director = Node.new()
	_run_director.set_script(load("res://scripts/run_director.gd"))
	_run_director.rng_seed = 12345  # 固定种子可复现
	_run_director._ready()  # 初始化 rng
	_run_director._player = _player
	_run_director.wave = 5  # 设置波次供奖励计算
	_run_director.copper = 10000
	_run_director.copper_earned_total = 10000
	add_child(_run_director)


func after_each() -> void:
	if _player and is_instance_valid(_player):
		_player.queue_free()
	if _run_director and is_instance_valid(_run_director):
		_run_director.queue_free()


func test_chest_pool_contains_random_weapon() -> void:
	var pool: Array = _run_director.CHEST_REWARD_POOL
	var has_random_weapon := false
	var has_grenade_supply := false
	for entry in pool:
		if entry["id"] == &"random_weapon":
			has_random_weapon = true
		if entry["id"] == &"grenade_supply":
			has_grenade_supply = true
	assert_true(has_random_weapon, "宝箱奖励池应包含 random_weapon")
	assert_true(has_grenade_supply, "宝箱奖励池应包含 grenade_supply")


func test_pick_chest_rewards_includes_new_types() -> void:
	# 抽 6 次（等于池大小），应包含所有类型
	var all_rewards: Array = _run_director.pick_chest_rewards(6)
	assert_eq(all_rewards.size(), 6, "池应有 6 项")
	var ids: Array = []
	for r in all_rewards:
		ids.append(r["id"])
	assert_true(&"random_weapon" in ids, "抽奖应可能包含 random_weapon")
	assert_true(&"grenade_supply" in ids, "抽奖应可能包含 grenade_supply")


func test_random_weapon_reward_with_empty_slot() -> void:
	var initial_weapon_count := _player.weapons.size()
	# 应用 random_weapon 奖励（有空槽）
	_run_director._apply_random_weapon_reward()
	assert_gt(_player.weapons.size(), initial_weapon_count, "有空槽时应获得武器")


func test_random_weapon_reward_with_full_slots() -> void:
	# 填满 3 个槽
	while _player.weapons.size() < 3:
		var w := Weapon.new()
		w.display_name = "填充枪"
		w.ammo_type = &"手枪弹"
		w.weapon_cost = 30
		w.durability_max = 50
		w.magazine_size = 10
		w.max_reserve = 30
		w.model = load("res://models/weapons/blaster.glb")
		w.cooldown = 0.3
		w.damage = 15.0
		_player.weapons.append(w)
		_player.magazine.append(w.magazine_size)
		_player.weapon_durability.append(w.durability_max)

	var copper_before := _run_director.copper
	# 应用 random_weapon 奖励（满槽 → 触发 chest_weapon_replace_offered 信号）
	_run_director._apply_random_weapon_reward()
	assert_eq(_player.weapons.size(), 3, "满槽时不应添加武器")


func test_grenade_supply_reward() -> void:
	var emp_before := _player.grenades.get(&"emp", 0)
	var frag_before := _player.grenades.get(&"frag", 0)
	_run_director._apply_grenade_supply_reward()
	assert_eq(_player.grenades[&"emp"], mini(emp_before + 1, _player.max_grenades), "EMP 应 +1")
	assert_eq(_player.grenades[&"frag"], mini(frag_before + 1, _player.max_grenades), "破片应 +1")


func test_grenade_supply_at_cap_gives_gold() -> void:
	# 填满手雷到上限
	_player.grenades[&"emp"] = _player.max_grenades
	_player.grenades[&"frag"] = _player.max_grenades
	var copper_before := _run_director.copper
	_run_director._apply_grenade_supply_reward()
	assert_eq(_player.grenades[&"emp"], _player.max_grenades, "EMP 不应超上限")
	assert_eq(_player.grenades[&"frag"], _player.max_grenades, "破片不应超上限")
	assert_gt(_run_director.copper, copper_before, "全满时应获得金币补偿")
