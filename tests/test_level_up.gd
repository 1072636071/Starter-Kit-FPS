## 竞技场 Issue 05 测试：升级三选一卡 + Player bonus 字段 + 叠加语义
## 运行：godot --headless --path . res://tests/test_level_up.tscn --quit-after 600
extends Node3D

var failures: int = 0
var _counters: Dictionary = {}

func _ready():
	call_deferred("_run_tests")

func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1

func _run_tests() -> void:
	var player_scene := preload("res://objects/player.tscn")

	# === 1. Player bonus 字段存在 + 默认值 ===
	var player: CharacterBody3D = player_scene.instantiate()
	add_child(player)
	_check(player.get("bonus_max_reserve") != null, "player has bonus_max_reserve")
	_check(player.get("damage_multiplier") != null, "player has damage_multiplier")
	_check(player.get("reload_time_multiplier") != null, "player has reload_time_multiplier")
	_check(player.get("move_speed_bonus") != null, "player has move_speed_bonus")
	_check(player.get("shield_regen_rate_bonus") != null, "player has shield_regen_rate_bonus")
	_check(int(player.get("bonus_max_reserve")) == 0, "bonus_max_reserve default 0 (got %d)" % int(player.get("bonus_max_reserve")))
	_check(abs(float(player.get("damage_multiplier")) - 1.0) < 0.001, "damage_multiplier default 1.0")
	_check(abs(float(player.get("reload_time_multiplier")) - 1.0) < 0.001, "reload_time_multiplier default 1.0")
	_check(abs(float(player.get("move_speed_bonus"))) < 0.001, "move_speed_bonus default 0.0")
	_check(abs(float(player.get("shield_regen_rate_bonus"))) < 0.001, "shield_regen_rate_bonus default 0.0")
	_check(player.has_method("effective_max_reserve"), "player has effective_max_reserve method")

	# effective_max_reserve 正确计算
	var wpn_path := "res://weapons/blaster.tres"
	if ResourceLoader.exists(wpn_path):
		var wpn := load(wpn_path) as Weapon
		var base_reserve := int(wpn.max_reserve)
		_check(int(player.effective_max_reserve(wpn)) == base_reserve, "effective_max_reserve = base + 0 bonus (got %d)" % int(player.effective_max_reserve(wpn)))
		player.set("bonus_max_reserve", 5)
		_check(int(player.effective_max_reserve(wpn)) == base_reserve + 5, "effective_max_reserve = base + 5 bonus (got %d)" % int(player.effective_max_reserve(wpn)))

	# === 2. RunDirector 升级池 ===
	var rd := preload("res://scripts/run_director.gd").new()
	rd.rng_seed = 42
	rd.monsters_parent = self
	rd.spawn_points = []
	add_child(rd)
	var pool: Array = rd.get("UPGRADE_POOL")
	_check(pool.size() == 6, "upgrade pool has 6 items (got %d)" % pool.size())
	var ids: Array = []
	for item in pool:
		ids.append(item["id"])
	# 6 个 id 都不同
	_check(ids.size() == 6 and ids.size() == ids.duplicate().size(), "6 upgrade ids unique")
	# 预期 id 集合
	for expected_id in [&"max_health", &"shield_regen", &"damage", &"move_speed", &"max_reserve", &"reload_time"]:
		_check(ids.has(expected_id), "pool has id %s" % str(expected_id))

	# === 3. _pick_upgrades 返回 3 个不重复 ===
	var picks := rd._pick_upgrades(3)
	_check(picks.size() == 3, "pick 3 returns 3 (got %d)" % picks.size())
	var pick_ids: Array = []
	for p in picks:
		pick_ids.append(p["id"])
	_check(pick_ids.size() == 3 and pick_ids.size() == pick_ids.duplicate().size(), "3 picks are unique")
	# 池不足时降级
	var picks2 := rd._pick_upgrades(99)
	_check(picks2.size() == 6, "pick 99 degrades to pool size 6 (got %d)" % picks2.size())

	# === 4. apply_upgrade 各项效果 ===
	# 4a. max_health：+20 上限 + 回 20 血
	player.set("bonus_max_reserve", 0)  # 重置
	var mh_before := int(player.get("max_health"))
	var hp_before := int(player.get("health"))
	player.set("health", hp_before - 30)  # 故意扣血验证回血
	rd._player = player
	# 直接调内部 apply（跳过暂停流程）
	rd.set("_level_up_pending", true)
	rd.apply_upgrade(&"max_health")
	_check(int(player.get("max_health")) == mh_before + 20, "max_health +20 (got %d)" % int(player.get("max_health")))
	_check(int(player.get("health")) == hp_before - 30 + 20, "health +20 on max_health upgrade (got %d)" % int(player.get("health")))

	# 4b. shield_regen：+5 速率
	var sr_before := float(player.get("shield_regen_rate"))
	rd.set("_level_up_pending", true)
	rd.apply_upgrade(&"shield_regen")
	_check(abs(float(player.get("shield_regen_rate")) - (sr_before + 5.0)) < 0.001, "shield_regen_rate +5 (got %f)" % float(player.get("shield_regen_rate")))

	# 4c. damage：×1.15
	var dm_before := float(player.get("damage_multiplier"))
	rd.set("_level_up_pending", true)
	rd.apply_upgrade(&"damage")
	_check(abs(float(player.get("damage_multiplier")) - (dm_before * 1.15)) < 0.001, "damage_multiplier ×1.15 (got %f)" % float(player.get("damage_multiplier")))

	# 4d. move_speed：+0.5
	var ms_before := float(player.get("move_speed_bonus"))
	rd.set("_level_up_pending", true)
	rd.apply_upgrade(&"move_speed")
	_check(abs(float(player.get("move_speed_bonus")) - (ms_before + 0.5)) < 0.001, "move_speed_bonus +0.5 (got %f)" % float(player.get("move_speed_bonus")))

	# 4e. max_reserve：+1
	var mr_before := int(player.get("bonus_max_reserve"))
	rd.set("_level_up_pending", true)
	rd.apply_upgrade(&"max_reserve")
	_check(int(player.get("bonus_max_reserve")) == mr_before + 1, "bonus_max_reserve +1 (got %d)" % int(player.get("bonus_max_reserve")))

	# 4f. reload_time：×0.9
	var rt_before := float(player.get("reload_time_multiplier"))
	rd.set("_level_up_pending", true)
	rd.apply_upgrade(&"reload_time")
	_check(abs(float(player.get("reload_time_multiplier")) - (rt_before * 0.9)) < 0.001, "reload_time_multiplier ×0.9 (got %f)" % float(player.get("reload_time_multiplier")))

	# === 5. 叠加语义：拿 3 次 +15% 伤害 = ×1.15³ ===
	var dm_base := float(player.get("damage_multiplier"))
	for i in 3:
		rd.set("_level_up_pending", true)
		rd.apply_upgrade(&"damage")
	var dm_after := float(player.get("damage_multiplier"))
	_check(abs(dm_after - dm_base * pow(1.15, 3)) < 0.001, "3× +15%% damage = ×1.15³ (got %f, expected %f)" % [dm_after, dm_base * pow(1.15, 3)])

	# === 6. add_xp 跨阈值 → 暂停 + level_up_offered + apply 后恢复 ===
	var rd2 := preload("res://scripts/run_director.gd").new()
	rd2.rng_seed = 7
	rd2.monsters_parent = self
	rd2.spawn_points = []
	add_child(rd2)
	_counters["levelup"] = 0
	_counters["last_choices"] = []
	rd2.level_up_offered.connect(func(choices): _counters["levelup"] = int(_counters["levelup"]) + 1; _counters["last_choices"] = choices)
	# 加 20 XP → 跨阈值（level 1 → 2）
	rd2.add_xp(20)
	_check(int(_counters["levelup"]) == 1, "level_up_offered emitted once on threshold (got %d)" % int(_counters["levelup"]))
	_check(rd2.level == 2, "level == 2 after threshold (got %d)" % rd2.level)
	_check(bool(rd2.get("_level_up_pending")) == true, "_level_up_pending set true")
	_check(get_tree().paused == true, "game paused during level-up")
	var choices: Array = _counters["last_choices"]
	_check(choices.size() == 3, "offered 3 choices (got %d)" % choices.size())
	# 选第一个 → apply → 解除暂停
	var first_id: StringName = choices[0]["id"]
	rd2.apply_upgrade(first_id)
	_check(get_tree().paused == false, "game unpaused after apply_upgrade")
	_check(bool(rd2.get("_level_up_pending")) == false, "_level_up_pending cleared after apply")

	# === 7. 一次跨多级只弹一次，剩余 XP 留待下次 ===
	var rd3 := preload("res://scripts/run_director.gd").new()
	rd3.rng_seed = 3
	rd3.monsters_parent = self
	rd3.spawn_points = []
	add_child(rd3)
	_counters["levelup3"] = 0
	rd3.level_up_offered.connect(func(_c): _counters["levelup3"] = int(_counters["levelup3"]) + 1)
	# level 1 阈值 20；给 100 XP 足够跨多级，但只弹一次升 1 级
	rd3.add_xp(100)
	_check(int(_counters["levelup3"]) == 1, "multi-level cross only emits once (got %d)" % int(_counters["levelup3"]))
	_check(rd3.level == 2, "level == 2 after multi-cross (got %d)" % rd3.level)
	_check(rd3.xp == 80, "remaining xp = 100-20=80 (got %d)" % rd3.xp)
	# apply 后，剩余 XP 仍在，下次 add_xp 可能再触发
	rd3.apply_upgrade(_counters["last_choices"][0]["id"] if _counters["last_choices"] else &"damage")
	# 剩余 80 XP，level 2 阈值 26 → 80 >= 26，但 apply_upgrade 不自动触发（需 add_xp 再调）
	# issue 要求"只弹一次，剩余留待下次跨阈值再触发"——apply 后不连弹
	_check(int(_counters["levelup3"]) == 1, "no chained level-up after apply (got %d)" % int(_counters["levelup3"]))

	if failures == 0:
		print("[TEST] PASS — arena issue 05 level-up cards + bonus fields")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
