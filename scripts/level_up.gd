extends Control
## issue 05：升级三选一 UI（ADR 011 / 015）
## issue 03：重构为 UICard 组件 + UITheme token + UIMotion 过渡动效
##
## 监听 RunDirector.level_up_offered(choices) → 显示 3 张升级卡（UICard）。
## 玩家点 1 → 调用 run_director.apply_upgrade(id) → 隐藏 UI。
## process_mode = WHEN_PAUSED（暂停期间可点击）；mouse mode 在显示/隐藏时切换。
##
## RunDirector 负责暂停/恢复，本 UI 只负责展示与回传选择。

var _run_director: Node
var _cards: Array = []  # Array[UICard]
var _choices: Array = []
var _is_closing := false  # 防止 fade-out 期间重复触发

@onready var _title: Label = _build_title()
@onready var _card_container: HBoxContainer = _build_card_container()

func _ready() -> void:
	# 暂停期间可交互
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_title)
	add_child(_card_container)
	# 延迟一帧绑定 RunDirector（确保 _ready 完成）
	call_deferred("_bind_run_director")

func _bind_run_director() -> void:
	# LevelUp 挂在 HUD（CanvasLayer）下，HUD 在 Main 下，RunDirector 也在 Main 下
	# 路径：LevelUp -> HUD -> Main -> RunDirector
	var main := get_parent().get_parent() if get_parent() != null else null
	if main != null:
		_run_director = main.get_node_or_null("RunDirector")
	if _run_director == null and get_tree() != null:
		# 回退：遍历树找有 level_up_offered 信号的节点
		for n in get_tree().get_nodes_in_group("run_director"):
			if n and n.has_signal("level_up_offered"):
				_run_director = n
				break
	if _run_director and _run_director.has_signal("level_up_offered"):
		_run_director.level_up_offered.connect(_on_level_up_offered)

func _build_title() -> Label:
	var label := Label.new()
	label.text = "升级！选择一项"
	label.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_2XL)
	label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.anchor_top = 0.15
	label.anchor_bottom = 0.15
	label.offset_left = -200
	label.offset_right = 200
	label.offset_top = -30
	label.offset_bottom = 30
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _build_card_container() -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", UITheme.SPACING_LG)
	hbox.anchor_left = 0.5
	hbox.anchor_right = 0.5
	hbox.anchor_top = 0.5
	hbox.anchor_bottom = 0.5
	hbox.offset_left = -360
	hbox.offset_right = 360
	hbox.offset_top = -150
	hbox.offset_bottom = 150
	hbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return hbox

func _on_level_up_offered(choices: Array) -> void:
	_choices = choices
	_show_cards(choices)
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Modal 打开过渡：scale 0.96→1.0 + fade-in（180ms）
	UIMotion.tween_modal_in(self)

func _show_cards(choices: Array) -> void:
	# 清空旧卡
	for c in _card_container.get_children():
		c.queue_free()
	_cards.clear()
	for choice in choices:
		var icon_path := _upgrade_icon_path(choice.get("id", &""))
		var card := UICard.new(
			str(choice.get("name", "")),
			str(choice.get("desc", "")),
			UITheme.get_icon(icon_path),
			UITheme.COLOR_ACCENT_PRIMARY
		)
		card.custom_minimum_size = Vector2(220, 280)
		card.pressed.connect(_on_card_pressed.bind(choice))
		_card_container.add_child(card)
		_cards.append(card)

## 升级类型→图标映射
## max_health → heart / shield_regen / shield_max → shield / damage → crosshair / 其他 → zap
func _upgrade_icon_path(id: Variant) -> String:
	match id:
		&"max_health":
			return UITheme.ICON_HEART
		&"shield_regen", &"shield_max":
			return UITheme.ICON_SHIELD
		&"damage":
			return UITheme.ICON_CROSSHAIR
		_:
			return UITheme.ICON_ZAP

func _on_card_pressed(choice: Dictionary) -> void:
	if _is_closing:
		return
	_is_closing = true
	# 选中卡片已在 UICard 内部 set_pinned(true) 高亮蓝边
	# fade-out 过渡（120ms）→ 隐藏 → 通知 RunDirector（apply 时解除暂停）
	var tween := UIMotion.tween_modal_out(self)
	await tween.finished
	var id = choice.get("id", &"")
	if _run_director and _run_director.has_method("apply_upgrade"):
		_run_director.apply_upgrade(id)
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_is_closing = false
