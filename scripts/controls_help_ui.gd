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

var _open := false
var _we_paused := false
var _bg: ColorRect
var _panel: Control

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
	if _panel:
		UIMotion.tween_modal_in(_panel)

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
	# 清理旧子节点
	for child in get_children():
		child.queue_free()
	_panel = null

	_bg = _make_bg()
	add_child(_bg)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# 居中，占屏幕 60% 宽、60% 高
	panel.anchor_left = 0.2
	panel.anchor_top = 0.2
	panel.anchor_right = 0.8
	panel.anchor_bottom = 0.8
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = UITheme.COLOR_BG_PANEL
	pstyle.corner_radius_top_left = 8
	pstyle.corner_radius_top_right = 8
	pstyle.corner_radius_bottom_left = 8
	pstyle.corner_radius_bottom_right = 8
	pstyle.content_margin_left = 24
	pstyle.content_margin_right = 24
	pstyle.content_margin_top = 20
	pstyle.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", pstyle)
	add_child(panel)
	_panel = panel

	var root := VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 14)
	panel.add_child(root)

	# 标题：图标 + 文字
	var title_hbox := HBoxContainer.new()
	title_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	title_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_hbox)

	var icon_rect := TextureRect.new()
	icon_rect.texture = UITheme.get_icon(UITheme.ICON_KEY)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_hbox.add_child(icon_rect)

	var title := Label.new()
	title.text = "按键说明"
	title.add_theme_font_override("font", UITheme.get_font(UITheme.FONT_RAJDHANI_BOLD))
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_hbox.add_child(title)

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
	hint.text = "按 F5 或点击外部关闭"
	hint.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_XS)
	hint.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)

func _make_bg() -> ColorRect:
	var bg_color := UITheme.COLOR_BG_BASE
	var r := ColorRect.new()
	r.color = Color(bg_color.r, bg_color.g, bg_color.b, 0.78)
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
	header.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_LG)
	header.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_PRIMARY)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(header)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)

	for entry in entries:
		# 描述标签
		var label := Label.new()
		label.text = entry["label"]
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.custom_minimum_size = Vector2(160, 0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(label)

		# kbd 样式键名
		var kbd := _make_kbd(entry["key"])
		grid.add_child(kbd)

	return box

func _make_kbd(key_text: String) -> PanelContainer:
	var kbd := PanelContainer.new()
	var kbd_style := StyleBoxFlat.new()
	kbd_style.bg_color = UITheme.COLOR_BG_PANEL_RAISED
	kbd_style.corner_radius_top_left = 4
	kbd_style.corner_radius_top_right = 4
	kbd_style.corner_radius_bottom_left = 4
	kbd_style.corner_radius_bottom_right = 4
	kbd_style.content_margin_left = 4
	kbd_style.content_margin_right = 4
	kbd_style.content_margin_top = 2
	kbd_style.content_margin_bottom = 2
	kbd.add_theme_stylebox_override("panel", kbd_style)
	kbd.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var key_label := Label.new()
	key_label.text = key_text
	key_label.add_theme_font_override("font", UITheme.get_font(UITheme.FONT_JETBRAINS_REGULAR))
	key_label.add_theme_font_size_override("font_size", 20)
	key_label.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_WARNING)
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kbd.add_child(key_label)

	return kbd