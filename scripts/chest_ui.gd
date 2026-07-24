extends Control
## issue 08（ADR 015）：宝箱 3 选 1 奖励 UI
##
## 由 chest.gd 调用 open(choices, chest_ref) 显示 3 个奖励选项。
## 玩家选 1 → 调用 chest.apply_reward_selected(reward_id)（由 chest 发信号 + queue_free，
## RunDirector 监听 chest_reward_selected 信号后 apply 奖励）。
## process_mode = WHEN_PAUSED（暂停期间可点击）；无 ESC 取消（宝箱必须开）。

var _chest: Node3D  # 当前宝箱实例引用（选择后回调用）
var _card_buttons: Array = []  # Array[Button]

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

## 由 chest.gd 调用：显示 3 选 1 奖励卡
func open(choices: Array, chest_ref: Node3D) -> void:
	_chest = chest_ref
	_show_cards(choices)
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_card_pressed(choice: Dictionary) -> void:
	var id = choice.get("id", &"")
	# 先隐藏 UI + 恢复鼠标（避免与后续升级 UI 冲突）
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# 通知宝箱实例：发 chest_reward_selected 信号 + queue_free；
	# RunDirector 监听信号后 apply 奖励（可能级联触发升级）
	if _chest and is_instance_valid(_chest) and _chest.has_method("apply_reward_selected"):
		_chest.apply_reward_selected(id)
	_chest = null

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
	l.add_theme_font_size_override("font_size", 36)
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
	_card_buttons.clear()
	for choice in choices:
		var btn := Button.new()
		btn.text = "%s\n\n%s" % [str(choice.get("name", "")), str(choice.get("desc", ""))]
		btn.custom_minimum_size = Vector2(240, 280)
		btn.add_theme_font_size_override("font_size", 20)
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		btn.pressed.connect(_on_card_pressed.bind(choice))
		_card_container.add_child(btn)
		_card_buttons.append(btn)
