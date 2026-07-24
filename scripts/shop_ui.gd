extends Control
## issue 04（ADR 012 / 013 / 015）：子弹商店购买 UI
##
## 由 ShopStation（Area3D）在玩家走入触发区时调用 open(player, run_director)：
##   - 显示玩家当前持有武器的购买行（名称 / 当前备弹 / 单价 / +1 / +10 / 买满 / 状态）
##   - 暂停期间可点击（process_mode = WHEN_PAUSED）
##   - 鼠标进入时切 VISIBLE，关闭时切 CAPTURED
##
## 购买步进：+1 / +10 / 买满。+10 与买满在金币不足时自动降级到"买得起的数量"。
## 上限封顶：reserve 不超过 weapon.max_reserve + player.bonus_max_reserve（issue 05 bonus）。
## 扣金币通过 run_director.spend_gold(cost)；不足返回 false 不扣。
##
## 关闭：ESC（复用 mouse_capture_exit 动作，PAUSABLE 玩家冻结不会冲突）/ 关闭按钮 / ShopStation body_exited。
## 关闭 → 隐藏 + 恢复鼠标捕获 + emit closed（ShopStation 监听以恢复游戏暂停）。

signal closed

var _player: Node3D
var _run_director: Node
var _open := false

# 每行子节点引用，便于购买后刷新
var _rows: Array = [] # Array[Dictionary]
@onready var _panel: PanelContainer = _build_panel()
@onready var _content: VBoxContainer = _build_content()
@onready var _title: Label = _build_title()
@onready var _close_btn: Button = _build_close_button()
@onready var _list: VBoxContainer = _build_list()
@onready var _gold_label: Label = _build_gold_label()

func _ready() -> void:
	# 暂停期间可交互
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	_panel.add_child(_content)
	_content.add_child(_title)
	_content.add_child(_gold_label)
	_content.add_child(_list)
	_content.add_child(_close_btn)
	# 加入 group 供 ShopStation 查找（生产环境）
	add_to_group("shop_ui")
	# gold_changed 绑定延迟到 open() 时（_run_director 注入后再绑，避免重复连接）

func _on_gold_changed(_amount: int) -> void:
	if _open:
		_refresh_gold_label()
		_refresh_row_states()

# ============================================================
# 公共 API（供 ShopStation 与测试调用）
# ============================================================

## 是否处于打开状态
func is_open() -> bool:
	return _open

## 由 ShopStation 调用：绑定 player/run_director 并打开 UI
func open(player: Node3D, run_director: Node) -> void:
	if _open:
		return
	_player = player
	_run_director = run_director
	_open = true
	_build_rows()
	_refresh_gold_label()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# 绑定 gold_changed（若 _ready 时 _run_director 尚未注入，此处补绑）
	if _run_director and _run_director.has_signal("gold_changed"):
		if not _run_director.gold_changed.is_connected(_on_gold_changed):
			_run_director.gold_changed.connect(_on_gold_changed)

## 关闭 UI（不直接 unpause——由 ShopStation 监听 closed 信号处理）
func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()

## 有效备弹上限 = weapon.max_reserve + player.bonus_max_reserve（issue 05 bonus）
func effective_cap(weapon_index: int) -> int:
	if _player == null or not is_instance_valid(_player):
		return 0
	var w: Weapon = _player.weapons[weapon_index]
	return _player.effective_max_reserve(w)

## 是否已满（reserve >= effective_cap）
func is_full(weapon_index: int) -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	return _player.reserve[weapon_index] >= effective_cap(weapon_index)

## 金币是否够买 count 发
func can_afford(weapon_index: int, count: int) -> bool:
	if _run_director == null:
		return false
	var w: Weapon = _player.weapons[weapon_index]
	return _run_director.gold >= w.gold_cost_per_bullet * count

## 核心购买逻辑：买 requested_count 发，返回实际买入数（金币不足/接近上限时降级）
## - 上限封顶：实际买入不超过 effective_cap - current_reserve
## - 金币不足：降到 gold / cost_per_bullet 能买的数量
## - 扣金币：run_director.spend_gold(actual * cost_per)
## - 加备弹：player.reserve[idx] += actual
## - 广播 ammo_updated 让 HUD 同步刷新
func buy_bullets(weapon_index: int, requested_count: int) -> int:
	if not _open:
		return 0
	if _player == null or not is_instance_valid(_player):
		return 0
	if _run_director == null:
		return 0
	if weapon_index < 0 or weapon_index >= _player.weapons.size():
		return 0
	var w: Weapon = _player.weapons[weapon_index]
	var cost_per: int = w.gold_cost_per_bullet
	if cost_per <= 0:
		return 0
	var cap: int = effective_cap(weapon_index)
	var current: int = _player.reserve[weapon_index]
	var headroom: int = cap - current
	if headroom <= 0:
		return 0  # 已满
	# 想要的数量受上限约束
	var want: int = mini(requested_count, headroom)
	# 金币能买的数量（降级）
	var max_affordable: int = int(_run_director.gold) / cost_per
	var actual: int = mini(want, max_affordable)
	if actual <= 0:
		return 0
	var cost: int = actual * cost_per
	if not _run_director.spend_gold(cost):
		return 0
	_player.reserve[weapon_index] += actual
	# 广播弹药刷新（信号回调不受暂停影响，HUD 会同步更新）
	if _player.has_method("_emit_ammo_updated"):
		_player._emit_ammo_updated()
	# 刷新本 UI 行（备弹数 + 按钮可用性）
	_refresh_row(weapon_index)
	_refresh_gold_label()
	_refresh_row_states()
	return actual

## 买满当前武器（headroom 发）
func buy_max(weapon_index: int) -> int:
	if _player == null or not is_instance_valid(_player):
		return 0
	var headroom: int = effective_cap(weapon_index) - int(_player.reserve[weapon_index])
	return buy_bullets(weapon_index, headroom)

# ============================================================
# UI 构建
# ============================================================

func _build_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.anchor_left = 0.25
	p.anchor_top = 0.2
	p.anchor_right = 0.75
	p.anchor_bottom = 0.8
	p.offset_left = 0
	p.offset_top = 0
	p.offset_right = 0
	p.offset_bottom = 0
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p

func _build_content() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 16)
	return v

func _build_title() -> Label:
	var l := Label.new()
	l.text = "子弹商店  |  ESC 关闭"
	l.add_theme_font_size_override("font_size", 28)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build_close_button() -> Button:
	var b := Button.new()
	b.text = "关闭 (ESC)"
	b.add_theme_font_size_override("font_size", 18)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.pressed.connect(close)
	return b

func _build_list() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 8)
	return v

func _build_gold_label() -> Label:
	var l := Label.new()
	l.text = "金币: 0"
	l.add_theme_font_size_override("font_size", 20)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _refresh_gold_label() -> void:
	if _run_director:
		_gold_label.text = "金币: %d" % _run_director.gold

## 构建每把武器的购买行
func _build_rows() -> void:
	for c in _list.get_children():
		c.queue_free()
	_rows.clear()
	if _player == null:
		return
	for i in range(_player.weapons.size()):
		var w: Weapon = _player.weapons[i]
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 12)

		var name_lbl := Label.new()
		name_lbl.text = w.display_name
		name_lbl.add_theme_font_size_override("font_size", 20)
		name_lbl.custom_minimum_size = Vector2(120, 0)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_lbl)

		var ammo_lbl := Label.new()
		ammo_lbl.add_theme_font_size_override("font_size", 20)
		ammo_lbl.custom_minimum_size = Vector2(100, 0)
		ammo_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ammo_lbl)

		var cost_lbl := Label.new()
		cost_lbl.add_theme_font_size_override("font_size", 18)
		cost_lbl.custom_minimum_size = Vector2(80, 0)
		cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_lbl.text = "%d金/发" % w.gold_cost_per_bullet
		row.add_child(cost_lbl)

		var btn1 := Button.new()
		btn1.text = "+1"
		btn1.add_theme_font_size_override("font_size", 18)
		btn1.custom_minimum_size = Vector2(50, 36)
		btn1.pressed.connect(buy_bullets.bind(i, 1))
		row.add_child(btn1)

		var btn10 := Button.new()
		btn10.text = "+10"
		btn10.add_theme_font_size_override("font_size", 18)
		btn10.custom_minimum_size = Vector2(60, 36)
		btn10.pressed.connect(buy_bullets.bind(i, 10))
		row.add_child(btn10)

		var btn_max := Button.new()
		btn_max.text = "买满"
		btn_max.add_theme_font_size_override("font_size", 18)
		btn_max.custom_minimum_size = Vector2(70, 36)
		btn_max.pressed.connect(buy_max.bind(i))
		row.add_child(btn_max)

		var status_lbl := Label.new()
		status_lbl.add_theme_font_size_override("font_size", 16)
		status_lbl.custom_minimum_size = Vector2(100, 0)
		status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(status_lbl)

		_list.add_child(row)
		_rows.append({
			"name": name_lbl,
			"ammo": ammo_lbl,
			"btn1": btn1,
			"btn10": btn10,
			"btn_max": btn_max,
			"status": status_lbl,
		})
		_refresh_row(i)
	_refresh_row_states()

## 刷新单行的弹药显示（购买后调用）
func _refresh_row(idx: int) -> void:
	if idx < 0 or idx >= _rows.size():
		return
	if _player == null or not is_instance_valid(_player):
		return
	var row: Dictionary = _rows[idx]
	var w: Weapon = _player.weapons[idx]
	var current: int = _player.reserve[idx]
	var cap: int = effective_cap(idx)
	(row["ammo"] as Label).text = "%d / %d" % [current, cap]

## 刷新所有按钮可用性 + 状态文案（金币不足 → 灰显 "金币不足"；已满 → "已满"）
func _refresh_row_states() -> void:
	for i in range(_rows.size()):
		var row: Dictionary = _rows[i]
		var full := is_full(i)
		var afford_one := can_afford(i, 1)
		var btn1: Button = row["btn1"]
		var btn10: Button = row["btn10"]
		var btn_max: Button = row["btn_max"]
		var status: Label = row["status"]
		if full:
			btn1.disabled = true
			btn10.disabled = true
			btn_max.disabled = true
			status.text = "已满"
		elif not afford_one:
			btn1.disabled = true
			btn10.disabled = true
			btn_max.disabled = true
			status.text = "金币不足"
		else:
			btn1.disabled = false
			btn10.disabled = false
			btn_max.disabled = false
			status.text = ""

# ============================================================
# 输入：ESC 关闭（复用 mouse_capture_exit，避免新增 ESC 绑定）
# Player 在暂停期间 _process 冻结，不会与 ESC 释放鼠标捕获冲突
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("mouse_capture_exit"):
		close()
		get_viewport().set_input_as_handled()
