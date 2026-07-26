extends CanvasLayer

# ============================================================
# 现代化 HUD（issue 02）
# - UITheme token 取代硬编码颜色（HIGHLIGHT/DIM/EMPTY → COLOR_TEXT_PRIMARY/SECONDARY/ACCENT_DANGER）
# - SVG 图标取代 emoji（🪙⚡💥 → coins/zap/flame TextureRect）
# - 锚点 + 容器布局取代像素硬编码（HBox/VBox/MarginContainer）
# - UIMotion 动效（出现 / 数值变化 / 关键状态脉冲）
# ============================================================

# ── 状态 ─────────────────────────────────────────────────
var _weapons: Array = [] # Array[Weapon]
# 每行的子节点引用：name_label / ammo_label / progress / durability_bar / pulse_tween / bar
var _rows: Array = [] # Array[Dictionary]
var _current_index := 0
var _reload_tween: Tween

# issue 07：肉鸽竞技场 HUD 扩展
var _run_director: Node
var _player: Node
var _wave_number: int = 0

# 信息条 4 个数值 Label 引用（_refresh_info_label 用）
var _info_coin_value: Label
var _info_level_value: Label
var _info_wave_value: Label
var _info_kills_value: Label

# 护盾脉冲（归零警示）
var _shield_pulse_tween: Tween

# 提示词隐藏 token（防 race）
var _prompt_hide_tokens: Dictionary = {}
var _prev_packing: bool = false

# 武器检视 UI（TAB 打开）
var _weapon_inspect_ui: Control
# 背包 UI（ADR 023，T 键打开）
var _backpack_ui: Control
# 按键说明面板（ADR 024，F5 打开）
var _controls_help_ui: Control

# ── @onready 构建子控件 ─────────────────────────────────
# 顺序敏感：先构建容器，构建过程中会副作用赋值子控件引用
@onready var _info_bar: Control = _build_info_bar()
@onready var _shield_container: Control = _build_shield_container()
@onready var _shield_bar: ProgressBar
@onready var _shield_text: Label
@onready var _shield_cooldown_label: Label
@onready var _shield_rate_label: Label
@onready var _list: VBoxContainer = _build_list()
@onready var _grenade_container: Control = _build_grenade_container()
@onready var _minimap_frame: Control = _build_minimap_frame()
@onready var _minimap_coord_label: Label
@onready var _minimap_offscreen_icon: TextureRect
@onready var _wave_prompt: Label = _build_wave_prompt()
@onready var _chest_prompt: Label = _build_chest_prompt()
@onready var _stuck_prompt: Label = _build_stuck_prompt()
@onready var _packing_prompt: Label = _build_packing_prompt()

# 护盾条样式（正常 accent_primary / 冷却 warning）
var _shield_style_normal: StyleBoxFlat
var _shield_style_cooldown: StyleBoxFlat

# 手雷
var _grenade_emp_label: Label
var _grenade_frag_label: Label
var _grenade_emp_icon: TextureRect
var _grenade_frag_icon: TextureRect


# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	add_to_group("hud")
	# 子节点添加顺序：从底层到顶层
	add_child(_info_bar)
	add_child(_shield_container)
	add_child(_list)
	add_child(_grenade_container)
	add_child(_minimap_frame)
	add_child(_wave_prompt)
	add_child(_chest_prompt)
	add_child(_stuck_prompt)
	add_child(_packing_prompt)

	# UIMotion：HUD 元件入场动画（120ms 上滑 + 淡入）
	UIMotion.tween_in(_info_bar)
	UIMotion.tween_in(_shield_container)
	UIMotion.tween_in(_list)
	UIMotion.tween_in(_grenade_container)
	UIMotion.tween_in(_minimap_frame)

	# 外部 UI 脚本（不在本工单重构范围）
	_weapon_inspect_ui = _build_weapon_inspect_ui()
	add_child(_weapon_inspect_ui)
	_backpack_ui = _build_backpack_ui()
	add_child(_backpack_ui)
	_controls_help_ui = _build_controls_help_ui()
	add_child(_controls_help_ui)

	# 延迟一帧绑定 player，确保 player._ready 已初始化 weapons 与弹药
	call_deferred("_bind_player")
	# issue 07：绑定 RunDirector 信号
	call_deferred("_bind_run_director")


func _process(_delta: float) -> void:
	if _player and is_instance_valid(_player):
		# 整理中提示（按状态变化触发动画，避免每帧创建 tween）
		var is_packing: bool = _player.get("_is_packing") as bool
		if is_packing != _prev_packing:
			_prev_packing = is_packing
			_animate_prompt(_packing_prompt, is_packing)
		# 小地图坐标信息条更新
		if _minimap_coord_label:
			var pos: Vector3 = _player.global_position
			_minimap_coord_label.text = "X:%.0f  Z:%.0f" % [pos.x, pos.z]


# ============================================================
# 玩家与 RunDirector 信号绑定（保持原逻辑）
# ============================================================

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


# ============================================================
# 左上信息条：4 个图标-数值对（coins / Lv / 波次 / 击杀）
# JetBrains Mono 数字 + Rajdhani 标签，锚定左上角
# ============================================================

func _build_info_bar() -> Control:
	var container := Control.new()
	container.name = "InfoBar"
	# 锚定左上角 + SPACING_LG 边距
	container.anchor_left = 0.0
	container.anchor_top = 0.0
	container.anchor_right = 0.0
	container.anchor_bottom = 0.0
	container.offset_left = UITheme.SPACING_LG
	container.offset_top = UITheme.SPACING_LG
	container.offset_right = 600.0
	container.offset_bottom = UITheme.SPACING_LG + UITheme.FONT_SIZE_2XL
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hbox := HBoxContainer.new()
	hbox.name = "InfoHBox"
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.add_theme_constant_override("separation", UITheme.SPACING_XL)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(hbox)

	# 4 个图标-数值对：coins / Lv / 波次 / 击杀
	var coins_pair := _build_info_pair("CoinsPair", UITheme.ICON_COINS, "金币", "0")
	_info_coin_value = coins_pair.get_node("Value") as Label
	hbox.add_child(coins_pair)

	var level_pair := _build_info_pair("LevelPair", UITheme.ICON_CROSSHAIR, "Lv", "1")
	_info_level_value = level_pair.get_node("Value") as Label
	hbox.add_child(level_pair)

	var wave_pair := _build_info_pair("WavePair", UITheme.ICON_PACKAGE, "波次", "0")
	_info_wave_value = wave_pair.get_node("Value") as Label
	hbox.add_child(wave_pair)

	var kills_pair := _build_info_pair("KillsPair", UITheme.ICON_SWORD, "击杀", "0")
	_info_kills_value = kills_pair.get_node("Value") as Label
	hbox.add_child(kills_pair)

	return container


func _build_info_pair(pair_name: String, icon_path: String, label_text: String, value_text: String) -> HBoxContainer:
	var pair := HBoxContainer.new()
	pair.name = pair_name
	pair.add_theme_constant_override("separation", UITheme.SPACING_SM)
	pair.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# SVG 图标（modulate 着色为 accent_primary）
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = UITheme.get_icon(icon_path)
	icon.custom_minimum_size = Vector2(UITheme.FONT_SIZE_LG, UITheme.FONT_SIZE_LG)
	icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = UITheme.COLOR_ACCENT_PRIMARY
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pair.add_child(icon)

	# 标签（Rajdhani 默认字体）
	var label := Label.new()
	label.name = "Label"
	label.text = label_text
	label.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SM)
	label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pair.add_child(label)

	# 数值（JetBrains Mono 等宽）
	var value := Label.new()
	value.name = "Value"
	value.text = value_text
	value.add_theme_font_override("font", UITheme.get_font(UITheme.FONT_JETBRAINS_REGULAR))
	value.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_LG)
	value.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pair.add_child(value)

	return pair


# ============================================================
# 右下弹药列表：当前武器 accent_primary 左边竖条高亮
# JetBrains Mono 数字，空弹脉冲警示，换弹进度条 + 耐久度条
# ============================================================

func _build_list() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.name = "AmmoList"
	# 锚定右下角 + SPACING_XL 边距
	vbox.anchor_left = 1.0
	vbox.anchor_top = 1.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = -240.0
	vbox.offset_top = -220.0
	vbox.offset_right = -UITheme.SPACING_XL
	vbox.offset_bottom = -UITheme.SPACING_XL
	vbox.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	vbox.grow_vertical = Control.GROW_DIRECTION_BEGIN
	vbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_theme_constant_override("separation", UITheme.SPACING_SM)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return vbox


func _build_rows() -> void:
	for child in _list.get_children():
		child.queue_free()
	_rows.clear()

	for i in range(_weapons.size()):
		var w: Weapon = _weapons[i]
		# 每行是一个 VBox：[labels HBox, ProgressBar, DurabilityBar]
		var row_vbox := VBoxContainer.new()
		row_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_vbox.add_theme_constant_override("separation", UITheme.SPACING_XS)
		_list.add_child(row_vbox)

		# labels 行：[左边竖条, name, ammo]
		var labels := HBoxContainer.new()
		labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
		labels.add_theme_constant_override("separation", UITheme.SPACING_SM)
		labels.alignment = BoxContainer.ALIGNMENT_END
		row_vbox.add_child(labels)

		# 当前武器左边竖条（accent_primary 高亮）
		var bar := ColorRect.new()
		bar.name = "HighlightBar"
		bar.custom_minimum_size = Vector2(UITheme.SPACING_XS, UITheme.FONT_SIZE_LG)
		bar.color = UITheme.COLOR_ACCENT_PRIMARY
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		labels.add_child(bar)

		var name_label := Label.new()
		name_label.text = w.display_name
		name_label.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_LG)
		name_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		labels.add_child(name_label)

		var ammo_label := Label.new()
		ammo_label.text = "0 / 0"
		ammo_label.add_theme_font_override("font", UITheme.get_font(UITheme.FONT_JETBRAINS_REGULAR))
		ammo_label.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_LG)
		ammo_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)
		ammo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		labels.add_child(ammo_label)

		# 换弹进度条
		var progress := ProgressBar.new()
		progress.min_value = 0.0
		progress.max_value = 1.0
		progress.value = 0.0
		progress.custom_minimum_size = Vector2(120, UITheme.SPACING_SM)
		progress.visible = false
		progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_vbox.add_child(progress)

		# issue 20：耐久度条
		var durability_bar := ProgressBar.new()
		durability_bar.name = "DurabilityBar"
		durability_bar.min_value = 0.0
		durability_bar.max_value = 1.0
		durability_bar.value = 1.0
		durability_bar.custom_minimum_size = Vector2(120, UITheme.SPACING_XS)
		durability_bar.show_percentage = false
		durability_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_vbox.add_child(durability_bar)

		_rows.append({
			"name_label": name_label,
			"ammo_label": ammo_label,
			"progress": progress,
			"durability_bar": durability_bar,
			"bar": bar,
			"pulse_tween": null,
		})


func _on_ammo_updated(weapon_index: int, magazines: Array, reserves: Array) -> void:
	_current_index = weapon_index
	for i in range(_rows.size()):
		var row: Dictionary = _rows[i]
		var name_label: Label = row["name_label"]
		var ammo_label: Label = row["ammo_label"]
		var bar: ColorRect = row["bar"]
		var mag: int = magazines[i] if i < magazines.size() else 0
		var res: int = reserves[i] if i < reserves.size() else 0

		var is_current := i == weapon_index
		# 左边竖条：当前武器 accent_primary，其余透明
		bar.color = UITheme.COLOR_ACCENT_PRIMARY if is_current else Color(1, 1, 1, 0.0)

		if mag <= 0 and res <= 0:
			# 彻底空弹：accent_danger 红字「空」+ 脉冲警示
			ammo_label.text = "空"
			ammo_label.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_DANGER)
			name_label.add_theme_color_override("font_color",
				UITheme.COLOR_ACCENT_DANGER if is_current else UITheme.COLOR_TEXT_SECONDARY)
			_start_pulse(row, ammo_label, UITheme.COLOR_ACCENT_DANGER)
		else:
			ammo_label.text = "%d / %d" % [mag, res]
			ammo_label.add_theme_color_override("font_color",
				UITheme.COLOR_TEXT_PRIMARY if is_current else UITheme.COLOR_TEXT_SECONDARY)
			name_label.add_theme_color_override("font_color",
				UITheme.COLOR_TEXT_PRIMARY if is_current else UITheme.COLOR_TEXT_SECONDARY)
			_stop_pulse(row)

		# issue 20：更新耐久度条
		_update_durability_bar(row, i, is_current)

	# issue 23：弹药更新时也刷新手雷 HUD（通过信号方式）
	if _player and is_instance_valid(_player) and _player.has_signal("grenades_changed"):
		_on_grenades_changed(_player.grenades, _player.selected_grenade_type)

	# 若武器检视 UI 打开，实时刷新弹药显示
	if _weapon_inspect_ui and is_instance_valid(_weapon_inspect_ui) and _weapon_inspect_ui.visible:
		if _weapon_inspect_ui.has_method("refresh_ammo"):
			_weapon_inspect_ui.refresh_ammo()


# 启动脉冲警示（仅在未运行时创建，避免重复）
func _start_pulse(row: Dictionary, control: Control, color: Color) -> void:
	var existing: Tween = row.get("pulse_tween", null)
	if existing != null and existing.is_valid():
		return
	row["pulse_tween"] = UIMotion.pulse_glow(control, color)


# 停止脉冲警示
func _stop_pulse(row: Dictionary) -> void:
	var existing: Tween = row.get("pulse_tween", null)
	if existing != null and existing.is_valid():
		existing.kill()
	row["pulse_tween"] = null


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
	# 颜色选择（委托给 Weapon 静态方法）
	var base_color := Weapon.durability_color(ratio)
	if is_current:
		base_color = base_color.lightened(0.15)
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


func _on_health_updated(health) -> void:
	if has_node("Health"):
		$Health.text = str(health) + "%"


# ============================================================
# issue 07：RunDirector 信号响应（保持原逻辑）
# ============================================================

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
	# 归零脉冲警示（accent_danger）
	if shield <= 0.0:
		if _shield_pulse_tween == null or not _shield_pulse_tween.is_valid():
			_shield_pulse_tween = UIMotion.pulse_glow(_shield_text, UITheme.COLOR_ACCENT_DANGER)
	else:
		if _shield_pulse_tween != null and _shield_pulse_tween.is_valid():
			_shield_pulse_tween.kill()
		_shield_pulse_tween = null

func _on_shield_cooldown_changed(timer: float) -> void:
	if timer > 0.0:
		_shield_cooldown_label.visible = true
		_shield_cooldown_label.text = "%.1fs" % timer
		# 冷却中护盾条变橙色（accent_warning）
		_shield_bar.add_theme_stylebox_override("fill", _shield_style_cooldown)
	else:
		_shield_cooldown_label.visible = false
		# 恢复 accent_primary
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
	if _info_coin_value:
		_info_coin_value.text = currency_str
	if _info_level_value:
		_info_level_value.text = "%d" % _run_director.level
	if _info_wave_value:
		_info_wave_value.text = "%d" % _wave_number
	if _info_kills_value:
		_info_kills_value.text = "%d" % _run_director.kills


# ============================================================
# 左下护盾条：shield 图标 + 数值 + 充能速率 + ProgressBar
# 冷却中变橙色倒计时，归零脉冲警示
# ============================================================

func _build_shield_container() -> Control:
	var container := Control.new()
	container.name = "ShieldContainer"
	# 锚定左下角 + SPACING_LG 边距
	container.anchor_left = 0.0
	container.anchor_top = 1.0
	container.anchor_right = 0.0
	container.anchor_bottom = 1.0
	container.offset_left = UITheme.SPACING_LG
	container.offset_top = -UITheme.SPACING_2XL - UITheme.SPACING_SM
	container.offset_right = 340.0
	container.offset_bottom = -UITheme.SPACING_LG
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 主行：[shield 图标, VBox[text / bar / rate], cooldown_label]
	var hbox := HBoxContainer.new()
	hbox.name = "ShieldHBox"
	hbox.add_theme_constant_override("separation", UITheme.SPACING_SM)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(hbox)

	# shield 图标（取代原 emoji-less 文字）
	var icon := TextureRect.new()
	icon.name = "ShieldIcon"
	icon.texture = UITheme.get_icon(UITheme.ICON_SHIELD)
	icon.custom_minimum_size = Vector2(UITheme.FONT_SIZE_2XL, UITheme.FONT_SIZE_2XL)
	icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = UITheme.COLOR_ACCENT_PRIMARY
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon)

	var info_vbox := VBoxContainer.new()
	info_vbox.name = "ShieldInfo"
	info_vbox.add_theme_constant_override("separation", UITheme.SPACING_XS)
	info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(info_vbox)

	# 数值文字（JetBrains Mono 等宽）
	_shield_text = Label.new()
	_shield_text.name = "ShieldText"
	_shield_text.text = "50 / 50"
	_shield_text.add_theme_font_override("font", UITheme.get_font(UITheme.FONT_JETBRAINS_REGULAR))
	_shield_text.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_MD)
	_shield_text.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	_shield_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(_shield_text)

	# 护盾 ProgressBar
	_shield_bar = ProgressBar.new()
	_shield_bar.name = "ShieldBar"
	_shield_bar.min_value = 0.0
	_shield_bar.max_value = 50.0
	_shield_bar.value = 50.0
	_shield_bar.show_percentage = false
	_shield_bar.custom_minimum_size = Vector2(200, UITheme.SPACING_SM)
	_shield_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shield_style_normal = StyleBoxFlat.new()
	_shield_style_normal.bg_color = UITheme.COLOR_ACCENT_PRIMARY
	_shield_style_cooldown = StyleBoxFlat.new()
	_shield_style_cooldown.bg_color = UITheme.COLOR_ACCENT_WARNING
	_shield_bar.add_theme_stylebox_override("fill", _shield_style_normal)
	info_vbox.add_child(_shield_bar)

	# 充能速率标签
	_shield_rate_label = Label.new()
	_shield_rate_label.name = "ShieldRate"
	_shield_rate_label.text = "10/s"
	_shield_rate_label.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SM)
	_shield_rate_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)
	_shield_rate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(_shield_rate_label)

	# 冷却倒计时标签（橙色警示）
	_shield_cooldown_label = Label.new()
	_shield_cooldown_label.name = "ShieldCooldown"
	_shield_cooldown_label.add_theme_font_override("font", UITheme.get_font(UITheme.FONT_JETBRAINS_REGULAR))
	_shield_cooldown_label.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SM)
	_shield_cooldown_label.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_WARNING)
	_shield_cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_shield_cooldown_label.visible = false
	_shield_cooldown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_shield_cooldown_label)

	return container


# ============================================================
# 中下提示词群：波次/宝箱/卡住/整理中提示
# Rajdhani SemiBold，滑入/滑出动效 120ms
# ============================================================

func _wave_prompt_text() -> String:
	var key_name := "F"
	var events := InputMap.action_get_events("start_wave")
	if events.size() > 0 and events[0] is InputEventKey:
		key_name = (events[0] as InputEventKey).as_text_physical_keycode()
	return "按 [%s] 开始下一波" % key_name


func _build_wave_prompt() -> Label:
	return _build_prompt("WavePrompt", _wave_prompt_text(), UITheme.FONT_SIZE_XL, 0.3, true)

func _build_chest_prompt() -> Label:
	return _build_prompt("ChestPrompt", "按 [E] 开启宝箱", UITheme.FONT_SIZE_XL, 0.62, false)

func _build_stuck_prompt() -> Label:
	return _build_prompt("StuckPrompt", "按 %s 尝试挣扎离开" % _stuck_key_name(), UITheme.FONT_SIZE_XL, 0.7, false)

func _build_packing_prompt() -> Label:
	return _build_prompt("PackingPrompt", "整理中…", UITheme.FONT_SIZE_LG, 0.5, false)


# 通用提示词构建：Rajdhani SemiBold + 居中锚点
func _build_prompt(node_name: String, text: String, font_size: int, anchor_y: float, default_visible: bool) -> Label:
	var l := Label.new()
	l.name = node_name
	l.text = text
	l.add_theme_font_override("font", UITheme.get_font(UITheme.FONT_RAJDHANI_SEMIBOLD))
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	l.anchor_top = anchor_y
	l.anchor_bottom = anchor_y
	l.offset_left = -250
	l.offset_right = 250
	l.offset_top = -25
	l.offset_bottom = 25
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.visible = default_visible
	return l


func show_chest_prompt(visible_val: bool) -> void:
	_animate_prompt(_chest_prompt, visible_val)


func show_wave_prompt(visible_val: bool) -> void:
	_wave_prompt.text = _wave_prompt_text()
	_animate_prompt(_wave_prompt, visible_val)


# 提示词滑入/滑出动效（120ms）+ 防 race token
func _animate_prompt(prompt: Label, visible_val: bool) -> void:
	if prompt == null:
		return
	var key := prompt.name
	if visible_val:
		prompt.visible = true
		_prompt_hide_tokens[key] = int(_prompt_hide_tokens.get(key, 0)) + 1
		UIMotion.tween_in(prompt)
	else:
		UIMotion.tween_out(prompt)
		_prompt_hide_tokens[key] = int(_prompt_hide_tokens.get(key, 0)) + 1
		var token: int = _prompt_hide_tokens[key]
		# 120ms 后真正隐藏（与 DURATION_HUD_OUT 对齐）
		await get_tree().create_timer(UIMotion.DURATION_HUD_OUT).timeout
		if int(_prompt_hide_tokens.get(key, 0)) == token:
			prompt.visible = false


# ============================================================
# issue 05：卡住提示（ADR 016）
# ============================================================

func _stuck_key_name() -> String:
	var events := InputMap.action_get_events("struggle")
	if events.size() > 0 and events[0] is InputEventKey:
		return (events[0] as InputEventKey).as_text_physical_keycode()
	return "G"  # 保底

func _on_stuck_state_changed(new_state) -> void:
	# StuckState.NORMAL = 0, STUCK = 1, ESCAPING = 2
	_animate_prompt(_stuck_prompt, new_state == 1)


# ============================================================
# issue 23：右下手雷 HUD（zap/flame 图标区分 EMP/破片）
# ============================================================

func _build_grenade_container() -> Control:
	var container := Control.new()
	container.name = "GrenadeContainer"
	# 锚定右下角，弹药列表左侧
	container.anchor_left = 1.0
	container.anchor_top = 1.0
	container.anchor_right = 1.0
	container.anchor_bottom = 1.0
	container.offset_left = -400.0
	container.offset_top = -200.0
	container.offset_right = -250.0
	container.offset_bottom = -UITheme.SPACING_XL
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vbox := VBoxContainer.new()
	vbox.name = "GrenadeVBox"
	vbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_theme_constant_override("separation", UITheme.SPACING_SM)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(vbox)

	# 标题
	var title := Label.new()
	title.text = "手雷"
	title.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_MD)
	title.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	# EMP 行（zap 图标）
	var emp_row := HBoxContainer.new()
	emp_row.name = "EMPRow"
	emp_row.add_theme_constant_override("separation", UITheme.SPACING_SM)
	emp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grenade_emp_icon = TextureRect.new()
	_grenade_emp_icon.name = "EMPIcon"
	_grenade_emp_icon.texture = UITheme.get_icon(UITheme.ICON_ZAP)
	_grenade_emp_icon.custom_minimum_size = Vector2(UITheme.FONT_SIZE_MD, UITheme.FONT_SIZE_MD)
	_grenade_emp_icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	_grenade_emp_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_grenade_emp_icon.modulate = UITheme.COLOR_TEXT_SECONDARY
	_grenade_emp_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emp_row.add_child(_grenade_emp_icon)
	_grenade_emp_label = Label.new()
	_grenade_emp_label.name = "EMPLabel"
	_grenade_emp_label.text = "EMP: 0"
	_grenade_emp_label.add_theme_font_override("font", UITheme.get_font(UITheme.FONT_JETBRAINS_REGULAR))
	_grenade_emp_label.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_MD)
	_grenade_emp_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)
	_grenade_emp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emp_row.add_child(_grenade_emp_label)
	vbox.add_child(emp_row)

	# 破片行（flame 图标）
	var frag_row := HBoxContainer.new()
	frag_row.name = "FragRow"
	frag_row.add_theme_constant_override("separation", UITheme.SPACING_SM)
	frag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grenade_frag_icon = TextureRect.new()
	_grenade_frag_icon.name = "FragIcon"
	_grenade_frag_icon.texture = UITheme.get_icon(UITheme.ICON_FLAME)
	_grenade_frag_icon.custom_minimum_size = Vector2(UITheme.FONT_SIZE_MD, UITheme.FONT_SIZE_MD)
	_grenade_frag_icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	_grenade_frag_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_grenade_frag_icon.modulate = UITheme.COLOR_TEXT_SECONDARY
	_grenade_frag_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frag_row.add_child(_grenade_frag_icon)
	_grenade_frag_label = Label.new()
	_grenade_frag_label.name = "FragLabel"
	_grenade_frag_label.text = "破片: 0"
	_grenade_frag_label.add_theme_font_override("font", UITheme.get_font(UITheme.FONT_JETBRAINS_REGULAR))
	_grenade_frag_label.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_MD)
	_grenade_frag_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)
	_grenade_frag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frag_row.add_child(_grenade_frag_label)
	vbox.add_child(frag_row)

	return container


# issue 23：手雷 HUD 刷新（信号驱动）
func _on_grenades_changed(grenades_dict: Dictionary, selected_type: StringName) -> void:
	var emp_count: int = grenades_dict.get(&"emp", 0)
	var frag_count: int = grenades_dict.get(&"frag", 0)
	_grenade_emp_label.text = "EMP: %d" % emp_count
	_grenade_frag_label.text = "破片: %d" % frag_count

	# 选中态高亮：accent_primary，未选中 text_secondary
	var emp_selected: bool = selected_type == &"emp"
	var frag_selected: bool = selected_type == &"frag"
	_grenade_emp_label.add_theme_color_override("font_color",
		UITheme.COLOR_ACCENT_PRIMARY if emp_selected else UITheme.COLOR_TEXT_SECONDARY)
	_grenade_frag_label.add_theme_color_override("font_color",
		UITheme.COLOR_ACCENT_PRIMARY if frag_selected else UITheme.COLOR_TEXT_SECONDARY)
	_grenade_emp_icon.modulate = UITheme.COLOR_ACCENT_PRIMARY if emp_selected else UITheme.COLOR_TEXT_SECONDARY
	_grenade_frag_icon.modulate = UITheme.COLOR_ACCENT_PRIMARY if frag_selected else UITheme.COLOR_TEXT_SECONDARY


# ============================================================
# 右上小地图：描边外框 + 坐标信息条 + 屏外敌人指示器（chevron-up 图标）
# ============================================================

func _build_minimap_frame() -> Control:
	var container := Control.new()
	container.name = "MinimapFrame"
	# 锚定右上角 + SPACING_LG 边距
	container.anchor_left = 1.0
	container.anchor_top = 0.0
	container.anchor_right = 1.0
	container.anchor_bottom = 0.0
	container.offset_left = -340.0
	container.offset_top = UITheme.SPACING_LG
	container.offset_right = -UITheme.SPACING_LG
	container.offset_bottom = 380.0
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 描边外框（PanelContainer + StyleBoxFlat 边框）
	var panel := PanelContainer.new()
	panel.name = "Frame"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)  # 透明填充（仅作边框）
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = UITheme.COLOR_ACCENT_PRIMARY
	panel.add_theme_stylebox_override("panel", style)
	container.add_child(panel)

	# 坐标信息条（底部，JetBrains Mono）
	_minimap_coord_label = Label.new()
	_minimap_coord_label.name = "CoordBar"
	_minimap_coord_label.text = "X:0  Z:0"
	_minimap_coord_label.add_theme_font_override("font", UITheme.get_font(UITheme.FONT_JETBRAINS_REGULAR))
	_minimap_coord_label.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SM)
	_minimap_coord_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)
	_minimap_coord_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_minimap_coord_label.anchor_left = 0.0
	_minimap_coord_label.anchor_top = 1.0
	_minimap_coord_label.anchor_right = 1.0
	_minimap_coord_label.anchor_bottom = 1.0
	_minimap_coord_label.offset_top = -UITheme.SPACING_2XL
	_minimap_coord_label.offset_bottom = -UITheme.SPACING_SM
	_minimap_coord_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_minimap_coord_label)

	# 屏外敌人指示器（chevron-up 图标，默认隐藏）
	_minimap_offscreen_icon = TextureRect.new()
	_minimap_offscreen_icon.name = "OffscreenIndicator"
	_minimap_offscreen_icon.texture = UITheme.get_icon(UITheme.ICON_CHEVRON_UP)
	_minimap_offscreen_icon.custom_minimum_size = Vector2(UITheme.FONT_SIZE_MD, UITheme.FONT_SIZE_MD)
	_minimap_offscreen_icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	_minimap_offscreen_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_minimap_offscreen_icon.modulate = UITheme.COLOR_ACCENT_DANGER
	_minimap_offscreen_icon.anchor_left = 0.5
	_minimap_offscreen_icon.anchor_top = 0.0
	_minimap_offscreen_icon.anchor_right = 0.5
	_minimap_offscreen_icon.anchor_bottom = 0.0
	_minimap_offscreen_icon.offset_left = -UITheme.FONT_SIZE_MD / 2.0
	_minimap_offscreen_icon.offset_top = UITheme.SPACING_SM
	_minimap_offscreen_icon.offset_right = UITheme.FONT_SIZE_MD / 2.0
	_minimap_offscreen_icon.offset_bottom = UITheme.SPACING_SM + UITheme.FONT_SIZE_MD
	_minimap_offscreen_icon.visible = false
	_minimap_offscreen_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_minimap_offscreen_icon)

	return container


# ============================================================
# 背包 UI（ADR 023，T 键打开）—— 不改动
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


# ============================================================
# 按键说明面板（F5 打开，ADR 024）—— 不改动
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
# 武器检视 UI（TAB 打开，ADR 022 配套）—— 不改动
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
