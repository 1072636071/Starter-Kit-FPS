## 竞技场 Issue 01 测试：护盾吸收层 + 延时恢复 + died 信号
## 运行：godot --headless --path . res://tests/test_arena_shield.tscn --quit-after 600
## 判定：[TEST] PASS 即通过；任何 [TEST] FAIL 即失败（脚本自行 quit(1)）
extends Node

var failures: int = 0
# 用 Dictionary 计数器（引用类型，避免 GDScript lambda 局部变量捕获的语义问题）
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

	# === Player A：基础护盾吸收 + 溢出 ===
	var player: CharacterBody3D = player_scene.instantiate()
	add_child(player)

	# 1. @export 字段存在
	_check(player.get("shield_max") != null, "player has shield_max export")
	_check(player.get("shield_regen_delay") != null, "player has shield_regen_delay export")
	_check(player.get("shield_regen_rate") != null, "player has shield_regen_rate export")
	_check(player.get("max_health") != null, "player has max_health export (issue 03 API)")
	_check(player.has_method("heal"), "player has heal method (issue 03 API)")

	# 2. 护盾初值满
	var shield_max: float = float(player.get("shield_max"))
	_check(abs(float(player.get("shield")) - shield_max) < 0.01,
		"shield initial = shield_max (%f vs %f)" % [float(player.get("shield")), shield_max])

	# 3. 信号存在
	_check(player.has_signal("shield_updated"), "player has shield_updated signal")
	_check(player.has_signal("died"), "player has died signal")

	# 4. 损伤吸收：先扣护盾，不扣血
	var health_before: int = int(player.get("health"))
	player.damage(20.0)  # 20 < 50 shield
	_check(abs(float(player.get("shield")) - (shield_max - 20.0)) < 0.01,
		"shield absorbs 20 damage (shield now %f, expected %f)" % [float(player.get("shield")), shield_max - 20.0])
	_check(int(player.get("health")) == health_before,
		"health unchanged when shield absorbs (got %d, expected %d)" % [int(player.get("health")), health_before])

	# 5. 溢出扣血：护盾归零后溢出伤害扣 health
	player.damage(60.0)  # 30 absorbs remaining shield (50-20=30), 30 overflow
	_check(abs(float(player.get("shield"))) < 0.01,
		"shield reaches 0 after overflow (got %f)" % float(player.get("shield")))
	_check(int(player.get("health")) == health_before - 30,
		"overflow 30 damages health (got %d, expected %d)" % [int(player.get("health")), health_before - 30])

	# 6. shield_updated 信号被发射
	var player_b: CharacterBody3D = player_scene.instantiate()
	add_child(player_b)
	_counters["shield_updated"] = 0
	player_b.shield_updated.connect(func(_s, _m): _counters["shield_updated"] += 1)
	player_b.damage(10.0)
	_check(int(_counters["shield_updated"]) >= 1,
		"shield_updated emitted on damage (got %d)" % int(_counters["shield_updated"]))

	# === Player C：died 信号在 health <= 0 时发射一次 ===
	var player_c: CharacterBody3D = player_scene.instantiate()
	add_child(player_c)
	_counters["died"] = 0
	player_c.died.connect(func(): _counters["died"] += 1)
	# 默认 shield=50, health=100 → 总有效 HP = 150
	# damage(200.0) → shield 0, overflow 150, health = max(0, 100-150) = 0 → emit died
	player_c.damage(200.0)
	_check(int(_counters["died"]) == 1,
		"died emitted exactly once on lethal damage (got %d)" % int(_counters["died"]))
	_check(bool(player_c.get("_dead")) == true, "_dead guard set to true after death")
	# 再次伤害不应再触发 died
	player_c.damage(100.0)
	_check(int(_counters["died"]) == 1,
		"died NOT re-emitted on post-death damage (got %d)" % int(_counters["died"]))

	# === Player D：health 恰好到 0 边界（原 < 0 的 bug 已修） ===
	var player_d: CharacterBody3D = player_scene.instantiate()
	add_child(player_d)
	_counters["died_d"] = 0
	player_d.died.connect(func(): _counters["died_d"] += 1)
	# damage(150) → shield 0, overflow 100, health = max(0, 100-100) = 0 → emit died
	player_d.damage(150.0)
	_check(int(_counters["died_d"]) == 1,
		"died emitted when damage brings health to exactly 0 (got %d)" % int(_counters["died_d"]))

	# === Player E：heal 方法 ===
	var player_e: CharacterBody3D = player_scene.instantiate()
	add_child(player_e)
	# damage(80) → shield 0, overflow 30, health 70
	player_e.damage(80.0)
	_check(int(player_e.get("health")) == 70,
		"player_e health = 70 after 80 dmg (got %d)" % int(player_e.get("health")))
	var h_before_heal := int(player_e.get("health"))
	player_e.heal(20)
	_check(int(player_e.get("health")) == h_before_heal + 20,
		"heal adds 20 health (got %d, expected %d)" % [int(player_e.get("health")), h_before_heal + 20])
	# heal 不超过 max_health
	player_e.heal(1000)
	_check(int(player_e.get("health")) == int(player_e.get("max_health")),
		"heal capped at max_health (got %d, expected %d)" % [int(player_e.get("health")), int(player_e.get("max_health"))])

	# === Player F：死亡后 heal 不生效（_dead 守卫）===
	var player_f: CharacterBody3D = player_scene.instantiate()
	add_child(player_f)
	player_f.damage(200.0)  # kill
	var h_after_death := int(player_f.get("health"))
	player_f.heal(50)
	_check(int(player_f.get("health")) == h_after_death,
		"heal no-op when _dead (got %d, expected %d)" % [int(player_f.get("health")), h_after_death])

	# === Player G：受击后 shield regen delay 计时器重置 ===
	var player_g: CharacterBody3D = player_scene.instantiate()
	add_child(player_g)
	player_g.set("shield_regen_delay", 0.5)  # 测试用短 delay
	player_g.set("shield_regen_rate", 10.0)
	player_g.damage(20.0)  # shield 30
	# 推进 0.2s（未过 delay），shield 应不变
	await get_tree().create_timer(0.2).timeout
	_check(abs(float(player_g.get("shield")) - 30.0) < 0.5,
		"shield unchanged during regen delay (got %f, expected ~30)" % float(player_g.get("shield")))
	# 推进到过 delay（总共 0.8s > 0.5s delay），shield 应开始回
	await get_tree().create_timer(0.6).timeout
	_check(float(player_g.get("shield")) > 30.0,
		"shield regen started after delay (got %f, expected > 30)" % float(player_g.get("shield")))

	if failures == 0:
		print("[TEST] PASS — arena issue 01 shield layer + died signal")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
