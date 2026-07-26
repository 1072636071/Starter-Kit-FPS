extends Control
## issue 06（ADR 014 / 015）：游戏结束界面
##
## 监听 RunDirector.game_over(stats) → 显示本局战绩（存活波数 / 击杀数 / 累计金币 / 达到等级）
## + "重开一局"按钮。process_mode = WHEN_PAUSED（暂停期间可点击）。
##
## 重开：get_tree().paused = false → reload_current_scene()（天然重置所有状态，无需手动 reset）。
## 暂停互斥：死亡优先级最高，显示时隐藏 shop/level-up UI。

var _run_director: Node

var _bg: ColorRect
var _title: Label
var _stats_panel: PanelContainer
var _stats_value_labels: Dictionary = {}
var _restart_btn: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	_bg = _build_bg()
	_title = _build_title()
	_stats_panel = _build_stats_panel()
	_restart_btn = _build_restart_btn()

	add_child(_bg)
	add_child(_title)
	add_child(_stats_panel)
	add_child(_restart_btn)
	call_deferred("_bind_run_director")

func _bind_run_director() -> void:
	# GameOver 挂在 HUD（CanvasLayer）下，HUD 在 Main 下，RunDirector 也在 Main 下
	var main := get_parent().get_parent() if get_parent() != null else null
	if main != null:
		_run_director = main.get_node_or_null("RunDirector")
	if _run_director == null and get_tree() != null:
		for n in get_tree().get_nodes_in_group("run_director"):
			if n and n.has_signal("game_over"):
				_run_director = n
				break
	if _run_director and _run_director.has_signal("game_over"):
		_run_director.game_over.connect(_on_game_over)

func _on_game_over(stats: Dictionary) -> void:
	# 设置战绩数值
	_stats_value_labels["wave"].text = str(int(stats.get("wave", 0)))
	_stats_value_labels["kills"].text = str(int(stats.get("kills", 0)))
	_stats_value_labels["copper"].text = str(int(stats.get("copper_earned_total", 0)))
	_stats_value_labels["level"].text = str(int(stats.get("level", 1)))

	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# 暂停互斥：死亡优先级最高，隐藏其它暂停 UI（shop/level-up）
	for n in get_tree().get_nodes_in_group("shop_ui"):
		if is_instance_valid(n):
			n.visible = false
	var hud := get_parent()
	if hud:
		var level_up := hud.get_node_or_null("LevelUp")
		if level_up:
			level_up.visible = false

	# 阶梯式过渡动效（不用 UIMotion.tween_modal_in）
	# ① 标题 fade-in 300ms
	_title.modulate.a = 0.0
	var t1 := create_tween()
	t1.set_trans(UIMotion.TRANS_TYPE)
	t1.set_ease(UIMotion.EASE_TYPE)
	t1.tween_property(_title, "modulate:a", 1.0, 0.3)

	# ② 战绩 slide-up + fade 400ms，延迟 300ms
	_stats_panel.modulate.a = 0.0
	_stats_panel.position.y += 20.0
	var t2 := create_tween()
	t2.set_trans(UIMotion.TRANS_TYPE)
	t2.set_ease(UIMotion.EASE_TYPE)
	t2.tween_interval(0.3)
	t2.set_parallel(true)
	t2.tween_property(_stats_panel, "modulate:a", 1.0, 0.4)
	t2.tween_property(_stats_panel, "position:y", _stats_panel.position.y - 20.0, 0.4)
	t2.set_parallel(false)

	# ③ 按钮 fade-in 200ms，延迟 700ms
	_restart_btn.modulate.a = 0.0
	var t3 := create_tween()
	t3.set_trans(UIMotion.TRANS_TYPE)
	t3.set_ease(UIMotion.EASE_TYPE)
	t3.tween_interval(0.7)
	t3.tween_property(_restart_btn, "modulate:a", 1.0, 0.2)

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

# ============================================================
# UI 构建
# ============================================================

func _build_bg() -> ColorRect:
	var bg_color := UITheme.COLOR_BG_BASE
	var r := ColorRect.new()
	r.anchor_right = 1.0
	r.anchor_bottom = 1.0
	r.color = Color(bg_color.r, bg_color.g, bg_color.b, 0.90)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r

func _build_title() -> Label:
	var l := Label.new()
	l.text = "游戏结束"
	l.add_theme_font_override("font", UITheme.get_font(UITheme.FONT_RAJDHANI_BOLD))
	l.add_theme_font_size_override("font_size", 64)
	l.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_DANGER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	l.anchor_top = 0.15
	l.anchor_bottom = 0.15
	l.offset_left = -300
	l.offset_right = 300
	l.offset_top = -40
	l.offset_bottom = 40
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build_stats_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.4
	panel.anchor_bottom = 0.4
	panel.offset_left = -200
	panel.offset_right = 200
	panel.offset_top = -150
	panel.offset_bottom = 150
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = UITheme.COLOR_BG_PANEL
	pstyle.corner_radius_top_left = 8
	pstyle.corner_radius_top_right = 8
	pstyle.corner_radius_bottom_left = 8
	pstyle.corner_radius_bottom_right = 8
	pstyle.content_margin_left = 24
	pstyle.content_margin_right = 24
	pstyle.content_margin_top = 16
	pstyle.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", pstyle)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.SPACING_MD)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	# 4 行战绩（图标 + 标签 + 数值）
	var rows := [
		{icon = UITheme.ICON_CROSSHAIR, label = "存活波次", key = "wave"},
		{icon = UITheme.ICON_SWORD,    label = "击杀数",   key = "kills"},
		{icon = UITheme.ICON_COINS,    label = "累计铜币", key = "copper"},
		{icon = UITheme.ICON_ZAP,      label = "达到等级", key = "level"},
	]
	for row in rows:
		var hbox := HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", UITheme.SPACING_SM)
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(hbox)

		# 图标
		var icon := TextureRect.new()
		icon.texture = UITheme.get_icon(row["icon"])
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.custom_minimum_size = Vector2(28, 28)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(icon)

		# 标签
		var lbl := Label.new()
		lbl.text = row["label"]
		lbl.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_LG)
		lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(lbl)

		# 数值
		var val := Label.new()
		val.text = "0"
		val.add_theme_font_override("font", UITheme.get_font(UITheme.FONT_JETBRAINS_BOLD))
		val.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_XL)
		val.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(val)

		_stats_value_labels[row["key"]] = val

	return panel

func _build_restart_btn() -> Button:
	var b := Button.new()
	b.text = "重开一局"
	b.icon = UITheme.get_icon(UITheme.ICON_CHEVRON_UP)
	b.add_theme_font_override("font", UITheme.get_font(UITheme.FONT_RAJDHANI_SEMIBOLD))
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	b.anchor_left = 0.5
	b.anchor_right = 0.5
	b.anchor_top = 0.78
	b.anchor_bottom = 0.78
	b.offset_left = -110
	b.offset_right = 110
	b.offset_top = -25
	b.offset_bottom = 25
	b.grow_horizontal = Control.GROW_DIRECTION_BOTH

	# accent_primary 描边样式
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = UITheme.COLOR_BG_PANEL
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.border_width_top = 1
	btn_style.border_width_bottom = 1
	btn_style.border_color = UITheme.COLOR_ACCENT_PRIMARY
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn_style.corner_radius_bottom_right = 4
	b.add_theme_stylebox_override("normal", btn_style)
	b.add_theme_stylebox_override("hover", btn_style)
	b.add_theme_stylebox_override("pressed", btn_style)

	b.pressed.connect(_on_restart_pressed)
	return b