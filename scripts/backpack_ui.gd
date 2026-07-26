extends Control
## ADR 023：T 键背包 UI（UI 现代化 issue 05）
##
## 左侧：背包物品列表（按类型分组，含重量信息）
## 右侧：10 个备弹槽（2×5 网格，可点击分配弹药）
## 关闭 UI 后进入 1.5s 整理动画（可移动不可射击）
##
## UI 现代化：引用 UITheme token，标题加 package 图标，重量 ProgressBar，
## 打开/关闭过渡使用 UIMotion.tween_modal_in/out。

signal closed

var _player: Node3D
var _open := false

# 选中状态
var _selected_backpack_item: Dictionary = {}  # 或空
var _selected_slot_idx: int = -1

# UI 引用
@onready var _bg: ColorRect = _build_bg()
@onready var _panel: PanelContainer = _build_panel()
@onready var _title: HBoxContainer = _build_title_bar()
@onready var _left_scroll: ScrollContainer = _build_left_scroll()
@onready var _left_content: VBoxContainer
@onready var _right_grid: GridContainer = _build_right_grid()
@onready var _close_btn: Button = _build_close_button()
@onready var _weight_label: Label = Label.new()
@onready var _weight_bar: ProgressBar = _build_weight_bar()
@onready var _prompt_label: Label = Label.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("backpack_ui")

	# 全屏背景 + 中央面板
	add_child(_bg)
	add_child(_panel)

	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", UITheme.SPACING_LG)
	main_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(main_hbox)

	# 左侧：背包物品
	_left_content = VBoxContainer.new()
	_left_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left_content.add_theme_constant_override("separation", UITheme.SPACING_XS)
	_left_scroll.add_child(_left_content)

	var left_vbox := VBoxContainer.new()
	left_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_vbox.add_theme_constant_override("separation", UITheme.SPACING_XS)
	left_vbox.add_child(_title)
	left_vbox.add_child(_weight_label)
	left_vbox.add_child(_weight_bar)
	left_vbox.add_child(_left_scroll)
	main_hbox.add_child(left_vbox)

	# 右侧：备弹槽 2×5 网格
	var right_vbox := VBoxContainer.new()
	right_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_vbox.add_theme_constant_override("separation", UITheme.SPACING_XS)
	var right_title := Label.new()
	right_title.text = "备弹槽"
	right_title.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_XL)
	right_title.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_PRIMARY)
	right_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_vbox.add_child(right_title)
	right_vbox.add_child(_right_grid)
	main_hbox.add_child(right_vbox)

	# 底部提示和关闭按钮
	var bottom_vbox := VBoxContainer.new()
	bottom_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_vbox.add_theme_constant_override("separation", UITheme.SPACING_SM)
	bottom_vbox.add_child(_prompt_label)
	bottom_vbox.add_child(_close_btn)
	main_hbox.add_child(bottom_vbox)

	_weight_label.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_MD)
	_weight_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	_weight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_weight_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_prompt_label.text = "点击左侧物品 → 点击右侧备弹槽分配弹药"
	_prompt_label.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SM)
	_prompt_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)
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
	# 打开过渡动效（issue 05）
	UIMotion.tween_modal_in(self)

func close() -> void:
	close_and_pack()

func close_and_pack() -> void:
	if not _open:
		return
	_open = false
	# 关闭过渡动效（issue 05）；visible 立即设为 false 保持原有 API 契约
	UIMotion.tween_modal_out(self)
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
	var ratio: float = _player.backpack_weight / maxf(_player.backpack_max_weight, 1.0)
	var fullness := ""
	if ratio > 0.9:
		fullness = " [负重警告!]"
		_weight_label.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_DANGER)
	elif ratio > 0.7:
		fullness = " [较重]"
		_weight_label.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_WARNING)
	else:
		_weight_label.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_PRIMARY)
	_weight_label.text = "背包负重: %.1f / %.1f  (%.0f%%)%s" % [_player.backpack_weight, _player.backpack_max_weight, ratio * 100, fullness]
	# 重量 ProgressBar 颜色：超 80% warning，超 100% danger
	_weight_bar.value = clampf(ratio * 100.0, 0.0, 100.0)
	_weight_bar.modulate = (
		UITheme.COLOR_ACCENT_DANGER if ratio > 1.0
		else UITheme.COLOR_ACCENT_WARNING if ratio > 0.8
		else UITheme.COLOR_ACCENT_PRIMARY
	)

func _refresh_left() -> void:
	for child in _left_content.get_children():
		child.queue_free()

	if _player.backpack_items.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "（背包为空）"
		empty_lbl.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_MD)
		empty_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)
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
	l.text = "▸ %s" % text
	l.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_MD)
	l.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_WARNING)
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
	# 行底色：按类型区分（基于 UITheme token，混合透明度）
	var row_color: Color = Color(UITheme.COLOR_BG_PANEL.r, UITheme.COLOR_BG_PANEL.g, UITheme.COLOR_BG_PANEL.b, 0.9)
	match type:
		&"ammo":
			display = "   %s  ×%d发  (%.1f重)" % [_ammo_display_name(item_key), count, total_w]
			row_color = Color(UITheme.COLOR_BG_PANEL.r, UITheme.COLOR_BG_PANEL.g, UITheme.COLOR_BG_PANEL.b, 0.9)
		&"weapon":
			display = "   %s  ×1  (%.1f重)" % [str(item_key), total_w]
			row_color = Color(UITheme.COLOR_BG_PANEL_RAISED.r, UITheme.COLOR_BG_PANEL_RAISED.g, UITheme.COLOR_BG_PANEL_RAISED.b, 0.9)
		&"health_pack":
			display = "   血包  ×%d  (%.1f重)" % [count, total_w]
			row_color = Color(UITheme.COLOR_ACCENT_DANGER.r, UITheme.COLOR_ACCENT_DANGER.g, UITheme.COLOR_ACCENT_DANGER.b, 0.18)

	btn.text = display
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SM)
	btn.custom_minimum_size = Vector2(320, 36)

	# 基础行样式
	var base_style := StyleBoxFlat.new()
	base_style.bg_color = row_color
	base_style.corner_radius_top_left = 4
	base_style.corner_radius_top_right = 4
	base_style.corner_radius_bottom_left = 4
	base_style.corner_radius_bottom_right = 4
	base_style.content_margin_left = 6
	base_style.content_margin_right = 6
	btn.add_theme_stylebox_override("normal", base_style)

	# 是当前选中行则高亮（accent_primary 半透明）
	if _selected_backpack_item.get("key", "") == item_key:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(UITheme.COLOR_ACCENT_PRIMARY.r, UITheme.COLOR_ACCENT_PRIMARY.g, UITheme.COLOR_ACCENT_PRIMARY.b, 0.25)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		style.content_margin_left = 6
		style.content_margin_right = 6
		btn.add_theme_stylebox_override("normal", style)

	btn.pressed.connect(func():
		_selected_backpack_item = {"key": item_key, "entry": entry}
		_selected_slot_idx = -1
		_refresh_all()
	)
	return btn

func _refresh_right() -> void:
	for child in _right_grid.get_children():
		child.queue_free()

	for i in range(_player.ammo_slots.size()):
		var slot: Dictionary = _player.ammo_slots[i]
		var btn := Button.new()
		var slot_color: Color
		if slot["ammo_type"] == &"" or slot["capacity"] == 0:
			btn.text = "槽 %d\n[空]" % (i + 1)
			slot_color = Color(UITheme.COLOR_BG_PANEL.r, UITheme.COLOR_BG_PANEL.g, UITheme.COLOR_BG_PANEL.b, 0.9)
		else:
			var ratio: float = float(slot["remaining"]) / maxf(float(slot["capacity"]), 1.0)
			btn.text = "槽 %d\n%s\n[%d/%d]" % [i + 1, _ammo_display_name(slot["ammo_type"]), slot["remaining"], slot["capacity"]]
			if ratio > 0.5:
				slot_color = Color(UITheme.COLOR_ACCENT_PRIMARY.r, UITheme.COLOR_ACCENT_PRIMARY.g, UITheme.COLOR_ACCENT_PRIMARY.b, 0.25)
			elif ratio > 0.0:
				slot_color = Color(UITheme.COLOR_ACCENT_WARNING.r, UITheme.COLOR_ACCENT_WARNING.g, UITheme.COLOR_ACCENT_WARNING.b, 0.25)
			else:
				slot_color = Color(UITheme.COLOR_ACCENT_DANGER.r, UITheme.COLOR_ACCENT_DANGER.g, UITheme.COLOR_ACCENT_DANGER.b, 0.25)

		btn.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SM)
		btn.custom_minimum_size = Vector2(130, 56)
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

		# 槽位样式
		var base_style := StyleBoxFlat.new()
		base_style.bg_color = slot_color
		base_style.corner_radius_top_left = 4
		base_style.corner_radius_top_right = 4
		base_style.corner_radius_bottom_left = 4
		base_style.corner_radius_bottom_right = 4
		base_style.content_margin_left = UITheme.SPACING_SM
		base_style.content_margin_right = UITheme.SPACING_SM
		btn.add_theme_stylebox_override("normal", base_style)

		# 高亮选中槽（accent_primary 半透明）
		if _selected_slot_idx == i:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(UITheme.COLOR_ACCENT_PRIMARY.r, UITheme.COLOR_ACCENT_PRIMARY.g, UITheme.COLOR_ACCENT_PRIMARY.b, 0.45)
			style.corner_radius_top_left = 4
			style.corner_radius_top_right = 4
			style.corner_radius_bottom_left = 4
			style.corner_radius_bottom_right = 4
			style.content_margin_left = UITheme.SPACING_SM
			style.content_margin_right = UITheme.SPACING_SM
			btn.add_theme_stylebox_override("normal", style)

		btn.pressed.connect(func():
			_on_slot_clicked(i)
		)
		_right_grid.add_child(btn)

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

func _build_bg() -> ColorRect:
	var r := ColorRect.new()
	# bg_base 80% alpha
	r.color = Color(UITheme.COLOR_BG_BASE.r, UITheme.COLOR_BG_BASE.g, UITheme.COLOR_BG_BASE.b, 0.8)
	r.anchor_left = 0.0
	r.anchor_top = 0.0
	r.anchor_right = 1.0
	r.anchor_bottom = 1.0
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r

func _build_panel() -> PanelContainer:
	var p := PanelContainer.new()
	# 中央 bg_panel 面板（70% 视口）
	p.anchor_left = 0.15
	p.anchor_top = 0.15
	p.anchor_right = 0.85
	p.anchor_bottom = 0.85
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	# bg_panel 面板风格
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = UITheme.COLOR_BG_PANEL
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = UITheme.COLOR_BG_PANEL_RAISED
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = UITheme.SPACING_LG
	panel_style.content_margin_right = UITheme.SPACING_LG
	panel_style.content_margin_top = UITheme.SPACING_MD
	panel_style.content_margin_bottom = UITheme.SPACING_MD
	p.add_theme_stylebox_override("panel", panel_style)
	return p

## 标题栏：package 图标 + "背  包"
func _build_title_bar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", UITheme.SPACING_SM)

	# package 图标
	var icon := TextureRect.new()
	icon.texture = UITheme.get_icon(UITheme.ICON_PACKAGE)
	icon.custom_minimum_size = Vector2(UITheme.FONT_SIZE_2XL, UITheme.FONT_SIZE_2XL)
	icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = UITheme.COLOR_ACCENT_PRIMARY
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(icon)

	# 标题文字
	var l := Label.new()
	l.text = "背  包"
	l.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_2XL)
	l.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(l)
	return bar

func _build_left_scroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	s.mouse_filter = Control.MOUSE_FILTER_PASS
	s.custom_minimum_size = Vector2(400, 500)
	return s

## 右侧 2×5 网格容器（10 个备弹槽）
func _build_right_grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", UITheme.SPACING_SM)
	g.add_theme_constant_override("v_separation", UITheme.SPACING_SM)
	g.mouse_filter = Control.MOUSE_FILTER_PASS
	g.custom_minimum_size = Vector2(280, 500)
	return g

func _build_weight_bar() -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0.0
	b.max_value = 100.0
	b.value = 0.0
	b.custom_minimum_size = Vector2(0, 18)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.show_percentage = false
	# 使用 Theme 的统一样式（progress_fill / progress_bg 由 ui.tres 提供）
	return b

func _build_close_button() -> Button:
	var b := Button.new()
	b.text = "关闭并整理 (ESC / T)"
	b.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_MD)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	# 关闭按钮样式（accent_primary 半透明）
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(UITheme.COLOR_ACCENT_PRIMARY.r, UITheme.COLOR_ACCENT_PRIMARY.g, UITheme.COLOR_ACCENT_PRIMARY.b, 0.25)
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.border_width_top = 1
	btn_style.border_width_bottom = 1
	btn_style.border_color = UITheme.COLOR_ACCENT_PRIMARY
	btn_style.corner_radius_top_left = 6
	btn_style.corner_radius_top_right = 6
	btn_style.corner_radius_bottom_left = 6
	btn_style.corner_radius_bottom_right = 6
	btn_style.content_margin_left = UITheme.SPACING_LG
	btn_style.content_margin_right = UITheme.SPACING_LG
	btn_style.content_margin_top = 6
	btn_style.content_margin_bottom = 6
	b.add_theme_stylebox_override("normal", btn_style)
	b.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	b.pressed.connect(close_and_pack)
	return b

# ============================================================
# 输入：ESC / T 关闭
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("mouse_capture_exit") or event.is_action_pressed("backpack"):
		close_and_pack()
		get_viewport().set_input_as_handled()
