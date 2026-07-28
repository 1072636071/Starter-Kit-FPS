## 弹药系统测试：验证 T1-T5 的核心状态机 + issue 08 三层弹药流
## 运行：godot --headless --path . res://tests/test_ammo_system.tscn --quit-after 30
## 判定：看到 [TEST] PASS 即通过；任何 [TEST] FAIL 行即失败（exit 1 由脚本自行 quit(1)）
## issue 08：三层弹药流 backpack_items → ammo_slots → magazine，ammo_reserve 已废弃
extends Node3D

var player: CharacterBody3D
var hud: CanvasLayer
var failures: int = 0

const HUD_SCRIPT := preload("res://scripts/hud.gd")

func _ready():
	var player_scene = preload("res://objects/player.tscn")
	player = player_scene.instantiate()

	# 实例化真正的 HUD（带 hud.gd 脚本），作为 Player 的兄弟节点
	# 这样 hud._bind_player 中的 "../Player" 才能解析到本测试根下的 Player
	hud = CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(HUD_SCRIPT)
	add_child(hud)

	# player.gd 需要 crosshair 引用
	var crosshair = TextureRect.new()
	crosshair.name = "Crosshair"
	hud.add_child(crosshair)
	player.crosshair = crosshair

	add_child(player)

	# 推迟一帧执行测试，让 hud 的 call_deferred("_bind_player") 先跑完
	call_deferred("_run_tests")

func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1

func _run_tests() -> void:
	# T1：武器资源已配置 4 个新字段
	var w0: Weapon = player.weapons[0]
	var w1: Weapon = player.weapons[1]
	_check(w0.display_name == "爆能枪", "blaster display_name = 爆能枪 (got %s)" % w0.display_name)
	_check(w0.magazine_size == 8, "blaster magazine_size = 8 (got %d)" % w0.magazine_size)
	_check(w0.max_reserve == 40, "blaster max_reserve = 40 (got %d)" % w0.max_reserve)
	_check(abs(w0.reload_time - 1.5) < 0.001, "blaster reload_time = 1.5 (got %f)" % w0.reload_time)
	_check(w1.display_name == "连发枪", "repeater display_name = 连发枪 (got %s)" % w1.display_name)
	_check(w1.magazine_size == 24, "repeater magazine_size = 24 (got %d)" % w1.magazine_size)

	# issue 09：两把武器均归属弹药类型「能量电池」（ADR 022）
	_check(w0.ammo_type == &"能量电池", "blaster ammo_type = 能量电池 (got %s)" % w0.ammo_type)
	_check(w1.ammo_type == &"能量电池", "repeater ammo_type = 能量电池 (got %s)" % w1.ammo_type)

	# T2（issue 08）：弹匣按武器独立；备弹走三层流（背包→槽→弹匣）
	_check(player.magazine.size() == 2, "magazine array size = 2 (got %d)" % player.magazine.size())
	_check(player.magazine[0] == 8, "blaster magazine init = 8 (got %d)" % player.magazine[0])
	_check(player.magazine[1] == 24, "repeater magazine init = 24 (got %d)" % player.magazine[1])
	# issue 08：初始弹药在背包，槽位为空
	_check(player.backpack_items.has(w0.ammo_type),
		"backpack has ammo type %s (got keys: %s)" % [w0.ammo_type, str(player.backpack_items.keys())])
	_check(player.backpack_items[w0.ammo_type]["count"] == 100,
		"backpack has 100 rounds init (got %d)" % player.backpack_items[w0.ammo_type]["count"])
	_check(player.get_reserve(w0) == 0,
		"get_reserve = 0 initially (slots empty) (got %d)" % player.get_reserve(w0))
	_check(player.get_reserves_snapshot() == [0, 0],
		"reserves snapshot = [0, 0] (slots empty) (got %s)" % str(player.get_reserves_snapshot()))

	# issue 09：武器耐久初始 = durability_max
	_check(player.weapon_durability.size() == 2, "weapon_durability size = 2 (got %d)" % player.weapon_durability.size())
	_check(player.weapon_durability[0] == w0.durability_max,
		"blaster durability init = durability_max %d (got %d)" % [w0.durability_max, player.weapon_durability[0]])

	# T4：手动换弹 —— 槽位有弹药时填满弹匣
	# 设置槽位：3 次换弹量（每次 = mag_size = 8 发）
	player.ammo_slots[0] = {"ammo_type": &"能量电池", "remaining": 3, "capacity": w0.magazine_size}
	player.magazine[0] = 3
	_check(player.get_reserve(w0) == 3 * w0.magazine_size,
		"get_reserve = 3 * mag_size = %d (got %d)" % [3 * w0.magazine_size, player.get_reserve(w0)])
	player.action_reload(0)
	_check(player.is_reloading == true, "action_reload sets is_reloading = true")
	_check(player.reload_index == 0, "reload_index = 0 (got %d)" % player.reload_index)
	# 推进 reload_time 时间
	var rt: float = w0.reload_time
	player._step_reload(rt + 0.01)
	_check(player.is_reloading == false, "after reload_time elapsed, is_reloading = false")
	_check(player.magazine[0] == 8, "after reload blaster mag refilled to 8 (got %d)" % player.magazine[0])
	_check(player.ammo_slots[0]["remaining"] == 2, "after reload slot remaining = 2 (got %d)" % player.ammo_slots[0]["remaining"])

	# T4：槽位空时不换弹
	for i in range(player.ammo_slots.size()):
		player.ammo_slots[i] = {"ammo_type": &"", "remaining": 0, "capacity": 0}
	player.magazine[0] = 0
	_check(player.get_reserve(w0) == 0, "empty slots → get_reserve = 0")
	player.action_reload(0)
	_check(player.is_reloading == false, "empty slots → reload not started")

	# T4：弹匣已满不换弹
	player.magazine[0] = 8
	player.ammo_slots[0] = {"ammo_type": &"能量电池", "remaining": 2, "capacity": w0.magazine_size}
	var reserve_before: int = player.get_reserve(w0)
	player.action_reload(0)
	_check(player.is_reloading == false, "magazine full → reload not started")
	_check(player.get_reserve(w0) == reserve_before, "magazine full → slots unchanged")

	# T4：槽位为 0 不换弹
	for i in range(player.ammo_slots.size()):
		player.ammo_slots[i] = {"ammo_type": &"", "remaining": 0, "capacity": 0}
	player.magazine[0] = 0
	player.action_reload(0)
	_check(player.is_reloading == false, "empty slots → reload not started")

	# T4：切枪取消换弹
	player.magazine[0] = 4
	player.ammo_slots[0] = {"ammo_type": &"能量电池", "remaining": 2, "capacity": w0.magazine_size}
	var slot_before: int = player.ammo_slots[0]["remaining"]
	player.action_reload(0)
	_check(player.is_reloading == true, "reload started for cancel test")
	player._cancel_reload()
	_check(player.is_reloading == false, "after _cancel_reload is_reloading = false")
	_check(player.magazine[0] == 4, "cancelled reload does not transfer ammo (mag still 4, got %d)" % player.magazine[0])
	_check(player.ammo_slots[0]["remaining"] == slot_before, "cancelled reload does not consume slot (still %d, got %d)" % [slot_before, player.ammo_slots[0]["remaining"]])

	# T3/T4：HUD 渲染 —— 空弹显示「空」
	for i in range(player.ammo_slots.size()):
		player.ammo_slots[i] = {"ammo_type": &"", "remaining": 0, "capacity": 0}
	player.magazine[0] = 0
	var list := hud.get_node_or_null("AmmoList")
	_check(list != null, "AmmoList built in HUD")
	if list:
		# 强制刷新一次
		hud._on_ammo_updated(0, player.magazine.duplicate(), player.get_reserves_snapshot())
		var row0 = list.get_child(0)
		var labels0 = row0.get_child(0)
		var ammo_label0 = labels0.get_child(1)
		_check(ammo_label0.text == "空", "empty weapon shows '空' (got %s)" % ammo_label0.text)
		# issue 08：两把枪共享能量电池槽位（全空），连发枪行显示 "24 / 0"
		var row1 = list.get_child(1)
		var labels1 = row1.get_child(0)
		var ammo_label1 = labels1.get_child(1)
		_check(ammo_label1.text == "24 / 0", "repeater shows '24 / 0' (got %s)" % ammo_label1.text)

	# T5：reload_started 让当前武器行内显示进度条
	player.magazine[0] = 4
	player.ammo_slots[0] = {"ammo_type": &"能量电池", "remaining": 2, "capacity": w0.magazine_size}
	player.action_reload(0)
	if list:
		var row0 = list.get_child(0)
		var progress0 = row0.get_child(1) # 进度条在行 vbox 内
		_check(progress0.visible == true, "reload_started shows progress bar inside current weapon row")
	player._cancel_reload()
	if list:
		var row0 = list.get_child(0)
		var progress0 = row0.get_child(1)
		_check(progress0.visible == false, "reload_ended hides progress bar")

	# issue 09：武器损毁 —— 移除数组项并自动切换
	var weapons_before: int = player.weapons.size()
	player._on_weapon_broken(0)
	_check(player.weapons.size() == weapons_before - 1, "broken weapon removed (size %d)" % player.weapons.size())
	_check(player.magazine.size() == weapons_before - 1, "magazine shrinks in sync (size %d)" % player.magazine.size())
	_check(player.weapon_durability.size() == weapons_before - 1,
		"weapon_durability shrinks in sync (size %d)" % player.weapon_durability.size())
	# initiate_change_weapon 立即更新 weapon_index；weapon 资源在切换 tween 后才换（0.15s）
	_check(player.weapon_index == 0 and player.weapons[0].display_name == "连发枪",
		"auto-switch to next weapon after break (index %d, %s)" % [player.weapon_index, player.weapons[0].display_name])

	# issue 09：最后一把损毁 → 空手状态
	player._on_weapon_broken(0)
	_check(player.weapons.is_empty(), "all weapons broken → empty")
	_check(player.weapon == null and player.weapon_index == -1, "unarmed: weapon=null, index=-1")

	if failures == 0:
		print("[TEST] PASS — ammo system 5 tickets + issue 08 three-layer ammo flow")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
