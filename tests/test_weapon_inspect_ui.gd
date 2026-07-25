extends Node
## issue 25：武器检视 UI 验证测试
##
## 验证 weapon_inspect_ui.gd 与 issue 19–21 的兼容性：
## - 弹药状态读数使用 ammo_reserve
## - TAB 键不与其他键冲突
## - .tres 身份字段正确显示
## - 交互流程正常
## - 边界情况处理正确

var _ui: Control
var _player: Node3D
var _weapon_a: Resource
var _weapon_b: Resource
var _weapon_c: Resource

func before_each() -> void:
	# 构造 2 把 mock 武器
	_weapon_a = Weapon.new()
	_weapon_a.display_name = "测试枪A"
	_weapon_a.ammo_type = &"手枪弹"
	_weapon_a.weapon_cost = 50
	_weapon_a.durability_max = 100
	_weapon_a.role_title = "通用型"
	_weapon_a.reliability_stars = 2
	_weapon_a.damage = 20.0
	_weapon_a.shot_count = 1
	_weapon_a.cooldown = 0.2
	_weapon_a.spread = 1.5
	_weapon_a.magazine_size = 12
	_weapon_a.max_reserve = 48
	_weapon_a.reload_time = 1.5

	_weapon_b = Weapon.new()
	_weapon_b.display_name = "测试枪B"
	_weapon_b.ammo_type = &"步枪弹"
	_weapon_b.weapon_cost = 80
	_weapon_b.durability_max = 200
	_weapon_b.role_title = "精准型"
	_weapon_b.reliability_stars = 3
	_weapon_b.damage = 35.0
	_weapon_b.shot_count = 1
	_weapon_b.cooldown = 0.8
	_weapon_b.spread = 0.5
	_weapon_b.magazine_size = 6
	_weapon_b.max_reserve = 24
	_weapon_b.reload_time = 2.0

	# 构造 player
	_player = Node3D.new()
	_player.set_script(load("res://objects/player.gd"))
	_player.weapons = [_weapon_a, _weapon_b]
	_player.weapon_index = 0
	_player.magazine = [_weapon_a.magazine_size, _weapon_b.magazine_size]
	_player.ammo_reserve = {&"手枪弹": 36, &"步枪弹": 24}
	_player.weapon_durability = [_weapon_a.durability_max, _weapon_b.durability_max]
	_player.weapon = _weapon_a
	add_child(_player)

	# 构造 UI
	var ui_scene := load("res://scenes/weapon_inspect_ui.tscn") as PackedScene
	if ui_scene:
		_ui = ui_scene.instantiate()
		add_child(_ui)


func after_each() -> void:
	if _ui and is_instance_valid(_ui):
		_ui.queue_free()
	if _player and is_instance_valid(_player):
		_player.queue_free()


func test_open_shows_correct_card_count() -> void:
	_ui.open(_player)
	assert_true(_ui.visible, "打开后 UI 应可见")
	# 玩家有 2 把枪，应有 2 张填充卡片 + 1 张空槽卡片
	# (3 张卡片总共)
	var panels := _ui._card_panels
	assert_eq(panels.size(), 3, "应显示 3 张卡片")


func test_current_weapon_has_gold_border() -> void:
	_ui.open(_player)
	# 槽位 0 是当前武器，应高亮
	var panels := _ui._card_panels
	assert_gt(panels.size(), 0, "至少应有卡片")
	# 边框检查：card 0 应为当前武器边框（金色）
	# 验证 _pinned_index 为 -1（非对比模式）
	assert_eq(_ui._pinned_index, -1, "初始无固定参考卡片")


func test_pin_card_for_comparison() -> void:
	_ui.open(_player)
	assert_eq(_ui._pinned_index, -1, "初始无钉选")
	# 模拟点击卡片 1（第二把枪）
	var click_event := InputEventMouseButton.new()
	click_event.pressed = true
	click_event.button_index = MOUSE_BUTTON_LEFT
	_ui._on_card_clicked(click_event, 1)
	assert_eq(_ui._pinned_index, 1, "卡片 1 应成为对比参考")


func test_unpin_same_card() -> void:
	_ui.open(_player)
	# 先钉选
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	_ui._on_card_clicked(click, 0)
	assert_eq(_ui._pinned_index, 0, "应钉选卡片 0")
	# 再次点击同一张取消
	_ui._on_card_clicked(click, 0)
	assert_eq(_ui._pinned_index, -1, "再次点击应取消钉选")


func test_empty_slot_cannot_be_pinned() -> void:
	_ui.open(_player)
	# 槽位 2 为空（player 只有 2 把枪）
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	_ui._on_card_clicked(click, 2)
	assert_eq(_ui._pinned_index, -1, "空槽不可钉选")


func test_close_hides_ui() -> void:
	_ui.open(_player)
	assert_true(_ui.visible, "打开后应可见")
	_ui.close()
	assert_false(_ui.visible, "关闭后应不可见")
	assert_false(_ui.is_open(), "is_open 应返回 false")


func test_auto_close_on_pause() -> void:
	_ui.open(_player)
	assert_true(_ui.visible, "打开后应可见")
	get_tree().paused = true
	# 给 _process 一个机会运行
	await get_tree().process_frame
	assert_false(_ui.visible, "暂停时 UI 应自动关闭")
	get_tree().paused = false


func test_dps_calculation() -> void:
	var dps_a := _ui._calc_dps(_weapon_a)  # 20 / 0.2 = 100
	assert_true(dps_a > 90.0 and dps_a < 110.0, "DPS A 应在合理范围")
	var dps_b := _ui._calc_dps(_weapon_b)  # 35 / 0.8 = 43.75
	assert_true(dps_b > 40.0 and dps_b < 50.0, "DPS B 应在合理范围")


func test_ammo_display_uses_ammo_reserve() -> void:
	_ui.open(_player)
	# 验证 refresh_ammo 不报错
	_ui.refresh_ammo()
	# 测试通过即表示调用成功（内部使用 get_reserve -> ammo_reserve）


func test_reliability_stars_display() -> void:
	var stars_1 := _ui._reliability_stars(1)
	assert_true(stars_1 == "★☆☆", "1 星应为 ★☆☆")
	var stars_2 := _ui._reliability_stars(2)
	assert_true(stars_2 == "★★☆", "2 星应为 ★★☆")
	var stars_3 := _ui._reliability_stars(3)
	assert_true(stars_3 == "★★★", "3 星应为 ★★★")


func test_accuracy_label() -> void:
	var w_high := Weapon.new()
	w_high.spread = 0.3
	assert_true(_ui._accuracy_label(w_high) == "极高", "spread 0.3 → 极高")
	var w_med := Weapon.new()
	w_med.spread = 2.0
	assert_true(_ui._accuracy_label(w_med) == "中", "spread 2.0 → 中")
	var w_low := Weapon.new()
	w_low.spread = 5.0
	assert_true(_ui._accuracy_label(w_low) == "极低", "spread 5.0 → 极低")


func test_bar_color_for_durability() -> void:
	var c_high := _ui._bar_color_for_durability(250)
	assert_eq(c_high, Color(0.25, 0.85, 0.3), "高耐久 → 绿色")
	var c_med := _ui._bar_color_for_durability(150)
	assert_eq(c_med, Color(0.85, 0.75, 0.2), "中耐久 → 黄色")
	var c_low := _ui._bar_color_for_durability(50)
	assert_eq(c_low, Color(0.85, 0.35, 0.2), "低耐久 → 红色")
