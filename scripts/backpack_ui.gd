extends Control
## ADR 023：T 键背包 UI
##
## 左侧：背包物品列表（按类型分组，含重量信息）
## 右侧：10 个备弹槽（可点击分配弹药）
## 关闭 UI 后进入 1.5s 整理动画（可移动不可射击）

signal closed

var _player: Node3D
var _open := false

# 选中状态
var _selected_backpack_item: Dictionary = {}  # 或空
var _selected_slot_idx: int = -1

# UI 引用
@onready var _panel: PanelContainer = _build_panel()
@onready var _title: Label = _build_title()
@onready var _left_scroll: ScrollContainer = _build_left_scroll()
@onready var _left_content: VBoxContainer
@onready var _right_scroll: ScrollContainer = _build_right_scroll()
@onready var _right_content: VBoxContainer
@onready var _close_btn: Button = _build_close_button()
@onready var _weight_label: Label = Label.new()
@onready var _prompt_label: Label = Label.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("backpack_ui")

	# 布局：全屏面板
	add_child(_panel)

	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 16)
	main_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(main_hbox)

	# 左侧：背包物品
	_left_content = VBoxContainer.new()
	_left_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left_content.add_theme_constant_override("separation", 4)
	_left_scroll.add_child(_left_content)

	var left_vbox := VBoxContainer.new()
	left_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_vbox.add_theme_constant_override("separation", 4)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(_title)
	left_vbox.add_child(_weight_label)
	left_vbox.add_child(_left_scroll)
	main_hbox.add_child(left_vbox)

	# 右侧：备弹槽
	_right_content = VBoxContainer.new()
	_right_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right_content.add_theme_constant_override("separation", 4)
	_right_scroll.add_child(_right_content)

	var right_vbox := VBoxContainer.new()
	right_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_vbox.add_theme_constant_override("separation", 4)
	var right_title := Label.new()
	right_title.text = "备弹槽"
	right_title.add_theme_font_size_override("font_size", 24)
	right_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_vbox.add_child(right_title)
	right_vbox.add_child(_right_scroll)

	main_hbox.add_child(right_vbox)

	# 底部提示和关闭按钮
	var bottom_vbox := VBoxContainer.new()
	bottom_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_vbox.add_theme_constant_override("separation", 8)
	bottom_vbox.add_child(_prompt_label)
	bottom_vbox.add_child(_close_btn)
	main_hbox.add_child(bottom_vbox)

	_weight_label.add_theme_font_size_override("font_size", 18)
	_weight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_weight_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_prompt_label.text = "点击左侧物品 → 点击右侧备弹槽分配"
	_prompt_label.add_theme_font_size_override("font_size", 16)
	_prompt_label.add_theme_color_override("font_color", Color(1, 1, 0.5, 1))
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

# ============================================================
# 公共 API
# ============================================================

func is_open() -> bool:
	return _open

func open(player: Node3D) -> void:
	if _open:
		return
	_player = player
	_open = true
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_selected_backpack_item = {}
	_selected_slot_idx = -1
	_refresh_all()

func close() -> void:
	close_and_pack()

func close_and_pack() -> void:
	if not _open:
		return
	_open = false
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# 启动整理动画
	if _player and is_instance_valid(_player):
		_player._is_packing = true
		# 1.5s 后结束整理
		get_tree().create_timer(1.5, false, false, false).timeout.connect(func():
			if _player and is_instance_valid(_player):
				_player._is_packing = false
		)
	closed.emit()

# ============================================================
# 刷新方法
# ============================================================

func _refresh_all() -> void:
	_refresh_left()
	_refresh_right()
	_refresh_weight_label()

func _refresh_weight_label() -> void:
	_weight_label.text = "背包负重: %.1f / %.1f" % [_player.backpack_weight, _player.backpack_max_weight]

func _refresh_left() -> void:
	for child in _left_content.get_children():
		child.queue_free()

	if _player.backpack_items.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "（背包为空）"
		empty_lbl.add_theme_font_size_override("font_size", 18)
		empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_left_content.add_child(empty_lbl)
		return

	# 按类型分组
	var groups: Dictionary = {}
	for key in _player.backpack_items:
		var entry: Dictionary = _player.backpack_items[key]
		var type: StringName = entry["type"]
		if not groups.has(type):
			groups[type] = []
		groups[type].append({"key": key, "entry": entry})

	# 弹药组
	if groups.has(&"ammo"):
		var header := _make_section_header("弹药")
		_left_content.add_child(header)
		for item in groups[&"ammo"]:
			_left_content.add_child(_build_backpack_row(item["key"], item["entry"]))

	# 武器组
	if groups.has(&"weapon"):
		var header := _make_section_header("枪械")
		_left_content.add_child(header)
		for item in groups[&"weapon"]:
			_left_content.add_child(_build_backpack_row(item["key"], item["entry"]))

	# 血包组
	if groups.has(&"health_pack"):
		var header := _make_section_header("血包")
		_left_content.add_child(header)
		for item in groups[&"health_pack"]:
			_left_content.add_child(_build_backpack_row(item["key"], item["entry"]))

func _make_section_header(text: String) -> Label:
	var l := Label.new()
	l.text = "--- %s ---" % text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _ammo_display_name(ammo_type: StringName) -> String:
	match ammo_type:
		&"手枪弹": return "手枪弹"
		&"步枪弹": return "步枪弹"
		&"霰弹": return "霰弹"
		&"狙击弹": return "狙击弹"
		&"能量电池": return "能量电池"
		&"榴弹": return "榴弹"
		_: return str(ammo_type)

func _build_backpack_row(item_key: StringName, entry: Dictionary) -> Button:
	var btn := Button.new()
	var count: int = entry["count"]
	var wpu: float = entry["weight_per_unit"]
	var total_w := count * wpu
	var type: StringName = entry["type"]

	var display: String
	match type:
		&"ammo":
			display = "%s: %d发 (%.2f/%.2f)" % [_ammo_display_name(item_key), count, total_w, wpu]
		&"weapon":
			display = "%s: ×1 (%.1f)" % [str(item_key), total_w]
		&"health_pack":
			display = "血包: ×%d (%.1f/%.1f)" % [count, total_w, wpu]

	btn.text = display
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 16)
	btn.custom_minimum_size = Vector2(300, 32)

	# 是当前选中行则高亮
	if _selected_backpack_item.get("key", "") == item_key:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.3, 0.5, 0.8, 0.5)
		btn.add_theme_stylebox_override("normal", style)

	btn.pressed.connect(func():
		_selected_backpack_item = {"key": item_key, "entry": entry}
		_selected_slot_idx = -1
		_refresh_all()
	)
	return btn

func _refresh_right() -> void:
	for child in _right_content.get_children():
		child.queue_free()

	for i in range(_player.ammo_slots.size()):
		var slot: Dictionary = _player.ammo_slots[i]
		var btn := Button.new()
		if slot["ammo_type"] == &"" or slot["capacity"] == 0:
			btn.text = "槽 %d: 空" % (i + 1)
		else:
			btn.text = "槽 %d: %s %d/%d" % [i + 1, _ammo_display_name(slot["ammo_type"]), slot["remaining"], slot["capacity"]]

		btn.add_theme_font_size_override("font_size", 16)
		btn.custom_minimum_size = Vector2(250, 32)

		# 高亮选中槽
		if _selected_slot_idx == i:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.3, 0.8, 0.5, 0.5)
			btn.add_theme_stylebox_override("normal", style)

		btn.pressed.connect(func():
			_on_slot_clicked(i)
		)
		_right_content.add_child(btn)

# ============================================================
# 分配逻辑
# ============================================================

func _on_slot_clicked(slot_idx: int) -> void:
	if _selected_backpack_item.is_empty():
		# 未选中背包物品：改为选中该槽（方便后续操作）
		_selected_slot_idx = slot_idx
		_selected_backpack_item = {}
		_refresh_all()
		return

	# 已选中背包物品 → 分配到该槽
	var item_key: StringName = _selected_backpack_item["key"]
	var entry: Dictionary = _selected_backpack_item["entry"]
	var entry_type: StringName = entry["type"]

	if entry_type != &"ammo":
		# 非弹药不能分配到备弹槽
		_selected_backpack_item = {}
		_refresh_all()
		return

	# 获取该弹种的 magazine_size（从玩家当前武器或默认值）
	var ammo_type: StringName = item_key  # item_key 本身就是 ammo_type
	var mag_size := _get_magazine_size_for_ammo(ammo_type)
	if mag_size <= 0:
		_selected_backpack_item = {}
		_refresh_all()
		return

	var target_slot: Dictionary = _player.ammo_slots[slot_idx]

	# 若目标槽已有不同弹种：先清空退回背包
	if target_slot["ammo_type"] != &"" and target_slot["ammo_type"] != ammo_type:
		# 退回到背包
		var return_count: int = target_slot["remaining"] * target_slot["capacity"]
		if return_count > 0:
			_player.backpack_add(target_slot["ammo_type"], &"ammo", return_count, _player.ITEM_WEIGHTS.get(target_slot["ammo_type"], 0.01))
		target_slot["ammo_type"] = &""
		target_slot["remaining"] = 0
		target_slot["capacity"] = 0

	# 计算可从背包取出的数量
	var available: int = entry["count"]
	var needed: int = mag_size  # 一弹匣量
	var take: int = mini(available, needed)

	# 从背包取出（子弹按发计数）
	_player.backpack_remove(item_key, take)

	# 若目标槽同弹种：追加 remaining
	if target_slot["ammo_type"] == ammo_type:
		target_slot["remaining"] += 1
	else:
		# 新分配
		target_slot["ammo_type"] = ammo_type
		target_slot["remaining"] = 1
		target_slot["capacity"] = mag_size

	# 清除选中
	_selected_backpack_item = {}
	_selected_slot_idx = -1
	_refresh_all()

func _get_magazine_size_for_ammo(ammo_type: StringName) -> int:
	# 从玩家已装备武器中找匹配该弹种的 magazine_size
	for w in _player.weapons:
		if w.ammo_type == ammo_type:
			return w.magazine_size
	# 回退默认值
	match ammo_type:
		&"手枪弹": return 12
		&"步枪弹": return 30
		&"霰弹": return 8
		&"狙击弹": return 5
		&"能量电池": return 20
		&"榴弹": return 1
		_: return 10

# ============================================================
# UI 构建
# ============================================================

func _build_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.anchor_left = 0.05
	p.anchor_top = 0.05
	p.anchor_right = 0.95
	p.anchor_bottom = 0.95
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p

func _build_title() -> Label:
	var l := Label.new()
	l.text = "背包  |  ESC 关闭"
	l.add_theme_font_size_override("font_size", 28)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build_left_scroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	s.mouse_filter = Control.MOUSE_FILTER_PASS
	s.custom_minimum_size = Vector2(400, 500)
	return s

func _build_right_scroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	s.mouse_filter = Control.MOUSE_FILTER_PASS
	s.custom_minimum_size = Vector2(300, 500)
	return s

func _build_close_button() -> Button:
	var b := Button.new()
	b.text = "关闭并整理 (ESC)"
	b.add_theme_font_size_override("font_size", 18)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.pressed.connect(close_and_pack)
	return b

# ============================================================
# 输入：ESC 关闭
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("mouse_capture_exit"):
		close_and_pack()
		get_viewport().set_input_as_handled()
