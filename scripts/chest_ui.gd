extends Control
## issue 08（ADR 015）：宝箱 3 选 1 奖励 UI
## issue 03：重构为 UICard 组件 + UITheme token + UIMotion 过渡动效
##
## 由 chest.gd 调用 open(choices, chest_ref) 显示 3 个奖励选项（UICard）。
## 玩家选 1 → 调用 chest.apply_reward_selected(reward_id)（由 chest 发信号 + 延迟 queue_free，
## RunDirector 监听 chest_reward_selected 信号后 apply 奖励）。
## issue 24/28：随机武器满槽时监听 chest_weapon_replace_offered 信号，弹槽位替换对话框。
## process_mode = WHEN_PAUSED（暂停期间可点击）；无 ESC 取消（宝箱必须开）。

var _chest: Node3D  # 当前宝箱实例引用（选择后回调用）
var _cards: Array = []  # Array[UICard]
var _replace_dialog: Control = null  # issue 24：替换对话框引用
var _is_closing := false  # 防止 fade-out 期间重复触发

@onready var _bg: ColorRect = _build_bg()
@onready var _title: Label = _build_title()
@onready var _card_container: HBoxContainer = _build_card_container()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("chest_ui")
	add_child(_bg)
	add_child(_title)
	add_child(_card_container)
	# issue 24：监听 RunDirector 的替换武器信号
	_connect_replace_signal()

## 延迟连接到 RunDirector 的 chest_weapon_replace_offered 信号
func _connect_replace_signal() -> void:
	var rd := get_tree().get_first_node_in_group("run_director")
	if rd and rd.has_signal("chest_weapon_replace_offered"):
		if not rd.chest_weapon_replace_offered.is_connected(_on_chest_weapon_replace_offered):
			rd.chest_weapon_replace_offered.connect(_on_chest_weapon_replace_offered)

## 由 chest.gd 调用：显示 3 选 1 奖励卡
func open(choices: Array, chest_ref: Node3D) -> void:
	_chest = chest_ref
	_show_cards(choices)
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Modal 打开过渡：scale 0.96→1.0 + fade-in（180ms）
	UIMotion.tween_modal_in(self)

func _on_card_pressed(choice: Dictionary) -> void:
	if _is_closing:
		return
	_is_closing = true
	# 选中卡片已在 UICard 内部 set_pinned(true) 高亮蓝边
	# fade-out 过渡（120ms）→ 隐藏 → 通知宝箱
	var tween := UIMotion.tween_modal_out(self)
	await tween.finished
	var id = choice.get("id", &"")
	# 先隐藏 UI + 恢复鼠标（避免与后续升级 UI 冲突）
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# 通知宝箱实例：发 chest_reward_selected 信号；
	# RunDirector 监听信号后 apply 奖励（可能级联触发升级）
	if _chest and is_instance_valid(_chest) and _chest.has_method("apply_reward_selected"):
		_chest.apply_reward_selected(id)
	# random_weapon 的清理由 _finish_chest_reward() 处理（保留 _chest 引用）
	# 其他奖励类型由 chest 自身处理 queue_free
	if id != &"random_weapon":
		_chest = null
	_is_closing = false

# ============================================================
# UI 构建
# ============================================================

func _build_bg() -> ColorRect:
	var r := ColorRect.new()
	r.anchor_right = 1.0
	r.anchor_bottom = 1.0
	r.color = Color(0, 0, 0, 0.6)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r

func _build_title() -> Label:
	var l := Label.new()
	l.text = "宝箱奖励 — 选择一项"
	l.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_2XL)
	l.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	l.anchor_top = 0.15
	l.anchor_bottom = 0.15
	l.offset_left = -250
	l.offset_right = 250
	l.offset_top = -30
	l.offset_bottom = 30
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build_card_container() -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", UITheme.SPACING_LG)
	hbox.anchor_left = 0.5
	hbox.anchor_right = 0.5
	hbox.anchor_top = 0.5
	hbox.anchor_bottom = 0.5
	hbox.offset_left = -400
	hbox.offset_right = 400
	hbox.offset_top = -150
	hbox.offset_bottom = 150
	hbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return hbox

func _show_cards(choices: Array) -> void:
	for c in _card_container.get_children():
		c.queue_free()
	_cards.clear()
	for choice in choices:
		var icon_path := _chest_reward_icon_path(choice.get("id", &""))
		var card := UICard.new(
			str(choice.get("name", "")),
			str(choice.get("desc", "")),
			UITheme.get_icon(icon_path),
			UITheme.COLOR_ACCENT_PRIMARY
		)
		card.custom_minimum_size = Vector2(240, 280)
		card.pressed.connect(_on_card_pressed.bind(choice))
		_card_container.add_child(card)
		_cards.append(card)

## 宝箱奖励类型→图标映射
## coins → coins / health_pack → heart / xp → crosshair / ammo → package
## random_weapon → gun / grenade → flame
func _chest_reward_icon_path(id: Variant) -> String:
	match id:
		&"gold_bonus", &"coins":
			return UITheme.ICON_COINS
		&"heal_x3", &"health_pack":
			return UITheme.ICON_HEART
		&"xp_bonus", &"xp":
			return UITheme.ICON_CROSSHAIR
		&"ammo_refill", &"ammo":
			return UITheme.ICON_PACKAGE
		&"random_weapon":
			return UITheme.ICON_GUN
		&"grenade_supply", &"grenade":
			return UITheme.ICON_FLAME
		_:
			return UITheme.ICON_ZAP

# ============================================================
# issue 24：宝箱满槽替换对话框
# ============================================================

## 当 RunDirector 发射 chest_weapon_replace_offered 时调用
## weapon 为 null 表示奖励已直接装备（空槽），直接清理即可
## weapon 非 null 表示满槽需替换，弹出槽位选择对话框
func _on_chest_weapon_replace_offered(weapon: Weapon) -> void:
	if weapon == null:
		# 奖励已直接装备（有空槽），无需替换对话框，直接清理
		_finish_chest_reward()
		return

	if _replace_dialog and is_instance_valid(_replace_dialog):
		return  # 已有对话框，忽略

	var run_director := get_tree().get_first_node_in_group("run_director")
	if run_director == null:
		return

	# 从 RunDirector 获取槽位名列表，避免 chest_ui 直接钻取 player.weapons
	var slot_names: Array = []
	if run_director.has_method("get_weapon_slot_names"):
		slot_names = run_director.get_weapon_slot_names()

	var dialog := PanelContainer.new()
	dialog.name = "ChestReplaceDialog"
	dialog.anchor_left = 0.5
	dialog.anchor_right = 0.5
	dialog.anchor_top = 0.5
	dialog.anchor_bottom = 0.5
	dialog.offset_left = -180
	dialog.offset_right = 180
	dialog.offset_top = -140
	dialog.offset_bottom = 140
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.SPACING_SM)
	dialog.add_child(vbox)

	var title := Label.new()
	title.text = "宝箱开出：%s" % weapon.weapon_display_name
	title.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_LG)
	title.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "武器槽已满，选择替换的槽位："
	subtitle.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_MD)
	subtitle.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	# 每槽一个替换按钮（槽位名由 RunDirector 提供，chest_ui 只负责渲染）
	for i in range(slot_names.size()):
		var btn := Button.new()
		btn.text = "槽 %d：%s" % [(i + 1), slot_names[i]]
		btn.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_MD)
		btn.custom_minimum_size = Vector2(280, 36)
		btn.pressed.connect(func():
			if run_director.has_method("confirm_chest_weapon_replace"):
				run_director.confirm_chest_weapon_replace(i)
			_close_replace_dialog()
			_finish_chest_reward()
		)
		vbox.add_child(btn)

	# 取消按钮（拒绝替换，给金币补偿）
	var cancel_btn := Button.new()
	cancel_btn.text = "取消（获得 3 金补偿）"
	cancel_btn.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_MD)
	cancel_btn.custom_minimum_size = Vector2(280, 36)
	cancel_btn.pressed.connect(func():
		if run_director.has_method("cancel_chest_weapon_replace"):
			run_director.cancel_chest_weapon_replace()
		_close_replace_dialog()
		_finish_chest_reward()
	)
	vbox.add_child(cancel_btn)

	add_child(dialog)
	_replace_dialog = dialog

func _close_replace_dialog() -> void:
	if _replace_dialog and is_instance_valid(_replace_dialog):
		_replace_dialog.queue_free()
	_replace_dialog = null

## 清理并通知宝箱可安全销毁
func _finish_chest_reward() -> void:
	if _chest and is_instance_valid(_chest) and _chest.has_method("finish_reward"):
		_chest.finish_reward()
	_chest = null
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
