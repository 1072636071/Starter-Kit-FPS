extends Control
## 按键说明面板（ADR 024）
##
## 按 F5 弹出的暂停态模态面板，分组展示全部操作键位。
## 键名从 InputMap 动态读取，改键后自动同步。

signal closed

const KEY_MAP: Dictionary = {
	# 移动
	"move_forward":    {label = "前进",           group = "移动"},
	"move_back":       {label = "后退",           group = "移动"},
	"move_left":       {label = "左移",           group = "移动"},
	"move_right":      {label = "右移",           group = "移动"},
	"jump":            {label = "跳跃",           group = "移动"},
	# 战斗
	"shoot":           {label = "射击",           group = "战斗"},
	"aim":             {label = "瞄准（ADS）",    group = "战斗"},
	"reload":          {label = "换弹",           group = "战斗"},
	"melee":           {label = "近战",           group = "战斗"},
	"weapon_toggle":   {label = "切换武器",       group = "战斗"},
	"throw_grenade":   {label = "投掷手雷",       group = "战斗"},
	"grenade_switch":  {label = "切换手雷类型",   group = "战斗"},
	"drop_weapon":     {label = "丢枪",           group = "战斗"},
	# 系统
	"start_wave":      {label = "开始下一波",     group = "系统"},
	"struggle":        {label = "挣扎脱困",       group = "系统"},
	"backpack":        {label = "打开背包",       group = "系统"},
	"controls_help":   {label = "按键说明",       group = "系统"},
}

const GROUP_ORDER: Array[String] = ["移动", "战斗", "系统"]

const BG_COLOR := Color(0, 0, 0, 0.78)
const PANEL_BG := Color(0.08, 0.08, 0.14, 0.95)
const HEADER_COLOR := Color(1, 1, 1, 1)
const GROUP_COLOR := Color(0.35, 0.65, 0.95, 1)
const KEY_COLOR := Color(0.95, 0.85, 0.3, 1)
const LABEL_COLOR := Color(0.9, 0.9, 0.9, 1)
const HINT_COLOR := Color(0.45, 0.45, 0.5, 1)

var _open := false
var _we_paused := false
var _bg: ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

func is_open() -> bool:
	return _open

func open(_player: Node3D) -> void:
	if _open:
		return
	_open = true

	# 记录是否由我们触发的暂停
	if not get_tree().paused:
		get_tree().paused = true
		_we_paused = true
	else:
		_we_paused = false

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_ui()
	visible = true

func close() -> void:
	if not _open:
		return
	_open = false
	visible = false

	if _we_paused:
		get_tree().paused = false
		_we_paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif not get_tree().paused:
		# 游戏本身未暂停（其他 UI 可能已恢复），恢复鼠标
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	closed.emit()

# ============================================================
# 关闭方式
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventKey and event.physical_keycode == KEY_F5 and event.pressed and not event.echo:
		close()
		get_viewport().set_input_as_handled()

# ============================================================
# UI 构建
# ============================================================

func _build_ui() -> void:
	_bg = _make_bg()
	add_child(_bg)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# 居中，占屏幕 75% 宽、85% 高
	panel.anchor_left = 0.125
	panel.anchor_top = 0.075
	panel.anchor_right = 0.875
	panel.anchor_bottom = 0.925
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = PANEL_BG
	pstyle.corner_radius_top_left = 12
	pstyle.corner_radius_top_right = 12
	pstyle.corner_radius_bottom_left = 12
	pstyle.corner_radius_bottom_right = 12
	pstyle.content_margin_left = 24
	pstyle.content_margin_right = 24
	pstyle.content_margin_top = 20
	pstyle.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", pstyle)
	add_child(panel)

	var root := VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 14)
	panel.add_child(root)

	# 标题
	var title := Label.new()
	title.text = "按键说明"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", HEADER_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title)

	# 滚动区域
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(scroll)

	var groups_vbox := VBoxContainer.new()
	groups_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	groups_vbox.add_theme_constant_override("separation", 18)
	scroll.add_child(groups_vbox)

	# 按 GROUP_ORDER 分组渲染
	var entries_by_group := _group_entries()
	for group_name in GROUP_ORDER:
		var entries: Array = entries_by_group.get(group_name, [])
		if entries.is_empty():
			continue
		var group_box := _build_group_section(group_name, entries)
		groups_vbox.add_child(group_box)

	# 关闭提示
	var hint := Label.new()
	hint.text = "再按 F5 或点击背景关闭"
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", HINT_COLOR)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)

func _make_bg() -> ColorRect:
	var r := ColorRect.new()
	r.color = BG_COLOR
	r.anchor_left = 0.0
	r.anchor_top = 0.0
	r.anchor_right = 1.0
	r.anchor_bottom = 1.0
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	r.gui_input.connect(_on_bg_clicked)
	return r

func _on_bg_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
		get_viewport().set_input_as_handled()

# ============================================================
# 键位分组与渲染
# ============================================================

func _group_entries() -> Dictionary:
	var result: Dictionary = {}
	for group_name in GROUP_ORDER:
		result[group_name] = []
	for action_name in KEY_MAP:
		var entry: Dictionary = KEY_MAP[action_name]
		var group: String = entry["group"]
		if not result.has(group):
			result[group] = []
		var key_name := _key_display_for_action(action_name)
		result[group].append({label = entry["label"], key = key_name})
	return result

func _key_display_for_action(action_name: String) -> String:
	var events := InputMap.action_get_events(action_name)
	if events.is_empty():
		return "—"
	# 收集所有按键绑定的显示名
	var parts: Array[String] = []
	for ev in events:
		if ev is InputEventKey:
			parts.append(ev.as_text_physical_keycode())
		elif ev is InputEventMouseButton:
			parts.append(_mouse_button_name(ev.button_index))
	if parts.is_empty():
		# 可能只是手柄绑定，显示动作名
		return action_name
	return " / ".join(parts)

func _mouse_button_name(button_index: int) -> String:
	match button_index:
		1: return "鼠标左键"
		2: return "鼠标右键"
		3: return "鼠标中键"
		4: return "侧键上"
		5: return "侧键下"
		_: return "鼠标%d" % button_index

func _build_group_section(group_name: String, entries: Array) -> Control:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)

	var header := Label.new()
	header.text = "— %s —" % group_name
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", GROUP_COLOR)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(header)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)

	for entry in entries:
		var label := Label.new()
		label.text = entry["label"]
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", LABEL_COLOR)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.custom_minimum_size = Vector2(160, 0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(label)

		var key := Label.new()
		key.text = "[%s]" % entry["key"]
		key.add_theme_font_size_override("font_size", 20)
		key.add_theme_color_override("font_color", KEY_COLOR)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(key)

	return box
