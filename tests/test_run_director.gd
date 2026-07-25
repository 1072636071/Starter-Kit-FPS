## 竞技场 Issue 02 测试：RunDirector 波次/状态/奖励/清场/血包掉落
## 运行：godot --headless --path . res://tests/test_run_director.tscn --quit-after 600
extends Node3D

var failures: int = 0
var _counters: Dictionary = {}
var _wave_started: int = 0
var _wave_cleared: int = 0
var _last_cleared_by_timeout: bool = false

func _ready():
	call_deferred("_run_tests")

func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1

## 计算一组怪物类型的总成本（用于分数制波次测试）
func _total_cost(types: Array) -> int:
	const COST := {
		&"monster_melee": 5,
		&"monster_ranged": 8,
		&"enemy": 10,
	}
	var total := 0
	for t in types:
		total += COST.get(t, 0)
	return total

func _make_rd() -> Node:
	var rd := preload("res://scripts/run_director.gd").new()
	# 注入可控 rng_seed + 怪物父节点
	rd.rng_seed = 12345
	rd.monsters_parent = null  # 让 _ready 自动找（测试会手动设）
	return rd

func _run_tests() -> void:
	# === 1. 状态初值 + 金币公共方法 ===
	var rd := preload("res://scripts/run_director.gd").new()
	rd.rng_seed = 1
	rd.monsters_parent = self  # 直接挂测试根
	rd.spawn_points = []
	add_child(rd)
	_check(rd.gold == 0 and rd.xp == 0 and rd.level == 1 and rd.wave == 0 and rd.kills == 0,
		"initial state gold/xp/level/wave/kills = 0/0/1/0/0")
	rd.add_gold(100)
	_check(rd.gold == 100, "add_gold(100) → 100 (got %d)" % rd.gold)
	_check(rd.gold_earned_total == 100, "gold_earned_total tracks (got %d)" % rd.gold_earned_total)
	_check(rd.spend_gold(30) == true, "spend_gold(30) succeeds")
	_check(rd.gold == 70, "gold 70 after spend (got %d)" % rd.gold)
	_check(rd.spend_gold(1000) == false, "spend_gold(1000) fails (insufficient)")
	_check(rd.gold == 70, "gold unchanged on failed spend (got %d)" % rd.gold)

	# === 2. XP 阈值递增（首级 20，×1.3）===
	_check(rd.xp_to_next(1) == 20, "xp_to_next(1) == 20 (got %d)" % rd.xp_to_next(1))
	_check(rd.xp_to_next(2) == 26, "xp_to_next(2) == 26 (got %d)" % rd.xp_to_next(2))
	_check(rd.xp_to_next(3) == 34, "xp_to_next(3) == 34 (got %d)" % rd.xp_to_next(3))
	# 加 20 xp → 升级到 2
	# issue 05：add_xp 跨阈值会暂停游戏 + 发 level_up_offered；需 apply_upgrade 恢复
	_counters["levelup"] = 0
	rd.level_up_offered.connect(func(_c): _counters["levelup"] += 1)
	rd.add_xp(20)
	_check(rd.level == 2, "add_xp(20) → level 2 (got %d)" % rd.level)
	_check(int(_counters["levelup"]) == 1, "level_up_offered emitted once (got %d)" % int(_counters["levelup"]))
	_check(rd.xp == 0, "xp reset to 0 after level up (got %d)" % rd.xp)
	# apply 一个升级以解除暂停 + 清 pending（让后续测试不受暂停影响）
	rd.apply_upgrade(&"damage")
	_check(get_tree().paused == false, "game unpaused after apply_upgrade (issue 05 integration)")

	# === 3. 波次组成（分数制）===
	# 波 1：预算 60，仅 melee（cost=5）→ 恰好 12 只
	var w1 := rd.compute_wave_composition(1)
	_check(w1.size() == 12, "wave 1 count = 12 (got %d)" % w1.size())
	_check(w1.count(&"monster_melee") == 12 and w1.count(&"monster_ranged") == 0 and w1.count(&"enemy") == 0,
		"wave 1 all melee")
	# 波 4：预算 104，可用 melee + ranged；总成本 ≥ 预算，类型仅 melee/ranged
	var w4 := rd.compute_wave_composition(4)
	var w4_cost := _total_cost(w4)
	_check(w4_cost >= rd.wave_budget(4), "wave 4 cost %d >= budget %d" % [w4_cost, rd.wave_budget(4)])
	_check(w4.count(&"monster_melee") > 0 and w4.count(&"monster_ranged") > 0 and w4.count(&"enemy") == 0,
		"wave 4 melee+ranged only, no enemy (got melee=%d ranged=%d enemy=%d)" % [w4.count(&"monster_melee"), w4.count(&"monster_ranged"), w4.count(&"enemy")])
	# 波 7：预算 179，可用全部三种类型；总成本 ≥ 预算
	var w7 := rd.compute_wave_composition(7)
	var w7_cost := _total_cost(w7)
	_check(w7_cost >= rd.wave_budget(7), "wave 7 cost %d >= budget %d" % [w7_cost, rd.wave_budget(7)])
	_check(w7.count(&"monster_melee") > 0 and w7.count(&"monster_ranged") > 0 and w7.count(&"enemy") > 0,
		"wave 7 all three types present (got %d/%d/%d)" % [w7.count(&"monster_melee"), w7.count(&"monster_ranged"), w7.count(&"enemy")])

	# === 4. 奖励结算 + 血包掉落（用假怪物直接驱动 _on_monster_died）===
	rd.set("_wave_active", false)  # 不触发 wave_cleared
	rd.health_pack_drop_chance = 1.0  # 强制掉血包
	var fake_pos := Vector3(5, 0.5, 5)
	var fake_mon: Node3D = Node3D.new()
	add_child(fake_mon)
	fake_mon.global_position = fake_pos
	var gold_before := rd.gold
	rd.alive_count = 99
	rd._on_monster_died(&"monster_ranged", fake_mon)
	_check(rd.gold == gold_before + 8, "ranged reward +8 gold (got %d)" % (rd.gold - gold_before))
	_check(rd.kills == 1, "kills = 1 (got %d)" % rd.kills)
	# 血包已生成
	var packs1 := get_tree().get_nodes_in_group("health_pack")
	_check(packs1.size() == 1, "health pack dropped (got %d)" % packs1.size())
	# 同位置再次死亡 → 不堆叠
	var fake_mon2: Node3D = Node3D.new()
	add_child(fake_mon2)
	fake_mon2.global_position = fake_pos
	rd._on_monster_died(&"monster_melee", fake_mon2)
	var packs2 := get_tree().get_nodes_in_group("health_pack")
	_check(packs2.size() == 1, "no-stack: same position still 1 pack (got %d)" % packs2.size())
	# 不同位置 → 第 2 个血包
	var fake_mon3: Node3D = Node3D.new()
	add_child(fake_mon3)
	fake_mon3.global_position = fake_pos + Vector3(10, 0, 0)
	rd._on_monster_died(&"enemy", fake_mon3)
	var packs3 := get_tree().get_nodes_in_group("health_pack")
	_check(packs3.size() == 2, "different position → 2nd pack (got %d)" % packs3.size())
	# enemy 奖励 = 10
	_check(rd.gold == gold_before + 8 + 5 + 10, "rewards 8+5+10 (got %d)" % (rd.gold - gold_before))
	# 清理血包
	for p in packs3:
		p.queue_free()
	await get_tree().process_frame

	# === 5. 清场检测（alive_count → 0 触发 wave_cleared）===
	rd.set("_wave_active", true)
	rd.alive_count = 1
	rd.health_pack_drop_chance = 0.0  # 关掉掉落避免干扰
	_wave_cleared = 0
	rd.wave_cleared.connect(func(_w, by_t): _wave_cleared += 1; _last_cleared_by_timeout = by_t)
	var fake_clear: Node3D = Node3D.new()
	add_child(fake_clear)
	rd._on_monster_died(&"monster_melee", fake_clear)
	_check(_wave_cleared == 1, "wave_cleared emitted when alive_count hits 0 (got %d)" % _wave_cleared)
	_check(_last_cleared_by_timeout == false, "cleared_by_timeout = false on normal clear")
	_check(bool(rd.get("_wave_active")) == false, "_wave_active reset to false after clear")
	# issue 05 集成：_on_monster_died → add_xp 可能跨阈值触发升级暂停，需 apply 恢复
	if bool(rd.get("_level_up_pending")):
		rd.apply_upgrade(&"damage")
	_check(get_tree().paused == false, "game unpaused before test 6 (issue 05 cleanup)")

	# === 6. 集成：start_next_wave 真实刷怪 + 击杀清场 ===
	# 新建一个独立 RunDirector，挂真实怪物父节点 + 出生点
	var rd2 := preload("res://scripts/run_director.gd").new()
	rd2.rng_seed = 999
	var monsters_parent := Node3D.new()
	add_child(monsters_parent)
	rd2.monsters_parent = monsters_parent
	var pts: Array[Marker3D] = []
	for i in 3:
		var m := Marker3D.new()
		add_child(m)
		m.global_position = Vector3(i * 4.0, 0.5, 0)
		pts.append(m)
	rd2.spawn_points = pts
	add_child(rd2)
	_wave_started = 0
	rd2.wave_started.connect(func(_w): _wave_started += 1)
	_wave_cleared = 0
	rd2.wave_cleared.connect(func(_w, _t): _wave_cleared += 1)
	rd2.start_next_wave()
	_check(_wave_started == 1, "wave_started emitted (got %d)" % _wave_started)
	_check(rd2.wave == 1, "wave == 1 (got %d)" % rd2.wave)
	_check(rd2.alive_count == 12, "alive_count == 12 after wave 1 start (got %d)" % rd2.alive_count)
	_check(monsters_parent.get_child_count() == 12, "12 monsters spawned (got %d)" % monsters_parent.get_child_count())
	# 杀光所有怪物
	var gold_pre := rd2.gold
	for m in monsters_parent.get_children():
		if m.has_method("damage"):
			m.damage(99999.0)
	# 等一帧让 die 动画/延迟 queue_free 不影响断言（died 已同步发射）
	await get_tree().physics_frame
	_check(_wave_cleared == 1, "wave_cleared after killing all (got %d)" % _wave_cleared)
	_check(rd2.gold == gold_pre + 12 * 5, "gold +60 from 12 melee kills (got %d)" % (rd2.gold - gold_pre))
	_check(rd2.kills == 12, "kills == 12 (got %d)" % rd2.kills)
	# issue 05 集成：12×5=60 XP 跨阈值触发升级暂停，需 apply 恢复
	if bool(rd2.get("_level_up_pending")):
		rd2.apply_upgrade(&"damage")
	_check(get_tree().paused == false, "game unpaused before test 7 (issue 05 cleanup)")

	# === 7. 卡怪兜底（wave_timeout 强制清场，cleared_by_timeout=true）===
	# 注意：GDScript lambda 按值捕获局部变量，故用 Dictionary（引用类型）计数。
	var rd3 := preload("res://scripts/run_director.gd").new()
	rd3.rng_seed = 7
	rd3.wave_timeout = 0.2
	var mp3 := Node3D.new()
	add_child(mp3)
	rd3.monsters_parent = mp3
	var pts3: Array[Marker3D] = []
	var sp := Marker3D.new()
	add_child(sp)
	sp.global_position = Vector3(0, 0.5, 0)
	pts3.append(sp)
	rd3.spawn_points = pts3
	add_child(rd3)
	# 用 Dictionary 计数避免 lambda 局部变量按值捕获问题（见 test_arena_shield.gd 同类注释）
	_counters["timeout_cleared"] = 0
	_counters["by_timeout"] = false
	rd3.wave_cleared.connect(func(_w, t: bool):
		_counters["timeout_cleared"] = int(_counters["timeout_cleared"]) + 1
		_counters["by_timeout"] = t)
	rd3.start_next_wave()
	_check(rd3.alive_count == 12, "rd3 wave1 alive=12 (got %d)" % rd3.alive_count)
	# 等超过 wave_timeout（0.2s）→ 强制清场
	await get_tree().create_timer(0.6).timeout
	_check(int(_counters["timeout_cleared"]) == 1, "wave_cleared on timeout (got %d)" % int(_counters["timeout_cleared"]))
	_check(bool(_counters["by_timeout"]) == true, "cleared_by_timeout = true (got %s)" % str(_counters["by_timeout"]))

	if failures == 0:
		print("[TEST] PASS — arena issue 02 RunDirector")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
