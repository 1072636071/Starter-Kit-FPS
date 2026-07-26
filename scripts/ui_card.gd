class_name UICard
extends PanelContainer
## 共享卡片组件（issue 03：UI 现代化工单 03）
##
## 用于升级三选一、宝箱三选一、武器检视对比等"卡片选择"场景。
## 视觉：bg_panel 背景 + 4px 圆角 + 2px accent 描边
## 交互：hover scale 1.02，pressed scale 0.98，点击发射 pressed 信号
## 选中后通过 set_pinned(true) 高亮蓝边，set_delta 显示 ▲/▼ 差异指示。
##
## 接口稳定，工单 04/05 会依赖此组件。

## 卡片被点击时发射（无参数；外部用 .bind(choice) 携带业务数据）
signal pressed

## 当前样式盒（测试与外部读取边框色用）
var _stylebox: StyleBoxFlat
## 差异指示标签（测试读取其文本/可见性）
var _delta_label: Label

var _accent_color: Color
var _title_label: Label
var _description_label: Label
var _is_pressed: bool = false


## 构造函数：创建卡片 bg_panel 背景 + 4px 圆角 + 2px accent 描边
## 内部布局：VBox [TextureRect icon, Label title, Label description, Label delta]
func _init(title: String, description: String, icon: Texture2D, accent: Color) -> void:
	_accent_color = accent

	# StyleBox：bg_panel 背景 + 4px 圆角 + 2px accent 描边
	_stylebox = StyleBoxFlat.new()
	_stylebox.bg_color = UITheme.COLOR_BG_PANEL
	_stylebox.corner_radius_top_left = 4
	_stylebox.corner_radius_top_right = 4
	_stylebox.corner_radius_bottom_left = 4
	_stylebox.corner_radius_bottom_right = 4
	_stylebox.border_width_left = 2
	_stylebox.border_width_right = 2
	_stylebox.border_width_top = 2
	_stylebox.border_width_bottom = 2
	_stylebox.border_color = accent
	_stylebox.content_margin_left = UITheme.SPACING_LG
	_stylebox.content_margin_right = UITheme.SPACING_LG
	_stylebox.content_margin_top = UITheme.SPACING_LG
	_stylebox.content_margin_bottom = UITheme.SPACING_LG
	add_theme_stylebox_override("panel", _stylebox)

	# 内部布局：VBox [TextureRect icon, Label title, Label description, Label delta]
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.SPACING_SM)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)

	# 图标
	var icon_rect := TextureRect.new()
	icon_rect.texture = icon
	icon_rect.custom_minimum_size = Vector2(48, 48)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.modulate = accent
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon_rect)

	# 标题
	_title_label = Label.new()
	_title_label.text = title
	_title_label.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_LG)
	_title_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# 描述
	_description_label = Label.new()
	_description_label.text = description
	_description_label.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SM)
	_description_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.custom_minimum_size = Vector2(180, 0)
	vbox.add_child(_description_label)

	# 差异指示标签（默认隐藏，set_delta 时显示）
	_delta_label = Label.new()
	_delta_label.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SM)
	_delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_delta_label.visible = false
	vbox.add_child(_delta_label)

	# 鼠标交互（hover/pressed 由 _ready 连接信号）
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	# 在树中才连接鼠标信号（测试不进树也能用 set_pinned/set_delta）
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)


# ============================================================
# 公共接口
# ============================================================

## 设置对比参考高亮（蓝边）
## is_pinned=true 时边框变 COLOR_ACCENT_PRIMARY 蓝色
## is_pinned=false 时恢复为初始 accent 色
func set_pinned(is_pinned: bool) -> void:
	_stylebox.border_color = UITheme.COLOR_ACCENT_PRIMARY if is_pinned else _accent_color


## 设置差异指示 ▲/▼
## 在卡片底部添加/更新差异标签
## is_better=true 显示 ▲ 绿色(COLOR_ACCENT_PRIMARY)
## is_better=false 显示 ▼ 红色(COLOR_ACCENT_DANGER)
func set_delta(label_text: String, is_better: bool) -> void:
	var arrow := "▲" if is_better else "▼"
	var color := UITheme.COLOR_ACCENT_PRIMARY if is_better else UITheme.COLOR_ACCENT_DANGER
	_delta_label.text = "%s %s" % [arrow, label_text]
	_delta_label.add_theme_color_override("font_color", color)
	_delta_label.visible = true


## 获取卡片标题标签（供外部更新文本）
func get_title_label() -> Label:
	return _title_label


## 获取卡片描述标签（供外部更新文本）
func get_description_label() -> Label:
	return _description_label


# ============================================================
# 内部：hover/pressed 动效
# ============================================================

func _on_mouse_entered() -> void:
	if not _is_pressed:
		_tween_scale(Vector2(1.02, 1.02))


func _on_mouse_exited() -> void:
	if not _is_pressed:
		_tween_scale(Vector2.ONE)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_pressed = true
			_tween_scale(Vector2(0.98, 0.98))
		elif _is_pressed:
			_is_pressed = false
			# 选中后立即高亮（蓝边），方便玩家确认选择
			set_pinned(true)
			_tween_scale(Vector2.ONE)
			pressed.emit()


func _tween_scale(target: Vector2) -> void:
	# 缩放围绕卡片中心
	pivot_offset = size / 2.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", target, UIMotion.DURATION_HUD_IN)
