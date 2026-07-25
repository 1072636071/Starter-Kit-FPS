## 弹药池测试（issue 21）
## 运行：godot --headless --path . res://tests/test_ammo_pool.tscn --quit-after 30
extends Node3D

var player: CharacterBody3D
var hud: CanvasLayer
var failures: int = 0

const HUD_SCRIPT := preload("res://scripts/hud.gd")


func _ready():
	var player_scene = preload("res://objects/player.tscn")
	player = player_scene.instantiate()

	hud = CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(HUD_SCRIPT)
	add_child(hud)

	var crosshair = TextureRect.new()
	crosshair.name = "Crosshair"
	hud.add_child(crosshair)
	player.crosshair = crosshair

	add_child(player)
	call_deferred("_run_tests")


func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1


func _run_tests() -> void:
	var w0: Weapon = player.weapons[0]
	var w1: Weapon = player.weapons[1]

	# 两把武器同弹药类型（能量电池），共享 ammo_reserve 池
	_check(w0.ammo_type == w1.ammo_type,
		"both weapons share ammo type (got %s vs %s)" % [w0.ammo_type, w1.ammo_type])
	_check(player.get_reserve(w0) == player.get_reserve(w1),
		"shared pool: same reserve for both (got %d vs %d)" % [player.get_reserve(w0), player.get_reserve(w1)])

	# A 开枪 → ammo_reserve 减少
	var pool_before: int = player.get_reserve(w0)
	# 手动模拟消耗弹药池
	player.add_reserve(w0, -5)
	_check(player.get_reserve(w0) == pool_before - 5,
		"after A shoots, pool reduced (got %d, expected %d)" % [player.get_reserve(w0), pool_before - 5])
	# B 读同一池
	_check(player.get_reserve(w1) == pool_before - 5,
		"B sees same pool reduction (got %d)" % player.get_reserve(w1))

	# 弹药归零 → 无法射击 + 换弹后弹匣仍为 0
	player.ammo_reserve[w0.ammo_type] = 0
	player.magazine[0] = 0
	_check(player.get_reserve(w0) == 0, "pool drained to 0")
	# 换弹无效
	player.action_reload(0)
	_check(player.is_reloading == false, "empty pool → reload not started")
	_check(player.magazine[0] == 0, "magazine still 0 after failed reload (got %d)" % player.magazine[0])

	# ammo_reserve 变更时信号验证（通过 _emit_ammo_updated 间接触发）
	player.ammo_reserve[w0.ammo_type] = 10
	player._emit_ammo_updated()
	# 验证 reserves snapshot
	var snap := player.get_reserves_snapshot()
	_check(snap[0] == 10 and snap[1] == 10,
		"reserves snapshot reflects shared pool (got %s)" % str(snap))

	# get_reserve / add_reserve API
	_check(player.get_reserve(null) == 0, "get_reserve(null) returns 0")
	player.add_reserve(null, 10) # should not crash
	_check(true, "add_reserve(null, ...) does not crash")

	# effective_max_reserve
	var eff := player.effective_max_reserve(w0)
	_check(eff == w0.max_reserve, "effective_max_reserve = max_reserve (no bonus) (got %d)" % eff)

	if failures == 0:
		print("[TEST] PASS — ammo pool")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
