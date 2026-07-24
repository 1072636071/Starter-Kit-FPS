extends CanvasLayer

# 右下角弹药 HUD（T2/T3/T4/T5）
# - 纵向列出所有武器：`武器名 弹匣 / 备弹`
# - 当前武器行高亮（亮白），其余半透明灰
# - 弹匣+备弹均 0 时显示红色「空」
# - 当前武器换弹时该行内显示进度条（HUD 自驱动 Tween，与 player 的 reload_time 同步）

const HIGHLIGHT_COLOR := Color(1, 1, 1, 1)
const DIM_COLOR := Color(1, 1, 1, 0.35)
const EMPTY_COLOR := Color(1, 0.27, 0.27, 1)

var _weapons: Array = [] # Array[Weapon]
# 每行的子节点引用：name_label / ammo_label / progress
var _rows: Array = [] # Array[Dictionary]
var _current_index := 0
var _reload_tween: Tween

@onready var _list: VBoxContainer = _build_list()

func _ready() -> void:
	add_child(_list)
	# 延迟一帧绑定 player，确保 player._ready 已初始化 weapons 与弹药
	call_deferred("_bind_player")

func _bind_player() -> void:
	var player := get_node_or_null("../Player")
	if player == null:
		return
	if not player.has_signal("ammo_updated"):
		return
	_weapons = player.weapons
	_build_rows()
	player.ammo_updated.connect(_on_ammo_updated)
	player.reload_started.connect(_on_reload_started)
	player.reload_ended.connect(_on_reload_ended)
	# 用 player 当前快照做首次渲染
	_on_ammo_updated(player.weapon_index, player.magazine.duplicate(), player.reserve.duplicate())

func _build_list() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.name = "AmmoList"
	# 锚定右下角的小框（约 200×180），而非全屏拉伸
	vbox.anchor_left = 1.0
	vbox.anchor_top = 1.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = -220.0
	vbox.offset_top = -200.0
	vbox.offset_right = -20.0
	vbox.offset_bottom = -20.0
	vbox.grow_horizontal = 0
	vbox.grow_vertical = 0
	vbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return vbox

func _build_rows() -> void:
	for child in _list.get_children():
		child.queue_free()
	_rows.clear()

	for i in range(_weapons.size()):
		var w: Weapon = _weapons[i]
		# 每行是一个 VBox：[labels HBox, ProgressBar] —— 进度条属于该行内部
		var row_vbox := VBoxContainer.new()
		row_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_list.add_child(row_vbox)

		var labels := HBoxContainer.new()
		labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
		labels.alignment = BoxContainer.ALIGNMENT_END
		row_vbox.add_child(labels)

		var name_label := Label.new()
		name_label.text = w.display_name
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		labels.add_child(name_label)

		var ammo_label := Label.new()
		ammo_label.text = "0 / 0"
		ammo_label.add_theme_font_size_override("font_size", 22)
		ammo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		labels.add_child(ammo_label)

		var progress := ProgressBar.new()
		progress.min_value = 0.0
		progress.max_value = 1.0
		progress.value = 0.0
		progress.custom_minimum_size = Vector2(120, 8)
		progress.visible = false
		progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_vbox.add_child(progress)

		_rows.append({
			"name_label": name_label,
			"ammo_label": ammo_label,
			"progress": progress
		})

func _on_ammo_updated(weapon_index: int, magazines: Array, reserves: Array) -> void:
	_current_index = weapon_index
	for i in range(_rows.size()):
		var row: Dictionary = _rows[i]
		var name_label: Label = row["name_label"]
		var ammo_label: Label = row["ammo_label"]
		var mag: int = magazines[i] if i < magazines.size() else 0
		var res: int = reserves[i] if i < reserves.size() else 0

		var is_current := i == weapon_index
		if mag <= 0 and res <= 0:
			# 彻底空弹：红字「空」
			ammo_label.text = "空"
			ammo_label.add_theme_color_override("font_color", EMPTY_COLOR)
			name_label.add_theme_color_override("font_color", EMPTY_COLOR if is_current else DIM_COLOR)
		else:
			ammo_label.text = "%d / %d" % [mag, res]
			ammo_label.add_theme_color_override("font_color", HIGHLIGHT_COLOR if is_current else DIM_COLOR)
			name_label.add_theme_color_override("font_color", HIGHLIGHT_COLOR if is_current else DIM_COLOR)

func _on_reload_started(weapon_index: int, reload_time: float) -> void:
	# 只为当前正在换弹的武器行显示进度条
	for i in range(_rows.size()):
		var row: Dictionary = _rows[i]
		var progress: ProgressBar = row["progress"]
		if i == weapon_index:
			progress.visible = true
			progress.value = 0.0
			# 自驱动 Tween，与 player.reload_time 同步读满
			if _reload_tween and _reload_tween.is_valid():
				_reload_tween.kill()
			_reload_tween = create_tween()
			_reload_tween.tween_property(progress, "value", 1.0, reload_time)
		else:
			progress.visible = false
			progress.value = 0.0

func _on_reload_ended(weapon_index: int, cancelled: bool) -> void:
	for i in range(_rows.size()):
		var row: Dictionary = _rows[i]
		var progress: ProgressBar = row["progress"]
		progress.visible = false
		progress.value = 0.0
	if _reload_tween and _reload_tween.is_valid():
		_reload_tween.kill()

func _on_health_updated(health):
	$Health.text = str(health) + "%"
