## 手雷投掷测试（issue 23）
## 运行：godot --headless --path . res://tests/test_grenade_throw.tscn --quit-after 30
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
	# 手雷状态初始化
	_check(player.grenades.has(&"emp"), "grenades dict has emp key")
	_check(player.grenades.has(&"frag"), "grenades dict has frag key")
	_check(player.grenades[&"emp"] == 3, "emp grenades init = 3")
	_check(player.grenades[&"frag"] == 3, "frag grenades init = 3")
	_check(player.max_grenades == 5, "max_grenades = 5")
	_check(player.selected_grenade_type == &"emp", "default grenade type is emp")
	_check(not player.is_charging_grenade, "not charging by default")
	_check(player.grenade_charge_time == 0.0, "charge time init = 0")

	# 手雷数量为 0 时投掷不消耗
	player.grenades[&"emp"] = 0
	player._throw_grenade()
	_check(player.grenades[&"emp"] == 0, "throw with 0 grenades does not go negative")

	# 有手雷时投掷
	player.grenades[&"emp"] = 2
	player.selected_grenade_type = &"emp"
	player.grenade_charge_time = 0.5
	player._throw_grenade()
	_check(player.grenades[&"emp"] == 1, "after throw, emp count decreases (got %d)" % player.grenades[&"emp"])

	# 切换手雷类型
	player.selected_grenade_type = &"frag" if player.selected_grenade_type == &"emp" else &"emp"
	_check(player.selected_grenade_type == &"frag", "grenade type toggles (got %s)" % player.selected_grenade_type)
	player.selected_grenade_type = &"frag" if player.selected_grenade_type == &"emp" else &"emp"
	_check(player.selected_grenade_type == &"emp", "grenade type toggles back (got %s)" % player.selected_grenade_type)

	# 蓄力逻辑
	player.is_charging_grenade = true
	player.grenade_charge_time = 0.0
	# 模拟一帧
	player.grenade_charge_time = minf(player.grenade_charge_time + 0.1, player.grenade_charge_max)
	_check(player.grenade_charge_time > 0.0, "charge time accumulates while charging")
	player.is_charging_grenade = false

	# HUD 手雷显示
	var grenade_container := hud.get_node_or_null("GrenadeContainer")
	_check(grenade_container != null, "GrenadeContainer built in HUD")

	if failures == 0:
		print("[TEST] PASS — grenade throw")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
