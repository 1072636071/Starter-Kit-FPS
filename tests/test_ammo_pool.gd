## 三层弹药流测试（issue 08 — 备弹系统三层统一重构）
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

	# ── 初始化验证：弹药在背包，槽位为空 ──
	_check(player.backpack_items.has(w0.ammo_type),
		"init: backpack has ammo type %s (got keys: %s)" % [w0.ammo_type, str(player.backpack_items.keys())])
	_check(player.backpack_items[w0.ammo_type]["count"] == 100,
		"init: backpack has 100 rounds (got %d)" % player.backpack_items[w0.ammo_type]["count"])
	_check(player.ammo_slots[0]["ammo_type"] == &"",
		"init: ammo_slots all empty after init")
	_check(player.get_reserve(w0) == 0,
		"init: get_reserve = 0 (no slots filled) (got %d)" % player.get_reserve(w0))

	# ── 手动填槽：模拟从背包分配到槽 ──
	var mag_size := w0.magazine_size
	player.ammo_slots[0] = {"ammo_type": w0.ammo_type, "remaining": 3, "capacity": mag_size}
	# 从背包扣除对应数量
	player.backpack_remove(w0.ammo_type, 3 * mag_size)

	# get_reserve 返回发数 = remaining × magazine_size
	_check(player.get_reserve(w0) == 3 * mag_size,
		"get_reserve returns bullet count (got %d, expected %d)" % [player.get_reserve(w0), 3 * mag_size])

	# 同弹种武器共享槽位
	_check(w0.ammo_type == w1.ammo_type,
		"both weapons share ammo type (got %s vs %s)" % [w0.ammo_type, w1.ammo_type])
	_check(player.get_reserve(w1) == 3 * mag_size,
		"same-type weapon sees same slot reserve (got %d)" % player.get_reserve(w1))

	# ── get_reserves_snapshot 返回发数 ──
	var snap := player.get_reserves_snapshot()
	_check(snap[0] == 3 * mag_size and snap[1] == 3 * mag_size,
		"reserves snapshot returns bullet counts (got %s)" % str(snap))

	# ── add_reserve 写入背包 ──
	var backpack_before: int = player.backpack_items[w0.ammo_type]["count"]
	player.add_reserve(w0, 10)
	_check(player.backpack_items[w0.ammo_type]["count"] == backpack_before + 10,
		"add_reserve writes to backpack (got %d, expected %d)" % [player.backpack_items[w0.ammo_type]["count"], backpack_before + 10])

	# ── 槽位空 = 无法换弹 ──
	# 清空所有槽
	for i in range(player.ammo_slots.size()):
		player.ammo_slots[i] = {"ammo_type": &"", "remaining": 0, "capacity": 0}
	player.magazine[0] = 0
	_check(player.get_reserve(w0) == 0, "empty slots → get_reserve = 0")
	player.action_reload(0)
	_check(player.is_reloading == false, "empty slots → reload not started")
	_check(player.magazine[0] == 0, "magazine still 0 after failed reload (got %d)" % player.magazine[0])

	# ── null 安全 ──
	_check(player.get_reserve(null) == 0, "get_reserve(null) returns 0")
	player.add_reserve(null, 10)
	_check(true, "add_reserve(null, ...) does not crash")

	# ── effective_max_reserve ──
	var eff := player.effective_max_reserve(w0)
	_check(eff == w0.max_reserve, "effective_max_reserve = max_reserve (no bonus) (got %d)" % eff)

	if failures == 0:
		print("[TEST] PASS — three-layer ammo flow")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)

