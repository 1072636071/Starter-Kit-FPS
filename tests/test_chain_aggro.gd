## 连锁 Aggro 测试（issue 07）
## 运行：godot --headless --path . res://tests/test_chain_aggro.tscn --quit-after 1200
## 判定：[TEST] PASS 即通过；任何 [TEST] FAIL 即失败
extends Node

var failures: int = 0

func _ready():
	call_deferred("_run_tests")

func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1

## 提供一个在 "player" 组里的 Node3D
func _make_dummy_player(pos: Vector3 = Vector3(10, 0, 10)) -> Node3D:
	var p := Node3D.new()
	p.add_to_group("player")
	p.position = pos
	add_child(p)
	return p

## 创建一个地板 StaticBody3D（供怪物缓降着陆 + is_on_floor 判定）
func _make_floor() -> StaticBody3D:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1  # layer 1 = 地形
	floor_body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := WorldBoundaryShape3D.new()
	col.shape = shape
	floor_body.add_child(col)
	add_child(floor_body)
	return floor_body

## 跳过缓降：手动设置 _dropping=false 并放在地板上方，等几帧着陆
func _land_monster(m: CharacterBody3D) -> void:
	m.set("_dropping", false)
	m.position.y = 1.5  # 略高于地板（胶囊半高≈1.1），几帧内着陆
	for i in 30:
		await get_tree().physics_frame

func _run_tests() -> void:
	# 创建地板供所有怪物测试使用
	_make_floor()

	# 每次运行前清空 AlertSystem 缓存
	AlertSystem.clear()

	# === T1: AlertSystem emit_alert 后 has_alert_nearby 返回 true ===
	AlertSystem.clear()
	AlertSystem.emit_alert(Vector3(0, 0, 0), 30.0)
	_check(AlertSystem.has_alert_nearby(Vector3(5, 0, 5), 10.0),
		"T1: has_alert_nearby returns true after emit_alert (dist=7.07, alert=30, check=10)")

	# === T2: AlertSystem 过期后 has_alert_nearby 返回 false ===
	AlertSystem.clear()
	AlertSystem.emit_alert(Vector3(0, 0, 0), 30.0)
	# 等待 1.5s（远超 ALERT_LIFETIME=0.5s）
	await get_tree().create_timer(1.5).timeout
	_check(not AlertSystem.has_alert_nearby(Vector3(5, 0, 5), 10.0),
		"T2: has_alert_nearby returns false after alert expired")

	# === T9: awareness_range 默认值验证 ===
	AlertSystem.clear()
	var melee_scene := preload("res://objects/monster_melee.tscn")
	var ranged_scene := preload("res://objects/monster_ranged.tscn")
	var melee: CharacterBody3D = melee_scene.instantiate()
	add_child(melee)
	_check(abs(melee.get("awareness_range") - 16.0) < 0.01,
		"T9a: monster_melee awareness_range == 16.0 (got %f)" % float(melee.get("awareness_range")))

	var ranged: CharacterBody3D = ranged_scene.instantiate()
	add_child(ranged)
	_check(abs(ranged.get("awareness_range") - 24.0) < 0.01,
		"T9b: monster_ranged awareness_range == 24.0 (got %f)" % float(ranged.get("awareness_range")))

	# === T3: IDLE 怪物在 awareness_range 内 + 视线 → 转 CHASE（被动感知）===
	AlertSystem.clear()
	# ranged 怪 awareness=12m，把玩家放 10m 处（视野内无遮挡）
	var dummy_player := _make_dummy_player(Vector3(10, 0, 0))
	# 注入 player（ranged 在 T9 创建时无 player）
	ranged.set("player", dummy_player)
	# 着陆 + 等 _evaluate_transitions + _update_los 触发
	_land_monster(ranged)
	for i in 30:
		await get_tree().physics_frame
	_check(int(ranged.get("_ai_state")) == 1,
		"T3: monster_ranged IDLE→CHASE via passive perception (got state=%d)" % int(ranged.get("_ai_state")))
	ranged.queue_free()
	dummy_player.queue_free()
	# 清理 melee
	melee.queue_free()
	await get_tree().process_frame

	# === T4: IDLE 怪物在 awareness_range 外、chase_range 内，有 alert → 转 CHASE ===
	AlertSystem.clear()
	# 玩家远离怪物（避免被动感知触发）
	var dummy_player2 := _make_dummy_player(Vector3(100, 0, 100))
	var melee2: CharacterBody3D = melee_scene.instantiate()
	melee2.position = Vector3(0, 0, 0)
	add_child(melee2)
	_land_monster(melee2)
	# distance ≈ 141m，awareness=16m, chase=50m → 不应进入 CHASE
	for i in 30:
		await get_tree().physics_frame
	_check(int(melee2.get("_ai_state")) == 0,
		"T4a: monster IDLE without alert (state=%d, expected 0)" % int(melee2.get("_ai_state")))
	# 在怪物位置 emit alert（模拟远处枪声传过来）
	AlertSystem.emit_alert(Vector3(0, 0, 0), 30.0)
	for i in 30:
		await get_tree().physics_frame
	_check(int(melee2.get("_ai_state")) == 1,
		"T4b: monster IDLE→CHASE via alert propagation (state=%d, expected 1)" % int(melee2.get("_ai_state")))
	melee2.queue_free()
	dummy_player2.queue_free()
	await get_tree().process_frame

	# === T5: IDLE 怪物在 chase_range 外，有 alert 也不转 CHASE ===
	AlertSystem.clear()
	# 需要 far-away player 让 _evaluate_transitions 能运行
	var dummy_player_far := _make_dummy_player(Vector3(1000, 0, 1000))
	var melee3: CharacterBody3D = melee_scene.instantiate()
	melee3.position = Vector3(0, 0, 0)
	add_child(melee3)
	_land_monster(melee3)
	# 在 50m 处 emit alert（radius=30），怪物 chase_range=50
	# 50 > 30 (alert radius) AND 50 > 50 (chase_range) 不成立，但 50 > 30 (alert radius) 已阻断 → 不触发
	AlertSystem.emit_alert(Vector3(50, 0, 0), 30.0)
	for i in 30:
		await get_tree().physics_frame
	_check(int(melee3.get("_ai_state")) == 0,
		"T5: monster stays IDLE when alert out of range (state=%d, expected 0)" % int(melee3.get("_ai_state")))
	melee3.queue_free()
	dummy_player_far.queue_free()
	await get_tree().process_frame

	# === T6: 怪物死亡时触发 AlertSystem emit_alert ===
	AlertSystem.clear()
	var melee4: CharacterBody3D = melee_scene.instantiate()
	add_child(melee4)
	_land_monster(melee4)
	melee4.damage(9999.0)
	# 立即检查 alert 是否被发出（在怪物位置附近）
	_check(AlertSystem.has_alert_nearby(melee4.global_position, 20.0),
		"T6a: monster_melee death emits alert (20m radius)")
	melee4.queue_free()
	await get_tree().process_frame

	AlertSystem.clear()
	var ranged2: CharacterBody3D = ranged_scene.instantiate()
	add_child(ranged2)
	_land_monster(ranged2)
	ranged2.damage(9999.0)
	_check(AlertSystem.has_alert_nearby(ranged2.global_position, 20.0),
		"T6b: monster_ranged death emits alert (20m radius)")
	ranged2.queue_free()
	await get_tree().process_frame

	# === T7: 怪物远程开枪时触发 AlertSystem emit_alert ===
	AlertSystem.clear()
	var dummy_player3 := _make_dummy_player(Vector3(5, 0, 5))
	var ranged3: CharacterBody3D = ranged_scene.instantiate()
	add_child(ranged3)
	_land_monster(ranged3)
	# 调用 _fire_projectile（private 方法用 call）
	ranged3.call("_fire_projectile")
	_check(AlertSystem.has_alert_nearby(ranged3.global_position, 25.0),
		"T7: monster_ranged shoot emits alert (25m radius)")
	ranged3.queue_free()
	dummy_player3.queue_free()
	await get_tree().process_frame

	# === T8: 玩家开枪时触发 AlertSystem emit_alert ===
	# 验证 player.gd 中存在 SHOOT_ALERT_RADIUS 常量且为 30
	var player_scene := preload("res://objects/player.tscn")
	var player: CharacterBody3D = player_scene.instantiate()
	add_child(player)
	_check(float(player.get("SHOOT_ALERT_RADIUS")) == 60.0,
		"T8: player SHOOT_ALERT_RADIUS == 60.0 (got %f)" % float(player.get("SHOOT_ALERT_RADIUS")))
	player.queue_free()
	await get_tree().process_frame

	# === T10: 已进入 CHASE 的怪物在 alert 消失后不退回 IDLE ===
	AlertSystem.clear()
	# 需要一个 far-away dummy player 让 _evaluate_transitions 能运行
	var dummy_player4 := _make_dummy_player(Vector3(1000, 0, 1000))
	var melee5: CharacterBody3D = melee_scene.instantiate()
	melee5.position = Vector3(0, 0, 0)
	add_child(melee5)
	_land_monster(melee5)
	# 用 alert 触发 CHASE（玩家在 1000m 外，被动感知不触发）
	AlertSystem.emit_alert(Vector3(0, 0, 0), 30.0)
	for i in 30:
		await get_tree().physics_frame
	_check(int(melee5.get("_ai_state")) == 1,
		"T10a: monster entered CHASE via alert (state=%d)" % int(melee5.get("_ai_state")))
	# 等 alert 过期（ALERT_LIFETIME=0.5s），验证怪物不退回 IDLE
	await get_tree().create_timer(1.0).timeout
	# 状态应该不是 IDLE(0)：CHASE → LOST → 2s 后才回 IDLE，1s 内仍在追踪态
	var state_after := int(melee5.get("_ai_state"))
	_check(state_after != 0,
		"T10b: monster does NOT return to IDLE after alert expires (state=%d, expected !=0)" % state_after)
	melee5.queue_free()
	dummy_player4.queue_free()
	await get_tree().process_frame

	# 等一帧让延迟 queue_free 不报错
	await get_tree().process_frame

	if failures == 0:
		print("[TEST] PASS — chain aggro (issue 07)")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
