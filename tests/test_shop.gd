## 竞技场 Issue 04 测试：子弹商店摊位（walk-in 暂停 + 购买扣金币加备弹封顶 + 降级）
## 运行：godot --headless --path . res://tests/test_shop.tscn --quit-after 600
extends Node3D

var failures: int = 0
var _shop_closed_count: int = 0

func _ready():
	call_deferred("_run_tests")

func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1

func _run_tests() -> void:
	# === 1. Weapon 资源：gold_cost_per_bullet 字段 + .tres backfill ===
	var weapon_script := preload("res://scripts/weapon.gd")
	var w := Weapon.new()
	_check(int(w.get("gold_cost_per_bullet")) == 1, "Weapon.gold_cost_per_bullet default 1 (got %d)" % int(w.get("gold_cost_per_bullet")))

	var blaster := load("res://weapons/blaster.tres")
	_check(int(blaster.get("gold_cost_per_bullet")) == 1, "blaster.tres gold_cost_per_bullet == 1 (got %d)" % int(blaster.get("gold_cost_per_bullet")))
	var repeater := load("res://weapons/blaster-repeater.tres")
	_check(int(repeater.get("gold_cost_per_bullet")) == 2, "blaster-repeater.tres gold_cost_per_bullet == 2 (got %d)" % int(repeater.get("gold_cost_per_bullet")))

	# === 2. 准备 player + run_director + shop_ui ===
	var player_scene := preload("res://objects/player.tscn")
	var player: CharacterBody3D = player_scene.instantiate()
	player.add_to_group("player")
	add_child(player)
	# 把 blaster 备弹清零，方便观察购买增量
	player.reserve[0] = 0
	player.reserve[1] = 0
	# 给玩家一些初始金币（通过 run_director.add_gold）
	var rd := preload("res://scripts/run_director.gd").new()
	rd.rng_seed = 42
	add_child(rd)
	rd.add_gold(100)
	_check(rd.gold == 100, "rd.gold == 100 after add_gold (got %d)" % rd.gold)

	var shop_ui_scene := preload("res://scenes/shop_ui.tscn")
	var shop_ui: Control = shop_ui_scene.instantiate()
	add_child(shop_ui)
	# open 前不可见
	_check(shop_ui.visible == false, "shop_ui hidden before open")
	shop_ui.open(player, rd)
	_check(shop_ui.visible == true, "shop_ui visible after open")
	_check(shop_ui.is_open() == true, "shop_ui.is_open == true after open")
	# 监听 closed 信号
	_shop_closed_count = 0
	shop_ui.closed.connect(func(): _shop_closed_count += 1)

	# === 3. 购买 +1（blaster 金价 1）===
	var gold_pre: int = rd.gold
	var bought: int = shop_ui.buy_bullets(0, 1)
	_check(bought == 1, "buy_bullets(0,1) returns 1 (got %d)" % bought)
	_check(rd.gold == gold_pre - 1, "gold -1 after buying 1 blaster bullet (got %d)" % rd.gold)
	_check(player.reserve[0] == 1, "reserve[0] +1 (got %d)" % player.reserve[0])

	# === 4. 购买 +10 但金币不足 → 降级到买得起的数量 ===
	# repeater 金价 2，rd.gold=99，最多买 49 发（99/2=49）
	gold_pre = rd.gold
	var max_affordable: int = gold_pre / 2
	bought = shop_ui.buy_bullets(1, 10)
	# 10 < 49，所以买满 10 发
	_check(bought == 10, "buy_bullets(1,10) returns 10 (gold enough, got %d)" % bought)
	_check(rd.gold == gold_pre - 10 * 2, "gold -20 after 10 repeater bullets (got %d)" % rd.gold)
	_check(player.reserve[1] == 10, "reserve[1] +10 (got %d)" % player.reserve[1])

	# === 5. 买满（repeater max_reserve=96，bonus=0，effective=96；当前 10，headroom=86）===
	# 需 86×2=172 金币才买满，当前 gold=79 不足 → 先补金
	rd.add_gold(100)
	_check(rd.gold == 179, "rd.gold == 179 after +100 (got %d)" % rd.gold)
	bought = shop_ui.buy_bullets(1, 9999)
	_check(bought == 86, "buy_max repeater returns 86 (headroom, got %d)" % bought)
	_check(player.reserve[1] == 96, "reserve[1] == 96 (effective max, got %d)" % player.reserve[1])
	_check(shop_ui.is_full(1) == true, "is_full(1) == true after buy_max")

	# === 6. 已满时 buy_bullets 返回 0 ===
	bought = shop_ui.buy_bullets(1, 1)
	_check(bought == 0, "buy_bullets(1,1) returns 0 when full (got %d)" % bought)

	# === 7. 金币不足 1 发时 can_afford false ===
	# 先把金币清零再测 can_afford（不真的扣）
	var gold_saved: int = rd.gold
	rd.spend_gold(rd.gold)  # 清空
	_check(rd.gold == 0, "gold drained to 0 (got %d)" % rd.gold)
	_check(bool(shop_ui.can_afford(0, 1)) == false, "can_afford(0,1) false when gold==0")
	# blaster 当前 reserve[0]=1，未满，但金币不足 → buy 返回 0
	bought = shop_ui.buy_bullets(0, 1)
	_check(bought == 0, "buy_bullets(0,1) returns 0 when gold insufficient (got %d)" % bought)
	_check(player.reserve[0] == 1, "reserve[0] unchanged when gold insufficient (got %d)" % player.reserve[0])
	# 恢复金币继续后续测试
	rd.add_gold(gold_saved)

	# === 8. effective_max_reserve 受 bonus_max_reserve 影响（issue 05 集成）===
	# blaster max_reserve=40，bonus_max_reserve=0，effective=40
	_check(shop_ui.effective_cap(0) == 40, "blaster effective_cap == 40 (got %d)" % shop_ui.effective_cap(0))
	player.bonus_max_reserve = 5
	_check(shop_ui.effective_cap(0) == 45, "blaster effective_cap == 45 with +5 bonus (got %d)" % shop_ui.effective_cap(0))
	player.bonus_max_reserve = 0  # 复位

	# === 9. close() 隐藏 + 鼠标捕获 + 发 closed 信号 ===
	shop_ui.close()
	_check(shop_ui.visible == false, "shop_ui hidden after close")
	_check(shop_ui.is_open() == false, "shop_ui.is_open == false after close")
	_check(_shop_closed_count == 1, "closed signal emitted once (got %d)" % _shop_closed_count)

	# 清理 shop_ui / player / rd
	shop_ui.queue_free()
	player.queue_free()
	rd.queue_free()
	await get_tree().process_frame

	# === 10. ShopStation Area3D：body_entered → 暂停 + 开 UI；body_exited → 恢复 + 关 UI ===
	# 重新搭一套真实 player + rd + shop_ui + shop_station
	var player2: CharacterBody3D = player_scene.instantiate()
	player2.add_to_group("player")
	add_child(player2)
	player2.reserve[0] = 0

	var rd2 := preload("res://scripts/run_director.gd").new()
	rd2.rng_seed = 7
	add_child(rd2)
	rd2.add_gold(50)

	var shop_ui2: Control = shop_ui_scene.instantiate()
	add_child(shop_ui2)
	_check(shop_ui2.visible == false, "shop_ui2 hidden initially")

	var shop_station: Area3D = preload("res://scenes/shop.tscn").instantiate()
	add_child(shop_station)
	shop_station.global_position = Vector3(100, 0.5, 100)  # 远离 origin，避免误触发
	# 把 shop_ui2 注入 shop_station（生产环境通过 group 查找，测试直接注入）
	shop_station.set_shop_ui(shop_ui2)
	shop_station.set_run_director(rd2)

	# 把玩家移入触发区
	player2.global_position = shop_station.global_position
	# 等物理帧让 Area3D 检测 body_entered
	for i in 5:
		await get_tree().physics_frame
	_check(get_tree().paused == true, "game paused after player walks into shop station")
	_check(shop_ui2.is_open() == true, "shop_ui2 opened by station")
	_check(shop_ui2.visible == true, "shop_ui2 visible after walk-in")

	# 在暂停态下买 5 发 blaster（金价 1，gold=50 够）
	bought = shop_ui2.buy_bullets(0, 5)
	_check(bought == 5, "bought 5 blaster bullets while paused (got %d)" % bought)
	_check(player2.reserve[0] == 5, "reserve[0] == 5 after paused purchase (got %d)" % player2.reserve[0])
	_check(rd2.gold == 45, "rd2.gold == 45 after 5 bullets (got %d)" % rd2.gold)

	# === 11. 关闭路径：ESC / 关闭按钮 / body_exited 都汇入 shop_ui.close() ===
	# 暂停期间物理冻结，玩家无法走动，故 body_exited 实际不会在暂停态触发；
	# 关闭主路径是 ESC/关闭按钮 → shop_ui.close() → emit closed → ShopStation 恢复暂停。
	# 这里直接调用 close() 模拟 ESC，验证恢复链路。
	shop_ui2.close()
	_check(get_tree().paused == false, "game unpaused after shop_ui.close() (ESC path)")
	_check(shop_ui2.is_open() == false, "shop_ui2 closed after close()")

	# === 11b. body_exited handler 直接调用（白盒测 handler 逻辑）===
	# 重新 walk-in 打开
	shop_station._on_body_entered(player2)
	_check(shop_ui2.is_open() == true, "shop_ui2 reopened by _on_body_entered (unpaused)")
	_check(get_tree().paused == true, "game paused again after reopen")
	# 调用 body_exited handler（模拟玩家走出，实际触发需非暂停态物理帧）
	shop_station._on_body_exited(player2)
	_check(shop_ui2.is_open() == false, "shop_ui2 closed by _on_body_exited handler")
	_check(get_tree().paused == false, "game unpaused after _on_body_exited handler")

	# === 12. 互斥：已暂停时 body_entered handler 不重复触发 ===
	get_tree().paused = true  # 模拟另一暂停源（如升级）
	shop_station._on_body_entered(player2)
	_check(shop_ui2.is_open() == false, "shop_ui2 NOT reopened when already paused (mutex)")
	get_tree().paused = false

	# 清理
	shop_station.queue_free()
	shop_ui2.queue_free()
	player2.queue_free()
	rd2.queue_free()
	await get_tree().process_frame

	if failures == 0:
		print("[TEST] PASS — arena issue 04 shop station")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
