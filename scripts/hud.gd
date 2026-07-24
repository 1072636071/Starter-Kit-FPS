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

# issue 07：肉鸽竞技场 HUD 扩展
var _run_director: Node
var _wave_number: int = 0

@onready var _list: VBoxContainer = _build_list()
@onready var _shield_bar: ProgressBar = _build_shield_bar()
@onready var _info_label: Label = _build_info_label()
@onready var _wave_prompt: Label = _build_wave_prompt()
@onready var _chest_prompt: Label = _build_chest_prompt()

func _ready() -> void:
	add_child(_list)
	# issue 07：新增 HUD 元素
	add_child(_shield_bar)
	add_child(_info_label)
	add_child(_wave_prompt)
	add_child(_chest_prompt)
	# 延迟一帧绑定 player，确保 player._ready 已初始化 weapons 与弹药
	call_deferred("_bind_player")
	# issue 07：绑定 RunDirector 信号
	call_deferred("_bind_run_director")

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

# ============================================================
# issue 07：RunDirector 信号绑定与响应
# ============================================================

func _bind_run_director() -> void:
	var main := get_parent()
	if main:
		_run_director = main.get_node_or_null("RunDirector")
	if _run_director == null:
		return
	_run_director.gold_changed.connect(_on_gold_changed)
	_run_director.xp_changed.connect(_on_xp_changed)
	_run_director.wave_started.connect(_on_wave_started)
	_run_director.wave_cleared.connect(_on_wave_cleared)
	_run_director.kills_changed.connect(_on_kills_changed)
	# 初始状态：波 0 Intermission，显示开局提示
	show_wave_prompt(true)

func _on_gold_changed(amount: int) -> void:
	update_gold(amount)

func _on_xp_changed(amount: int, threshold: int) -> void:
	update_xp(amount, threshold)

func _on_wave_started(wave_number: int) -> void:
	_wave_number = wave_number
	update_wave(wave_number)
	show_wave_prompt(false)

func _on_wave_cleared(wave_number: int, _cleared_by_timeout: bool) -> void:
	show_wave_prompt(true)

func _on_kills_changed(count: int) -> void:
	update_kills(count)

func _on_shield_updated(shield: float, shield_max: float) -> void:
	_shield_bar.max_value = shield_max
	_shield_bar.value = shield

# ============================================================
# issue 07：公共更新方法（暂停态 UI 显式调用刷新）
# ============================================================

func update_gold(amount: int) -> void:
	_refresh_info_label()

func update_xp(_amount: int, _threshold: int) -> void:
	_refresh_info_label()

func update_level(new_level: int) -> void:
	_refresh_info_label()

func update_wave(wave_number: int) -> void:
	_wave_number = wave_number
	_refresh_info_label()

func update_kills(count: int) -> void:
	_refresh_info_label()

func _refresh_info_label() -> void:
	if _run_director == null:
		return
	_info_label.text = "金币: %d   Lv.%d   波次: %d   击杀: %d" % [
		_run_director.gold, _run_director.level, _wave_number, _run_director.kills]

# ============================================================
# issue 07：新增 HUD 元素构建
# ============================================================

func _build_shield_bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.offset_left = 48.0
	bar.offset_top = 596.0
	bar.offset_right = 248.0
	bar.offset_bottom = 618.0
	bar.min_value = 0.0
	bar.max_value = 50.0
	bar.value = 50.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.5, 0.85, 0.9)
	bar.add_theme_stylebox_override("fill", sb)
	return bar

func _build_info_label() -> Label:
	var l := Label.new()
	l.text = "金币: 0   Lv.1   波次: 0   击杀: 0"
	l.add_theme_font_size_override("font_size", 22)
	l.offset_left = 20.0
	l.offset_top = 20.0
	l.offset_right = 620.0
	l.offset_bottom = 55.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _wave_prompt_text() -> String:
	var key_name := "F"
	var events := InputMap.action_get_events("start_wave")
	if events.size() > 0 and events[0] is InputEventKey:
		key_name = (events[0] as InputEventKey).as_text_physical_keycode()
	return "按 [%s] 开始下一波" % key_name

func _build_wave_prompt() -> Label:
	var l := Label.new()
	l.text = _wave_prompt_text()
	l.add_theme_font_size_override("font_size", 30)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	l.anchor_top = 0.3
	l.anchor_bottom = 0.3
	l.offset_left = -250
	l.offset_right = 250
	l.offset_top = -25
	l.offset_bottom = 25
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.visible = true
	return l

func _build_chest_prompt() -> Label:
	var l := Label.new()
	l.text = "按 [E] 开启宝箱"
	l.add_theme_font_size_override("font_size", 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	l.anchor_top = 0.62
	l.anchor_bottom = 0.62
	l.offset_left = -200
	l.offset_right = 200
	l.offset_top = -20
	l.offset_bottom = 20
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.visible = false
	return l

func show_chest_prompt(show: bool) -> void:
	_chest_prompt.visible = show

func show_wave_prompt(show: bool) -> void:
	_wave_prompt.text = _wave_prompt_text()
	_wave_prompt.visible = show
