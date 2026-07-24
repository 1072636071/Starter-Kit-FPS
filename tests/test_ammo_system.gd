## 弹药系统测试：验证 T1-T5 的核心状态机
## 运行：godot --headless --path . res://tests/test_ammo_system.tscn --quit-after 30
## 判定：看到 [TEST] PASS 即通过；任何 [TEST] FAIL 行即失败（exit 1 由脚本自行 quit(1)）
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

	# T2：初始弹药 = 满弹匣 + 满备弹
	_check(player.magazine.size() == 2, "magazine array size = 2 (got %d)" % player.magazine.size())
	_check(player.reserve.size() == 2, "reserve array size = 2 (got %d)" % player.reserve.size())
	_check(player.magazine[0] == 8, "blaster magazine init = 8 (got %d)" % player.magazine[0])
	_check(player.reserve[0] == 40, "blaster reserve init = 40 (got %d)" % player.reserve[0])
	_check(player.magazine[1] == 24, "repeater magazine init = 24 (got %d)" % player.magazine[1])

	# T2：手动扣减弹匣，模拟射击扣弹
	player.magazine[0] = 3
	player._emit_ammo_updated()
	_check(player.magazine[0] == 3, "after manual decrement blaster mag = 3 (got %d)" % player.magazine[0])

	# T4：手动换弹 —— 备弹足够时填满弹匣
	player.action_reload(0)
	_check(player.is_reloading == true, "action_reload sets is_reloading = true")
	_check(player.reload_index == 0, "reload_index = 0 (got %d)" % player.reload_index)
	# 推进 reload_time 时间
	var rt: float = w0.reload_time
	player._step_reload(rt + 0.01)
	_check(player.is_reloading == false, "after reload_time elapses, is_reloading = false")
	_check(player.magazine[0] == 8, "after reload blaster mag refilled to 8 (got %d)" % player.magazine[0])
	_check(player.reserve[0] == 35, "after reload blaster reserve = 35 (got %d)" % player.reserve[0])

	# T4：备弹不足时只装可用数
	player.magazine[0] = 5
	player.reserve[0] = 2
	player.action_reload(0)
	player._step_reload(w0.reload_time + 0.01)
	_check(player.magazine[0] == 7, "partial fill: mag = 5+2 = 7 (got %d)" % player.magazine[0])
	_check(player.reserve[0] == 0, "partial fill: reserve drained to 0 (got %d)" % player.reserve[0])

	# T4：弹匣已满不换弹
	player.magazine[0] = 8
	var reserve_before: int = player.reserve[0]
	player.action_reload(0)
	_check(player.is_reloading == false, "magazine full → reload not started")
	_check(player.reserve[0] == reserve_before, "magazine full → reserve unchanged")

	# T4：备弹为 0 不换弹
	player.magazine[0] = 0
	player.reserve[0] = 0
	player.action_reload(0)
	_check(player.is_reloading == false, "empty reserve → reload not started")

	# T4：切枪取消换弹（手动触发 reload，然后模拟 _cancel_reload）
	player.magazine[0] = 4
	player.reserve[0] = 4
	player.action_reload(0)
	_check(player.is_reloading == true, "reload started for cancel test")
	player._cancel_reload()
	_check(player.is_reloading == false, "after _cancel_reload is_reloading = false")
	_check(player.magazine[0] == 4, "cancelled reload does not transfer ammo (mag still 4, got %d)" % player.magazine[0])
	_check(player.reserve[0] == 4, "cancelled reload does not consume reserve (still 4, got %d)" % player.reserve[0])

	# T3/T4：HUD 渲染 —— AmmoList 已构建，且空弹显示「空」
	player.magazine[0] = 0
	player.reserve[0] = 0
	var list := hud.get_node_or_null("AmmoList")
	_check(list != null, "AmmoList built in HUD")
	if list:
		# 强制刷新一次（信号路径之外直接调用，确保状态一致）
		hud._on_ammo_updated(0, player.magazine.duplicate(), player.reserve.duplicate())
		# list children: [row0_vbox, row1_vbox] —— 每行 vbox 内 [labels_hbox, progress]
		var row0 = list.get_child(0) # row VBox
		var labels0 = row0.get_child(0) # labels HBox
		var ammo_label0 = labels0.get_child(1)
		_check(ammo_label0.text == "空", "empty weapon shows '空' (got %s)" % ammo_label0.text)
		# 第二把枪仍有弹药，应显示 "24 / 96"
		var row1 = list.get_child(1)
		var labels1 = row1.get_child(0)
		var ammo_label1 = labels1.get_child(1)
		_check(ammo_label1.text == "24 / 96", "repeater shows '24 / 96' (got %s)" % ammo_label1.text)

	# T5：reload_started 让当前武器行内显示进度条
	player.magazine[0] = 4
	player.reserve[0] = 4
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

	if failures == 0:
		print("[TEST] PASS — ammo system 5 tickets")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
