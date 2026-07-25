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
# 每行的子节点引用：name_label / ammo_label / progress / durability_bar
var _rows: Array = [] # Array[Dictionary]
var _current_index := 0
var _reload_tween: Tween

# issue 07：肉鸽竞技场 HUD 扩展
var _run_director: Node
var _player: Node
var _wave_number: int = 0

@onready var _list: VBoxContainer = _build_list()
@onready var _shield_container: Control = _build_shield_container()
@onready var _shield_bar: ProgressBar
@onready var _shield_text: Label
@onready var _shield_cooldown_label: Label
@onready var _shield_rate_label: Label
@onready var _info_label: Label = _build_info_label()
@onready var _wave_prompt: Label = _build_wave_prompt()
@onready var _chest_prompt: Label = _build_chest_prompt()
@onready var _stuck_prompt: Label = _build_stuck_prompt()

# issue 23：手雷 HUD 元素
@onready var _grenade_container: Control = _build_grenade_container()

# 武器检视 UI（TAB 打开）
var _weapon_inspect_ui: Control

# 背包 UI（ADR 023，T 键打开）
var _backpack_ui: Control
var _packing_prompt: Label

# 按键说明面板（ADR 024，F5 打开）
var _controls_help_ui: Control

func _ready() -> void:
	add_to_group("hud")
	add_child(_list)
	# issue 07：新增 HUD 元素
	add_child(_shield_container)
	add_child(_info_label)
	add_child(_wave_prompt)
	add_child(_chest_prompt)
	# issue 05：卡住提示
	add_child(_stuck_prompt)
	# issue 23：手雷显示
	add_child(_grenade_container)

	# 武器检视 UI（ADR 022 配套，TAB 打开）
	_weapon_inspect_ui = _build_weapon_inspect_ui()
	add_child(_weapon_inspect_ui)

	# 背包 UI（ADR 023，T 键打开）
	_backpack_ui = _build_backpack_ui()
	add_child(_backpack_ui)

	# 按键说明面板（ADR 024，F5 打开）
	_controls_help_ui = _build_controls_help_ui()
	add_child(_controls_help_ui)

	# 整理中提示
	_packing_prompt = _build_packing_prompt()
	add_child(_packing_prompt)

	# 延迟一帧绑定 player，确保 player._ready 已初始化 weapons 与弹药
	call_deferred("_bind_player")
	# issue 07：绑定 RunDirector 信号
	call_deferred("_bind_run_director")

# issue 23：手雷 HUD 由 player.grenades_changed 信号驱动，不再每帧轮询

func _bind_player() -> void:
	var player := get_node_or_null("../Player")
	if player == null:
		return
	if not player.has_signal("ammo_updated"):
		return
	_player = player
	_weapons = player.weapons
	_build_rows()
	if not player.ammo_updated.is_connected(_on_ammo_updated):
		player.ammo_updated.connect(_on_ammo_updated)
	if not player.reload_started.is_connected(_on_reload_started):
		player.reload_started.connect(_on_reload_started)
	if not player.reload_ended.is_connected(_on_reload_ended):
		player.reload_ended.connect(_on_reload_ended)
	# issue 05：卡住状态信号
	if player.has_signal("stuck_state_changed"):
		player.stuck_state_changed.connect(_on_stuck_state_changed)
	# 护盾 HUD 信号（先断开再连接防重复）
	if player.shield_updated.is_connected(_on_shield_updated):
		player.shield_updated.disconnect(_on_shield_updated)
	if player.shield_cooldown_changed.is_connected(_on_shield_cooldown_changed):
		player.shield_cooldown_changed.disconnect(_on_shield_cooldown_changed)
	player.shield_updated.connect(_on_shield_updated)
	player.shield_cooldown_changed.connect(_on_shield_cooldown_changed)
	# 初始护盾显示
	_on_shield_updated(player.shield, player.shield_max)
	_shield_rate_label.text = "%.0f/s" % (player.shield_regen_rate + player.shield_regen_rate_bonus)
	# 用 player 当前快照做首次渲染（issue 09：备弹经弹药池快照展开）
	_on_ammo_updated(player.weapon_index, player.magazine.duplicate(), player.get_reserves_snapshot())
	# issue 23：手雷 HUD 信号驱动
	if player.has_signal("grenades_changed"):
		player.grenades_changed.connect(_on_grenades_changed)
		# 首次渲染
		_on_grenades_changed(player.grenades, player.selected_grenade_type)

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
	vbox.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	vbox.grow_vertical = Control.GROW_DIRECTION_BEGIN
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

		# issue 20：耐久度条（武器名同宽，高 4px，在换弹进度条下方）
		var durability_bar := ProgressBar.new()
		durability_bar.name = "DurabilityBar"
		durability_bar.min_value = 0.0
		durability_bar.max_value = 1.0
		durability_bar.value = 1.0
		durability_bar.custom_minimum_size = Vector2(120, 4)
		durability_bar.show_percentage = false
		durability_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_vbox.add_child(durability_bar)

		_rows.append({
			"name_label": name_label,
			"ammo_label": ammo_label,
			"progress": progress,
			"durability_bar": durability_bar
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

		# issue 20：更新耐久度条
		_update_durability_bar(row, i, is_current)

	# issue 23：弹药更新时也刷新手雷 HUD（通过信号方式）
	if _player and is_instance_valid(_player) and _player.has_signal("grenades_changed"):
		_on_grenades_changed(_player.grenades, _player.selected_grenade_type)

	# 若武器检视 UI 打开，实时刷新弹药显示
	if _weapon_inspect_ui and is_instance_valid(_weapon_inspect_ui) and _weapon_inspect_ui.visible:
		if _weapon_inspect_ui.has_method("refresh_ammo"):
			_weapon_inspect_ui.refresh_ammo()

# issue 20：更新单行耐久度条
func _update_durability_bar(row: Dictionary, i: int, is_current: bool) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var bar: ProgressBar = row.get("durability_bar", null)
	if bar == null:
		return
	var durabilities: Array = _player.weapon_durability
	var weapons_arr: Array = _player.weapons
	if i >= weapons_arr.size() or i >= durabilities.size():
		bar.visible = false
		return
	var w: Weapon = weapons_arr[i]
	if w == null or w.durability_max <= 0:
		bar.visible = false
		return
	var ratio: float = float(durabilities[i]) / float(w.durability_max)
	bar.value = ratio
	bar.visible = true
	# 颜色选择（委托给 Weapon 静态方法，武器检视 UI 等也可复用）
	var base_color := Weapon.durability_color(ratio)
	# 当前武器略微提亮
	if is_current:
		base_color = base_color.lightened(0.15)
	# 设置填充样式
	var style := StyleBoxFlat.new()
	style.bg_color = base_color
	bar.add_theme_stylebox_override("fill", style)

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

func _on_reload_ended(_weapon_index: int, _cancelled: bool) -> void:
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
	_run_director.currency_changed.connect(_on_currency_changed)
	_run_director.xp_changed.connect(_on_xp_changed)
	_run_director.wave_started.connect(_on_wave_started)
	_run_director.wave_cleared.connect(_on_wave_cleared)
	_run_director.kills_changed.connect(_on_kills_changed)
	# 初始状态：波 0 Intermission，显示开局提示
	show_wave_prompt(true)
	_refresh_info_label()

func _on_currency_changed(_copper: int) -> void:
	_refresh_info_label()

func _on_xp_changed(amount: int, threshold: int) -> void:
	update_xp(amount, threshold)

func _on_wave_started(wave_number: int) -> void:
	_wave_number = wave_number
	update_wave(wave_number)
	show_wave_prompt(false)

func _on_wave_cleared(_wn: int, _cleared_by_timeout: bool) -> void:
	show_wave_prompt(true)

func _on_kills_changed(count: int) -> void:
	update_kills(count)

func _on_shield_updated(shield: float, shield_max: float) -> void:
	_shield_bar.max_value = shield_max
	_shield_bar.value = shield
	_shield_text.text = "%.0f / %.0f" % [shield, shield_max]

func _on_shield_cooldown_changed(timer: float) -> void:
	if timer > 0.0:
		_shield_cooldown_label.visible = true
		_shield_cooldown_label.text = "%.1fs" % timer
		# 冷却中护盾条变灰
		_shield_bar.add_theme_stylebox_override("fill", _shield_style_cooldown)
	else:
		_shield_cooldown_label.visible = false
		# 恢复蓝色
		_shield_bar.add_theme_stylebox_override("fill", _shield_style_normal)

# ============================================================
# issue 07：公共更新方法（暂停态 UI 显式调用刷新）
# ============================================================

func update_gold(_amount: int) -> void:
	_refresh_info_label()

func update_xp(_amount: int, _threshold: int) -> void:
	_refresh_info_label()

func update_level(_new_level: int) -> void:
	_refresh_info_label()

func update_wave(wave_number: int) -> void:
	_wave_number = wave_number
	_refresh_info_label()

func update_kills(_count: int) -> void:
	_refresh_info_label()

func _refresh_info_label() -> void:
	if _run_director == null:
		return
	var currency_str := ""
	if _run_director.has_method("format_currency"):
		currency_str = _run_director.format_currency()
	_info_label.text = "🪙 %s   Lv.%d   波次: %d   击杀: %d" % [
		currency_str, _run_director.level, _wave_number, _run_director.kills]

# ============================================================
# issue 07：新增 HUD 元素构建
# ============================================================

# 护盾条样式（正常蓝色 / 冷却灰色）
var _shield_style_normal: StyleBoxFlat
var _shield_style_cooldown: StyleBoxFlat

func _build_shield_container() -> Control:
	var container := Control.new()
	container.name = "ShieldContainer"
	container.offset_left = 8.0
	container.offset_top = 596.0
	container.offset_right = 320.0
	container.offset_bottom = 620.0
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 左侧冷却倒计时标签
	_shield_cooldown_label = Label.new()
	_shield_cooldown_label.name = "ShieldCooldown"
	_shield_cooldown_label.offset_left = 0.0
	_shield_cooldown_label.offset_top = 2.0
	_shield_cooldown_label.offset_right = 55.0
	_shield_cooldown_label.offset_bottom = 22.0
	_shield_cooldown_label.add_theme_font_size_override("font_size", 14)
	_shield_cooldown_label.add_theme_color_override("font_color", Color(1, 0.6, 0.2, 1))
	_shield_cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_shield_cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_shield_cooldown_label.visible = false
	_shield_cooldown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_shield_cooldown_label)

	# 护盾 ProgressBar
	_shield_bar = ProgressBar.new()
	_shield_bar.name = "ShieldBar"
	_shield_bar.offset_left = 58.0
	_shield_bar.offset_top = 0.0
	_shield_bar.offset_right = 258.0
	_shield_bar.offset_bottom = 22.0
	_shield_bar.min_value = 0.0
	_shield_bar.max_value = 50.0
	_shield_bar.value = 50.0
	_shield_bar.show_percentage = false
	_shield_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shield_style_normal = StyleBoxFlat.new()
	_shield_style_normal.bg_color = Color(0.15, 0.5, 0.85, 0.9)
	_shield_style_cooldown = StyleBoxFlat.new()
	_shield_style_cooldown.bg_color = Color(0.35, 0.35, 0.35, 0.9)
	_shield_bar.add_theme_stylebox_override("fill", _shield_style_normal)
	container.add_child(_shield_bar)

	# 条内文字（叠加在 ProgressBar 上）
	_shield_text = Label.new()
	_shield_text.name = "ShieldText"
	_shield_text.offset_left = 58.0
	_shield_text.offset_top = 0.0
	_shield_text.offset_right = 258.0
	_shield_text.offset_bottom = 22.0
	_shield_text.add_theme_font_size_override("font_size", 18)
	_shield_text.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_shield_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shield_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_shield_text.text = "50 / 50"
	_shield_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_shield_text)

	# 右侧充能速率标签
	_shield_rate_label = Label.new()
	_shield_rate_label.name = "ShieldRate"
	_shield_rate_label.offset_left = 262.0
	_shield_rate_label.offset_top = 2.0
	_shield_rate_label.offset_right = 312.0
	_shield_rate_label.offset_bottom = 22.0
	_shield_rate_label.add_theme_font_size_override("font_size", 14)
	_shield_rate_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1, 1))
	_shield_rate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_shield_rate_label.text = "10/s"
	_shield_rate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_shield_rate_label)

	return container

func _build_info_label() -> Label:
	var l := Label.new()
	l.text = "🪙 0铜   Lv.1   波次: 0   击杀: 0"
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

func show_chest_prompt(visible_val: bool) -> void:
	_chest_prompt.visible = visible_val

func show_wave_prompt(visible_val: bool) -> void:
	_wave_prompt.text = _wave_prompt_text()
	_wave_prompt.visible = visible_val

# ============================================================
# issue 05：卡住提示（ADR 016）
# ============================================================

func _stuck_key_name() -> String:
	var events := InputMap.action_get_events("struggle")
	if events.size() > 0 and events[0] is InputEventKey:
		return (events[0] as InputEventKey).as_text_physical_keycode()
	return "G"  # 保底

func _build_stuck_prompt() -> Label:
	var l := Label.new()
	l.text = "按 %s 尝试挣扎离开" % _stuck_key_name()
	l.add_theme_font_size_override("font_size", 28)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	l.anchor_top = 0.7
	l.anchor_bottom = 0.7
	l.offset_left = -200
	l.offset_right = 200
	l.offset_top = -20
	l.offset_bottom = 20
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.visible = false
	return l

func _on_stuck_state_changed(new_state) -> void:
	# StuckState.NORMAL = 0, STUCK = 1, ESCAPING = 2
	_stuck_prompt.visible = (new_state == 1)  # 仅 STUCK 时显示

# ============================================================
# issue 23：手雷 HUD 显示
# ============================================================

var _grenade_emp_label: Label
var _grenade_frag_label: Label
var _grenade_emp_icon: Label
var _grenade_frag_icon: Label

func _build_grenade_container() -> Control:
	var container := Control.new()
	container.name = "GrenadeContainer"
	# 放在弹药列表左侧
	container.anchor_left = 1.0
	container.anchor_top = 1.0
	container.anchor_right = 1.0
	container.anchor_bottom = 1.0
	container.offset_left = -380.0
	container.offset_top = -200.0
	container.offset_right = -230.0
	container.offset_bottom = -20.0
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vbox := VBoxContainer.new()
	vbox.name = "GrenadeVBox"
	vbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(vbox)

	# 标题
	var title := Label.new()
	title.text = "手雷"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	# EMP 行
	var emp_row := HBoxContainer.new()
	emp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grenade_emp_icon = Label.new()
	_grenade_emp_icon.text = "⚡"
	_grenade_emp_icon.add_theme_font_size_override("font_size", 18)
	_grenade_emp_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emp_row.add_child(_grenade_emp_icon)
	_grenade_emp_label = Label.new()
	_grenade_emp_label.text = "EMP: 0"
	_grenade_emp_label.add_theme_font_size_override("font_size", 18)
	_grenade_emp_label.add_theme_color_override("font_color", DIM_COLOR)
	_grenade_emp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emp_row.add_child(_grenade_emp_label)
	vbox.add_child(emp_row)

	# 破片行
	var frag_row := HBoxContainer.new()
	frag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grenade_frag_icon = Label.new()
	_grenade_frag_icon.text = "💥"
	_grenade_frag_icon.add_theme_font_size_override("font_size", 18)
	_grenade_frag_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frag_row.add_child(_grenade_frag_icon)
	_grenade_frag_label = Label.new()
	_grenade_frag_label.text = "破片: 0"
	_grenade_frag_label.add_theme_font_size_override("font_size", 18)
	_grenade_frag_label.add_theme_color_override("font_color", DIM_COLOR)
	_grenade_frag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frag_row.add_child(_grenade_frag_label)
	vbox.add_child(frag_row)

	return container

# issue 23：手雷 HUD 刷新（信号驱动，不再每帧轮询 _player）
func _on_grenades_changed(grenades_dict: Dictionary, selected_type: StringName) -> void:
	var emp_count: int = grenades_dict.get(&"emp", 0)
	var frag_count: int = grenades_dict.get(&"frag", 0)
	_grenade_emp_label.text = "EMP: %d" % emp_count
	_grenade_frag_label.text = "破片: %d" % frag_count

	# 高亮当前选中类型
	_grenade_emp_label.add_theme_color_override("font_color",
		HIGHLIGHT_COLOR if selected_type == &"emp" else DIM_COLOR)
	_grenade_frag_label.add_theme_color_override("font_color",
		HIGHLIGHT_COLOR if selected_type == &"frag" else DIM_COLOR)

# ============================================================
# 背包 UI（ADR 023，T 键打开）
# ============================================================

func _build_backpack_ui() -> Control:
	var scene := load("res://scripts/backpack_ui.gd") as GDScript
	if scene == null:
		return Control.new()
	var ui := scene.new() as Control
	ui.visible = false
	ui.mouse_filter = Control.MOUSE_FILTER_STOP
	return ui

func show_backpack_ui(player: Node3D) -> void:
	if _backpack_ui == null or not is_instance_valid(_backpack_ui):
		return
	if _backpack_ui.has_method("open"):
		_backpack_ui.open(player)

func _build_packing_prompt() -> Label:
	var l := Label.new()
	l.text = "整理中…"
	l.add_theme_font_size_override("font_size", 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	l.anchor_top = 0.5
	l.anchor_bottom = 0.5
	l.offset_left = -100
	l.offset_right = 100
	l.offset_top = -20
	l.offset_bottom = 20
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.visible = false
	return l

func _process(_delta: float) -> void:
	if _player and is_instance_valid(_player):
		_packing_prompt.visible = _player.get("_is_packing") as bool

# ============================================================
# 按键说明面板（F5 打开，ADR 024）
# ============================================================

func _build_controls_help_ui() -> Control:
	var scene := load("res://scripts/controls_help_ui.gd") as GDScript
	if scene == null:
		return Control.new()
	var ui := scene.new() as Control
	ui.visible = false
	ui.mouse_filter = Control.MOUSE_FILTER_STOP
	if ui.has_signal("closed"):
		ui.closed.connect(_on_controls_help_closed)
	return ui

func _on_controls_help_closed() -> void:
	# 仅当游戏未暂停时才恢复鼠标捕获
	if not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _can_open_controls_help() -> bool:
	if get_tree().paused:
		return false
	if _player == null or not is_instance_valid(_player):
		return false
	return true

# ============================================================
# 武器检视 UI（TAB 打开，ADR 022 配套）
# ============================================================

func _build_weapon_inspect_ui() -> Control:
	var scene := load("res://scenes/weapon_inspect_ui.tscn") as PackedScene
	if scene == null:
		return Control.new()
	var ui := scene.instantiate() as Control
	ui.visible = false
	ui.mouse_filter = Control.MOUSE_FILTER_STOP
	if ui.has_signal("closed"):
		ui.closed.connect(_on_weapon_inspect_closed)
	return ui

func _on_weapon_inspect_closed() -> void:
	# 仅当游戏未暂停时才恢复鼠标捕获
	if not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _can_open_weapon_inspect() -> bool:
	# 只在游戏进行中可用（非暂停、非死亡）
	if get_tree().paused:
		return false
	if _player == null or not is_instance_valid(_player):
		return false
	# 检查是否有其他 UI 打开
	var shop_uis := get_tree().get_nodes_in_group("shop_ui")
	for s in shop_uis:
		if s is Control and s.visible:
			return false
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_TAB and event.pressed:
		if _weapon_inspect_ui == null or not is_instance_valid(_weapon_inspect_ui):
			return
		if _weapon_inspect_ui.visible:
			_weapon_inspect_ui.close()
			get_viewport().set_input_as_handled()
			return
		if not _can_open_weapon_inspect():
			return
		if _player:
			_weapon_inspect_ui.open(_player)
			get_viewport().set_input_as_handled()
	if event is InputEventKey and event.physical_keycode == KEY_F5 and event.pressed and not event.echo:
		if _controls_help_ui == null or not is_instance_valid(_controls_help_ui):
			return
		if _controls_help_ui.visible:
			_controls_help_ui.close()
			get_viewport().set_input_as_handled()
			return
		if not _can_open_controls_help():
			return
		if _player:
			_controls_help_ui.open(_player)
			get_viewport().set_input_as_handled()
