extends Control
## issue 22（ADR 022）：商店 UI 三区重构（武器 / 弹药 / 手雷）
## 工单04：UI 现代化 — UITheme token、SVG 图标、UIMotion 动效
##
## 由 ShopStation（Area3D）在玩家走入触发区时调用 open(player, run_director)：
##   - 武器区：随机 3 把不重复枪（从 weapons/ 目录 .tres 扫描）
##   - 弹药区：随机 3–4 种不重复弹种
##   - 手雷区：随机 1–2 种手雷
##   - 暂停期间可交互（process_mode = WHEN_PAUSED）
##   - ESC 关闭商店
##
## 购买逻辑：
##   - 武器：空槽→购买；满槽→购买并替换（弹窗选槽位）
##   - 弹药：backpack_add(type, "ammo", bundle_amount, weight)
##   - 手雷：grenades[type] += 1（上限 max_grenades）

signal closed

# ============================================================
# 弹药价格表（ADR 022）
# ============================================================
const AMMO_CONFIG: Dictionary = {
	&"手枪弹": {"bundle_amount": 24, "price": 24, "display": "手枪弹"},
	&"步枪弹": {"bundle_amount": 20, "price": 60, "display": "步枪弹"},
	&"霰弹":   {"bundle_amount": 8,  "price": 80, "display": "霰弹"},
	&"狙击弹": {"bundle_amount": 4,  "price": 80, "display": "狙击弹"},
	&"能量电池": {"bundle_amount": 12, "price": 60, "display": "能量电池"},
	&"榴弹":   {"bundle_amount": 2,  "price": 100, "display": "榴弹"},
}

const ALL_AMMO_TYPES: Array[StringName] = [&"手枪弹", &"步枪弹", &"霰弹", &"狙击弹", &"能量电池", &"榴弹"]

# 武器 3D 预览参数
const WEAPON_PREVIEW_SIZE := Vector2(80, 60)
const WEAPON_PREVIEW_ROTATE_SPEED := 0.6  # 弧度/秒，绕 Y 轴慢速旋转

# 手雷价格
const GRENADE_CONFIG: Dictionary = {
	&"emp":  {"display": "EMP",  "price": 3},
	&"frag": {"display": "破片", "price": 2},
}

var _player: Node3D
var _run_director: Node
var _open := false

# 本局随机刷新的商店库存
var _shop_weapons: Array[Weapon] = []
var _shop_ammo_types: Array[StringName] = []
var _shop_grenade_types: Array[StringName] = []

# 波次缓存：仅在波次变化时重新生成库存
var _shop_wave_generated: int = -1

# 替换对话框引用
var _replace_popup: Control
var _replace_weapon_idx: int = -1

# 背景遮罩 + 余额标签引用
var _bg_overlay: ColorRect
var _balance_label: Label

# UI 根节点引用
@onready var _panel: PanelContainer = _build_panel()
@onready var _scroll: ScrollContainer = _build_scroll()
@onready var _content: HBoxContainer = _build_content()
@onready var _title_bar: HBoxContainer = _build_title_bar()
@onready var _close_btn: Button = _build_close_button()

# 三个区的容器引用（每次 open 重建）
var _weapon_zone: VBoxContainer
var _ammo_zone: VBoxContainer
var _grenade_zone: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 全屏背景遮罩（bg_base 80% alpha）
	_bg_overlay = ColorRect.new()
	_bg_overlay.color = UITheme.COLOR_BG_BASE
	_bg_overlay.color.a = 0.80
	_bg_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg_overlay)

	# 面板
	add_child(_panel)
	var panel_vbox := VBoxContainer.new()
	panel_vbox.add_theme_constant_override("separation", 0)
	panel_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(panel_vbox)

	# 标题栏
	panel_vbox.add_child(_title_bar)
	# 分隔线
	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_vbox.add_child(sep)
	# 滚动区
	panel_vbox.add_child(_scroll)
	_scroll.add_child(_content)

	# 关闭按钮（绝对定位在面板右上角）
	_panel.add_child(_close_btn)

	add_to_group("shop_ui")

func _process(delta: float) -> void:
	if not _open:
		return
	# 驱动武器预览旋转
	for svp in _weapon_preview_rotators:
		var rotator: Node3D = _weapon_preview_rotators[svp]
		if is_instance_valid(rotator):
			rotator.rotate_y(WEAPON_PREVIEW_ROTATE_SPEED * delta)

func _on_currency_changed(_copper: int) -> void:
	if _open:
		_refresh_gold_label()
		_refresh_all_button_states()

# ============================================================
# 公共 API
# ============================================================

func is_open() -> bool:
	return _open

## 强制刷新商店库存（例如新波次开始时调用）
func force_refresh_on_next_open() -> void:
	_shop_wave_generated = -1

func open(player: Node3D, run_director: Node) -> void:
	if _open:
		return
	_player = player
	_run_director = run_director
	_open = true

	# 获取当前波次，仅在波次变化时重新生成库存
	var current_wave: int = _run_director.wave if _run_director else 0
	if current_wave != _shop_wave_generated:
		_generate_shop_stock()
		_shop_wave_generated = current_wave

	# 重建三区 UI
	_build_all_zones()

	_refresh_gold_label()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# 打开动效：scale 0.96→1.0 + fade-in
	UIMotion.tween_modal_in(self)

	if _run_director and _run_director.has_signal("currency_changed"):
		if not _run_director.currency_changed.is_connected(_on_currency_changed):
			_run_director.currency_changed.connect(_on_currency_changed)

func close() -> void:
	if not _open:
		return
	_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	visible = false
	closed.emit()

# ============================================================
# 库存生成（使用 run_director.rng）
# ============================================================

func _get_rng() -> RandomNumberGenerator:
	return _run_director.rng

func _generate_shop_stock() -> void:
	var rng := _get_rng()

	# --- 武器区：从 weapons/ 目录扫描所有 .tres，随机抽 3 把不重复 ---
	var all_weapons: Array[Weapon] = _scan_weapon_tres_files()
	_shop_weapons.assign(_pick_random_n(all_weapons, 3, rng))

	# --- 弹药区：随机抽 3–4 种不重复弹种 ---
	var ammo_count := rng.randi_range(3, 4)
	_shop_ammo_types.assign(_pick_random_n(ALL_AMMO_TYPES, ammo_count, rng))

	# --- 手雷区：随机 1–2 种 ---
	var grenade_types: Array[StringName] = [&"emp", &"frag"]
	var grenade_count := rng.randi_range(1, 2)
	_shop_grenade_types.assign(_pick_random_n(grenade_types, grenade_count, rng))

## 扫描 res://weapons/ 目录下所有 .tres 文件，加载为 Weapon 资源（委托给 WeaponUtils）
func _scan_weapon_tres_files() -> Array[Weapon]:
	return WeaponUtils.load_all_weapons()

## 从 arr 中随机抽 count 个不重复项
func _pick_random_n(arr: Array, count: int, rng: RandomNumberGenerator) -> Array:
	var pool := arr.duplicate()
	var result: Array = []
	var n := mini(count, pool.size())
	for _i in range(n):
		var idx := rng.randi_range(0, pool.size() - 1)
		result.append(pool[idx])
		pool.remove_at(idx)
	return result

# ============================================================
# UI 构建
# ============================================================

func _build_panel() -> PanelContainer:
	var p := PanelContainer.new()
	# 80% 视口居中
	p.anchor_left = 0.10
	p.anchor_top = 0.10
	p.anchor_right = 0.90
	p.anchor_bottom = 0.90
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	# bg_panel 背景 + 8px 圆角
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = UITheme.COLOR_BG_PANEL
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = UITheme.SPACING_LG
	panel_style.content_margin_right = UITheme.SPACING_LG
	panel_style.content_margin_top = UITheme.SPACING_MD
	panel_style.content_margin_bottom = UITheme.SPACING_MD
	p.add_theme_stylebox_override("panel", panel_style)
	return p

func _build_scroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	s.mouse_filter = Control.MOUSE_FILTER_PASS
	return s

func _build_content() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_BEGIN
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", UITheme.SPACING_XL)
	return h

func _build_title_bar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", UITheme.SPACING_SM)

	# store 图标
	var store_icon := TextureRect.new()
	store_icon.texture = UITheme.get_icon(UITheme.ICON_PACKAGE)
	store_icon.custom_minimum_size = Vector2(32, 32)
	store_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	store_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	store_icon.modulate = UITheme.COLOR_ACCENT_PRIMARY
	store_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(store_icon)

	# 标题 "军火商店"
	var title_lbl := Label.new()
	title_lbl.text = "军火商店"
	title_lbl.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_2XL)
	title_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	# Rajdhani Bold
	var bold_font: Font = load(UITheme.FONT_RAJDHANI_BOLD)
	title_lbl.add_theme_font_override("font", bold_font)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(title_lbl)

	# 弹性间距
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)

	# coins 图标
	var coins_icon := TextureRect.new()
	coins_icon.texture = UITheme.get_icon(UITheme.ICON_COINS)
	coins_icon.custom_minimum_size = Vector2(24, 24)
	coins_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coins_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coins_icon.modulate = UITheme.COLOR_ACCENT_PRIMARY
	coins_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(coins_icon)

	# 余额
	_balance_label = Label.new()
	_balance_label.text = "0"
	_balance_label.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_LG)
	_balance_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	_balance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_balance_label)

	return bar

func _build_close_button() -> Button:
	var b := Button.new()
	b.text = "✕"
	b.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_LG)
	b.custom_minimum_size = Vector2(32, 32)
	# 绝对定位：面板右上角
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 0.0
	b.anchor_bottom = 0.0
	b.offset_left = -40
	b.offset_right = -8
	b.offset_top = 8
	b.offset_bottom = 40
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	# 关闭按钮样式
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(UITheme.COLOR_ACCENT_DANGER, 0.2)
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn_style.corner_radius_bottom_right = 4
	b.add_theme_stylebox_override("normal", btn_style)
	var hover_style := btn_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(UITheme.COLOR_ACCENT_DANGER, 0.5)
	b.add_theme_stylebox_override("hover", hover_style)
	b.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	b.pressed.connect(close)
	return b

func _refresh_gold_label() -> void:
	if _run_director and _balance_label:
		_balance_label.text = _run_director.format_currency()

# ============================================================
# 三区构建
# ============================================================

func _build_all_zones() -> void:
	# 清除旧的区
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

	# 清空武器预览旋转器映射
	_weapon_preview_rotators.clear()

	_weapon_zone = null
	_ammo_zone = null
	_grenade_zone = null

	# 武器区
	_build_weapon_zone()

	# 弹药区
	_build_ammo_zone()

	# 手雷区
	_build_grenade_zone()

func _build_weapon_zone() -> void:
	_weapon_zone = VBoxContainer.new()
	_weapon_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weapon_zone.add_theme_constant_override("separation", UITheme.SPACING_SM)
	_weapon_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var header := _make_zone_header("═══ 武器区 ═══")
	_weapon_zone.add_child(header)
	_weapon_zone.add_child(_make_zone_separator())

	if _shop_weapons.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "（暂无武器库存）"
		empty_lbl.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_MD)
		empty_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)
		empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_weapon_zone.add_child(empty_lbl)
	else:
		for i in range(_shop_weapons.size()):
			var w: Weapon = _shop_weapons[i]
			var card := _build_weapon_card(w, i)
			_weapon_zone.add_child(card)

	_content.add_child(_weapon_zone)

func _build_weapon_card(w: Weapon, shop_idx: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# UICard-like 样式：bg_panel + 4px 圆角 + accent 描边
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = UITheme.COLOR_BG_PANEL_RAISED
	card_style.corner_radius_top_left = 4
	card_style.corner_radius_top_right = 4
	card_style.corner_radius_bottom_left = 4
	card_style.corner_radius_bottom_right = 4
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_color = UITheme.COLOR_ACCENT_PRIMARY
	card_style.content_margin_left = UITheme.SPACING_SM
	card_style.content_margin_right = UITheme.SPACING_SM
	card_style.content_margin_top = UITheme.SPACING_SM
	card_style.content_margin_bottom = UITheme.SPACING_SM
	card.add_theme_stylebox_override("panel", card_style)

	# 水平布局：3D 预览 | 武器信息 | 购买按钮
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UITheme.SPACING_SM)
	card.add_child(row)

	# 武器 3D 模型预览
	var preview := _build_weapon_preview(w)
	row.add_child(preview)

	# 武器信息列
	var info_vbox := VBoxContainer.new()
	info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_theme_constant_override("separation", UITheme.SPACING_XS)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_vbox)

	# 名称
	var name_lbl := Label.new()
	name_lbl.text = w.display_name
	name_lbl.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_LG)
	name_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(name_lbl)

	# 价格
	var price_lbl := Label.new()
	@warning_ignore("integer_division")
	var weapon_price_gold: int = w.weapon_cost / 10
	price_lbl.text = "%d 金" % weapon_price_gold
	price_lbl.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_MD)
	price_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)
	price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(price_lbl)

	# 弹药类型
	var ammo_lbl := Label.new()
	ammo_lbl.text = str(w.ammo_type)
	ammo_lbl.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SM)
	ammo_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)
	ammo_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(ammo_lbl)

	# 耐久度条
	var dura_bar := ProgressBar.new()
	dura_bar.name = "DurabilityBar"
	dura_bar.min_value = 0.0
	dura_bar.max_value = 1.0
	dura_bar.value = 1.0
	dura_bar.custom_minimum_size = Vector2(0, 10)
	dura_bar.show_percentage = false
	dura_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dura_style := StyleBoxFlat.new()
	dura_style.bg_color = UITheme.COLOR_ACCENT_PRIMARY
	dura_bar.add_theme_stylebox_override("fill", dura_style)
	info_vbox.add_child(dura_bar)

	# 购买按钮
	var has_empty_slot: bool = _player.weapons.size() < 3
	if has_empty_slot:
		var buy_btn := _make_styled_button("购买", UITheme.FONT_SIZE_MD, Vector2(70, 36))
		buy_btn.name = "BuyWeaponBtn"
		buy_btn.pressed.connect(_buy_weapon.bind(shop_idx))
		row.add_child(buy_btn)
	else:
		var replace_btn := _make_styled_button("购买并替换", UITheme.FONT_SIZE_SM, Vector2(110, 36))
		replace_btn.name = "ReplaceWeaponBtn"
		replace_btn.pressed.connect(_show_replace_popup.bind(shop_idx))
		row.add_child(replace_btn)

	return card

# ============================================================
# 武器 3D 模型预览（SubViewport + Camera3D，渲染层 2 隔离）
# ============================================================

func _build_weapon_preview(w: Weapon) -> SubViewportContainer:
	var svp := SubViewport.new()
	svp.size = WEAPON_PREVIEW_SIZE
	svp.transparent_bg = true
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	# 用 SubViewportContainer 包装，使其能参与 UI 布局（SubViewport 不是 Control）
	var container := SubViewportContainer.new()
	container.custom_minimum_size = WEAPON_PREVIEW_SIZE
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.stretch = true
	container.add_child(svp)

	# 相机
	var cam := Camera3D.new()
	cam.current = true
	cam.size = 1.5  # 正交模式下控制视野范围
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.cull_mask = 2  # 渲染层 2，与主场景隔离
	cam.position = Vector3(0, 0.3, 2.5)
	cam.look_at(Vector3(0, 0.2, 0))
	svp.add_child(cam)

	# 灯光
	var light := DirectionalLight3D.new()
	light.position = Vector3(2, 3, 3)
	light.look_at(Vector3(0, 0.2, 0))
	light.light_energy = 0.8
	light.light_cull_mask = 2
	svp.add_child(light)

	var ambient := DirectionalLight3D.new()
	ambient.position = Vector3(-2, 1, -1)
	ambient.look_at(Vector3(0, 0.2, 0))
	ambient.light_energy = 0.4
	ambient.light_cull_mask = 2
	svp.add_child(ambient)

	# 旋转根节点（用于缓慢旋转）
	var rotator := Node3D.new()
	rotator.name = "WeaponRotator"
	svp.add_child(rotator)

	# 实例化武器模型
	if w.model and is_instance_valid(w.model):
		var model_inst: Node3D = w.model.instantiate()
		model_inst.name = "WeaponModel"
		# 将模型及其子节点设置到渲染层 2
		_set_render_layer_recursive(model_inst, 2)
		rotator.add_child(model_inst)

	# 将 SubViewport 注册到旋转列表中
	if not _weapon_preview_rotators.has(svp):
		_weapon_preview_rotators[svp] = rotator

	return container

## 递归设置节点及其所有子节点的可见层
func _set_render_layer_recursive(node: Node, layer: int) -> void:
	if node is MeshInstance3D:
		node.layers = layer
	elif node is GeometryInstance3D:
		node.layers = layer
	for child in node.get_children():
		_set_render_layer_recursive(child, layer)

## 存储 SubViewport → 旋转 Node3D 的映射，用于 _process 中驱动旋转
var _weapon_preview_rotators: Dictionary = {}

# ============================================================
# 弹药区
# ============================================================

func _build_ammo_zone() -> void:
	_ammo_zone = VBoxContainer.new()
	_ammo_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ammo_zone.add_theme_constant_override("separation", UITheme.SPACING_SM)
	_ammo_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var header := _make_zone_header("═══ 弹药区 ═══")
	_ammo_zone.add_child(header)
	_ammo_zone.add_child(_make_zone_separator())

	if _shop_ammo_types.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "（暂无弹药库存）"
		empty_lbl.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_MD)
		empty_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)
		empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ammo_zone.add_child(empty_lbl)
	else:
		for ammo_type in _shop_ammo_types:
			var row := _build_ammo_row(ammo_type)
			_ammo_zone.add_child(row)

	_content.add_child(_ammo_zone)

func _build_ammo_row(ammo_type: StringName) -> HBoxContainer:
	var cfg: Dictionary = AMMO_CONFIG.get(ammo_type, {"bundle_amount": 0, "price": 999, "display": str(ammo_type)})
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UITheme.SPACING_SM)

	# SVG 弹药图标（替代 emoji）
	var icon_rect := TextureRect.new()
	icon_rect.texture = UITheme.get_icon(_get_ammo_icon_path(ammo_type))
	icon_rect.custom_minimum_size = Vector2(24, 24)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.modulate = UITheme.COLOR_ACCENT_PRIMARY
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_rect)

	# 弹药名
	var name_lbl := Label.new()
	name_lbl.name = "AmmoNameLabel"
	name_lbl.text = cfg["display"]
	name_lbl.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_MD)
	name_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	name_lbl.custom_minimum_size = Vector2(80, 0)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_lbl)

	# 捆量
	var bundle_lbl := Label.new()
	bundle_lbl.text = "×%d" % cfg["bundle_amount"]
	bundle_lbl.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_MD)
	bundle_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)
	bundle_lbl.custom_minimum_size = Vector2(50, 0)
	bundle_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bundle_lbl)

	# 价格（铜）
	var price_lbl := Label.new()
	price_lbl.text = "%d 铜" % cfg["price"]
	price_lbl.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_MD)
	price_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)
	price_lbl.custom_minimum_size = Vector2(50, 0)
	price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(price_lbl)

	# 当前储备量（从备弹槽计算）
	var reserve_lbl := Label.new()
	reserve_lbl.name = "AmmoReserveLabel"
	var current_reserve: int = _player.get_available_reloads(ammo_type) if _player else 0
	reserve_lbl.text = "当前: %d" % current_reserve
	reserve_lbl.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SM)
	reserve_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)
	reserve_lbl.custom_minimum_size = Vector2(90, 0)
	reserve_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(reserve_lbl)

	# 购买按钮
	var buy_btn := _make_styled_button("购买", UITheme.FONT_SIZE_MD, Vector2(70, 36))
	buy_btn.name = "BuyAmmoBtn"
	buy_btn.pressed.connect(_buy_ammo.bind(ammo_type))
	row.add_child(buy_btn)

	return row

## 弹种 → SVG 图标路径映射
func _get_ammo_icon_path(ammo_type: StringName) -> String:
	match ammo_type:
		&"能量电池": return UITheme.ICON_ZAP
		&"榴弹": return UITheme.ICON_FLAME
		_: return UITheme.ICON_CROSSHAIR

func _build_grenade_zone() -> void:
	_grenade_zone = VBoxContainer.new()
	_grenade_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grenade_zone.add_theme_constant_override("separation", UITheme.SPACING_SM)
	_grenade_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var header := _make_zone_header("═══ 手雷区 ═══")
	_grenade_zone.add_child(header)
	_grenade_zone.add_child(_make_zone_separator())

	if _shop_grenade_types.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "（暂无手雷库存）"
		empty_lbl.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_MD)
		empty_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)
		empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grenade_zone.add_child(empty_lbl)
	else:
		for grenade_type in _shop_grenade_types:
			var row := _build_grenade_row(grenade_type)
			_grenade_zone.add_child(row)

	_content.add_child(_grenade_zone)

func _build_grenade_row(grenade_type: StringName) -> HBoxContainer:
	var cfg: Dictionary = GRENADE_CONFIG.get(grenade_type, {"display": str(grenade_type), "price": 99})
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UITheme.SPACING_SM)

	# SVG 手雷图标
	var icon_path := UITheme.ICON_ZAP if grenade_type == &"emp" else UITheme.ICON_FLAME
	var icon_rect := TextureRect.new()
	icon_rect.texture = UITheme.get_icon(icon_path)
	icon_rect.custom_minimum_size = Vector2(24, 24)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.modulate = UITheme.COLOR_ACCENT_PRIMARY
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_rect)

	# 手雷名
	var name_lbl := Label.new()
	name_lbl.text = cfg["display"]
	name_lbl.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_MD)
	name_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	name_lbl.custom_minimum_size = Vector2(60, 0)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_lbl)

	# 价格（银）
	var price_lbl := Label.new()
	price_lbl.text = "%d 银" % cfg["price"]
	price_lbl.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_MD)
	price_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)
	price_lbl.custom_minimum_size = Vector2(60, 0)
	price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(price_lbl)

	# 当前持有
	var count_lbl := Label.new()
	count_lbl.name = "GrenadeCountLabel"
	var current_count: int = _player.grenades.get(grenade_type, 0) if _player else 0
	count_lbl.text = "持有: %d/%d" % [current_count, _player.max_grenades if _player else 5]
	count_lbl.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SM)
	count_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)
	count_lbl.custom_minimum_size = Vector2(90, 0)
	count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(count_lbl)

	# 购买按钮
	var buy_btn := _make_styled_button("购买", UITheme.FONT_SIZE_MD, Vector2(70, 36))
	buy_btn.name = "BuyGrenadeBtn"
	buy_btn.pressed.connect(_buy_grenade.bind(grenade_type))
	row.add_child(buy_btn)

	return row

func _make_zone_header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SM)
	l.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _make_zone_separator() -> HSeparator:
	var s := HSeparator.new()
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s

## 创建统一样式的购买按钮（accent_primary 色调）
func _make_styled_button(text: String, font_size: int = 18, min_size: Vector2 = Vector2(80, 36)) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.custom_minimum_size = min_size
	# accent_primary 按钮样式
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(UITheme.COLOR_ACCENT_PRIMARY, 0.15)
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.border_width_top = 1
	btn_style.border_width_bottom = 1
	btn_style.border_color = UITheme.COLOR_ACCENT_PRIMARY
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn_style.corner_radius_bottom_right = 4
	btn_style.content_margin_left = 10
	btn_style.content_margin_right = 10
	btn_style.content_margin_top = 4
	btn_style.content_margin_bottom = 4
	b.add_theme_stylebox_override("normal", btn_style)
	# hover 状态
	var hover_style := btn_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(UITheme.COLOR_ACCENT_PRIMARY, 0.25)
	b.add_theme_stylebox_override("hover", hover_style)
	b.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	return b

# ============================================================
# 武器购买逻辑
# ============================================================

func _buy_weapon(shop_idx: int) -> void:
	if not _open or _player == null or not is_instance_valid(_player):
		return
	if _run_director == null:
		return
	if shop_idx < 0 or shop_idx >= _shop_weapons.size():
		return

	var w: Weapon = _shop_weapons[shop_idx]
	@warning_ignore("integer_division")
	var price_copper: int = w.weapon_cost / 10 * 10000  # weapon_cost ÷ 10 为金币数，×10000 转铜
	@warning_ignore("integer_division")
	var weapon_price_gold: int = w.weapon_cost / 10

	# 检查货币
	if _run_director.copper < price_copper:
		_show_confirm_dialog("金币不足", "需要 %d 金，当前 %s。" % [weapon_price_gold, _run_director.format_currency()], false)
		return

	# 确认弹窗
	_show_confirm_dialog("购买武器", "确认购买 %s？\n价格: %d 金" % [w.display_name, weapon_price_gold], true, func():
		if not _run_director.spend_copper(price_copper):
			return

		# 找到第一个空槽
		var slot_idx := -1
		for i in range(3):
			if i >= _player.weapons.size():
				slot_idx = i
				break

		if slot_idx == -1:
			return  # 防御：不该走到这里

		# 添加到玩家武器数组
		_player.weapons.append(w)
		_player.weapon_durability.append(w.durability_max)
		# 送一弹匣量弹药到背包
		var weight_per_unit: float = _player.ITEM_WEIGHTS.get(w.ammo_type, 0.01)
		_player.backpack_add(w.ammo_type, &"ammo", w.magazine_size, weight_per_unit)
		# 通知弹药刷新
		if _player.has_method("_emit_ammo_updated"):
			_player._emit_ammo_updated()

		# 刷新 UI
		_build_all_zones()
		_refresh_gold_label()
		# 购买后自动打开背包显示物品和重量
		_open_backpack_after_purchase()
	)

func _show_replace_popup(shop_idx: int) -> void:
	if not _open or _player == null or not is_instance_valid(_player):
		return
	if shop_idx < 0 or shop_idx >= _shop_weapons.size():
		return
	var w: Weapon = _shop_weapons[shop_idx]
	@warning_ignore("integer_division")
	var price_copper: int = w.weapon_cost / 10 * 10000
	@warning_ignore("integer_division")
	var weapon_price_gold: int = w.weapon_cost / 10

	# 检查货币
	if _run_director.copper < price_copper:
		_show_confirm_dialog("金币不足", "需要 %d 金，当前 %s。" % [weapon_price_gold, _run_director.format_currency()], false)
		return

	_replace_weapon_idx = shop_idx

	# 构建替换弹窗（模态中模态，bg_base 95% alpha + 中央小卡片）
	if _replace_popup and is_instance_valid(_replace_popup):
		_replace_popup.queue_free()
	_replace_popup = null

	# 背景遮罩
	var popup_overlay := ColorRect.new()
	popup_overlay.color = UITheme.COLOR_BG_BASE
	popup_overlay.color.a = 0.95
	popup_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(popup_overlay)

	var popup := PanelContainer.new()
	popup.name = "ReplacePopup"
	popup.anchor_left = 0.25
	popup.anchor_top = 0.25
	popup.anchor_right = 0.75
	popup.anchor_bottom = 0.75
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	# 卡片样式
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = UITheme.COLOR_BG_PANEL
	popup_style.corner_radius_top_left = 8
	popup_style.corner_radius_top_right = 8
	popup_style.corner_radius_bottom_left = 8
	popup_style.corner_radius_bottom_right = 8
	popup_style.content_margin_left = UITheme.SPACING_LG
	popup_style.content_margin_right = UITheme.SPACING_LG
	popup_style.content_margin_top = UITheme.SPACING_LG
	popup_style.content_margin_bottom = UITheme.SPACING_LG
	popup.add_theme_stylebox_override("panel", popup_style)
	add_child(popup)

	var popup_vbox := VBoxContainer.new()
	popup_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	popup_vbox.add_theme_constant_override("separation", UITheme.SPACING_MD)
	popup_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(popup_vbox)

	var popup_title := Label.new()
	popup_title.text = "选择要替换的武器（购买 %s - %d 金）" % [w.display_name, weapon_price_gold]
	popup_title.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_LG)
	popup_title.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_vbox.add_child(popup_title)

	for i in range(_player.weapons.size()):
		var slot_w: Weapon = _player.weapons[i]
		var slot_row := HBoxContainer.new()
		slot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_row.add_theme_constant_override("separation", UITheme.SPACING_SM)

		var slot_lbl := Label.new()
		slot_lbl.text = "槽 %d: %s" % [i + 1, slot_w.display_name]
		slot_lbl.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_MD)
		slot_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
		slot_lbl.custom_minimum_size = Vector2(180, 0)
		slot_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_row.add_child(slot_lbl)

		var replace_btn := Button.new()
		replace_btn.text = "替换此槽"
		replace_btn.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SM)
		replace_btn.custom_minimum_size = Vector2(100, 36)
		replace_btn.pressed.connect(_confirm_replace.bind(i))
		slot_row.add_child(replace_btn)

		popup_vbox.add_child(slot_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_MD)
	cancel_btn.custom_minimum_size = Vector2(80, 36)
	cancel_btn.pressed.connect(_close_replace_popup)
	popup_vbox.add_child(cancel_btn)

	_replace_popup = popup

func _confirm_replace(slot_idx: int) -> void:
	var shop_idx := _replace_weapon_idx
	_close_replace_popup()

	if shop_idx < 0 or shop_idx >= _shop_weapons.size():
		return
	if slot_idx < 0 or slot_idx >= _player.weapons.size():
		return

	var w: Weapon = _shop_weapons[shop_idx]
	@warning_ignore("integer_division")
	var price_copper: int = w.weapon_cost / 10 * 10000

	# 扣铜币
	if not _run_director.spend_copper(price_copper):
		return

	# 替换：旧武器消失，新武器入槽
	_player.weapons[slot_idx] = w
	_player.weapon_durability[slot_idx] = w.durability_max
	_player.magazine[slot_idx] = w.magazine_size
	# 送一弹匣量弹药到背包
	var weight_per_unit: float = _player.ITEM_WEIGHTS.get(w.ammo_type, 0.01)
	_player.backpack_add(w.ammo_type, &"ammo", w.magazine_size, weight_per_unit)

	if _player.has_method("_emit_ammo_updated"):
		_player._emit_ammo_updated()

	_build_all_zones()
	_refresh_gold_label()
	# 购买后自动打开背包显示物品和重量
	_open_backpack_after_purchase()

func _close_replace_popup() -> void:
	# 关闭替换弹窗及其遮罩
	for child in get_children():
		if child is ColorRect and child != _bg_overlay:
			child.queue_free()
	if _replace_popup and is_instance_valid(_replace_popup):
		_replace_popup.queue_free()
	_replace_popup = null
	_replace_weapon_idx = -1

# ============================================================
# 弹药购买逻辑
# ============================================================

func _buy_ammo(ammo_type: StringName) -> void:
	if not _open or _player == null or not is_instance_valid(_player):
		return
	if _run_director == null:
		return

	var cfg: Dictionary = AMMO_CONFIG.get(ammo_type, {})
	if cfg.is_empty():
		return

	var bundle: int = cfg["bundle_amount"]
	var bundle_price: int = cfg["price"]
	var display: String = cfg["display"]
	var per_unit_price := ceili(float(bundle_price) / float(bundle))  # 单发价格

	# 弹出数量输入对话框
	_show_ammo_quantity_dialog(ammo_type, display, bundle, per_unit_price, bundle_price)


# ============================================================
# 手雷购买逻辑
# ============================================================

func _buy_grenade(grenade_type: StringName) -> void:
	if not _open or _player == null or not is_instance_valid(_player):
		return
	if _run_director == null:
		return

	var cfg: Dictionary = GRENADE_CONFIG.get(grenade_type, {})
	if cfg.is_empty():
		return

	var price: int = cfg["price"]
	var price_copper := price * 100  # 银转铜
	var display: String = cfg["display"]
	var current: int = _player.grenades.get(grenade_type, 0)
	var max_g: int = _player.max_grenades

	if current >= max_g:
		_show_confirm_dialog("已满", "%s 已达上限 %d。" % [display, max_g], false)
		return

	if _run_director.copper < price_copper:
		_show_confirm_dialog("银币不足", "需要 %d 银，当前 %s。" % [price, _run_director.format_currency()], false)
		return

	_show_confirm_dialog("购买手雷", "确认购买 %s？\n价格: %d 银\n持有: %d/%d → %d/%d" % [display, price, current, max_g, current + 1, max_g], true, func():
		if not _run_director.spend_copper(price_copper):
			return
		_player.grenades[grenade_type] = current + 1
		# 刷新手雷区数量标签
		_refresh_grenade_zone_count_labels()
		_refresh_gold_label()
		_refresh_all_button_states()
		# 购买后自动打开背包显示物品和重量
		_open_backpack_after_purchase()
	)

# ============================================================
# 确认弹窗
# ============================================================

func _show_confirm_dialog(title_text: String, body_text: String, show_confirm: bool, callback: Callable = Callable()) -> void:
	# 先关闭已有弹窗
	_close_replace_popup()
	for child in get_children():
		if child is PanelContainer and child.name == "ConfirmDialog":
			child.queue_free()

	var dialog := PanelContainer.new()
	dialog.name = "ConfirmDialog"
	dialog.anchor_left = 0.35
	dialog.anchor_top = 0.35
	dialog.anchor_right = 0.65
	dialog.anchor_bottom = 0.65
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	# 卡片样式
	var dialog_style := StyleBoxFlat.new()
	dialog_style.bg_color = UITheme.COLOR_BG_PANEL
	dialog_style.corner_radius_top_left = 8
	dialog_style.corner_radius_top_right = 8
	dialog_style.corner_radius_bottom_left = 8
	dialog_style.corner_radius_bottom_right = 8
	dialog_style.border_width_left = 1
	dialog_style.border_width_right = 1
	dialog_style.border_width_top = 1
	dialog_style.border_width_bottom = 1
	dialog_style.border_color = UITheme.COLOR_ACCENT_PRIMARY
	dialog_style.content_margin_left = UITheme.SPACING_LG
	dialog_style.content_margin_right = UITheme.SPACING_LG
	dialog_style.content_margin_top = UITheme.SPACING_LG
	dialog_style.content_margin_bottom = UITheme.SPACING_LG
	dialog.add_theme_stylebox_override("panel", dialog_style)
	add_child(dialog)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", UITheme.SPACING_MD)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = title_text
	title_lbl.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_XL)
	title_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_lbl)

	var body_lbl := Label.new()
	body_lbl.text = body_text
	body_lbl.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_MD)
	body_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(body_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", UITheme.SPACING_XL)
	btn_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(btn_row)

	if show_confirm:
		var confirm_btn := Button.new()
		confirm_btn.text = "确认"
		confirm_btn.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_LG)
		confirm_btn.custom_minimum_size = Vector2(100, 44)
		confirm_btn.pressed.connect(func():
			callback.call()
			dialog.queue_free()
		)
		btn_row.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_LG)
	cancel_btn.custom_minimum_size = Vector2(100, 44)
	cancel_btn.pressed.connect(func(): dialog.queue_free())
	btn_row.add_child(cancel_btn)

# ============================================================
# 弹药数量输入对话框
# ============================================================

## 弹出数量选择对话框，默认填充一捆数量，玩家可调整
func _show_ammo_quantity_dialog(ammo_type: StringName, display: String, default_amount: int, per_unit_price: int, _bundle_price: int) -> void:
	# 先关闭已有弹窗
	_close_replace_popup()
	for child in get_children():
		if child is PanelContainer and (child.name == "ConfirmDialog" or child.name == "QuantityDialog"):
			child.queue_free()

	var dialog := PanelContainer.new()
	dialog.name = "QuantityDialog"
	dialog.anchor_left = 0.3
	dialog.anchor_top = 0.25
	dialog.anchor_right = 0.7
	dialog.anchor_bottom = 0.75
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	# 卡片样式
	var dialog_style := StyleBoxFlat.new()
	dialog_style.bg_color = UITheme.COLOR_BG_PANEL
	dialog_style.corner_radius_top_left = 8
	dialog_style.corner_radius_top_right = 8
	dialog_style.corner_radius_bottom_left = 8
	dialog_style.corner_radius_bottom_right = 8
	dialog_style.border_width_left = 1
	dialog_style.border_width_right = 1
	dialog_style.border_width_top = 1
	dialog_style.border_width_bottom = 1
	dialog_style.border_color = UITheme.COLOR_ACCENT_PRIMARY
	dialog_style.content_margin_left = UITheme.SPACING_LG
	dialog_style.content_margin_right = UITheme.SPACING_LG
	dialog_style.content_margin_top = UITheme.SPACING_LG
	dialog_style.content_margin_bottom = UITheme.SPACING_LG
	dialog.add_theme_stylebox_override("panel", dialog_style)
	add_child(dialog)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", UITheme.SPACING_MD)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "购买 %s" % display
	title_lbl.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_XL)
	title_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_lbl)

	# 数量滑块
	var slider_row := HBoxContainer.new()
	slider_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slider_row.add_theme_constant_override("separation", UITheme.SPACING_MD)
	slider_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(slider_row)

	var minus_btn := Button.new()
	minus_btn.text = "-1"
	minus_btn.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_MD)
	minus_btn.custom_minimum_size = Vector2(44, 36)
	slider_row.add_child(minus_btn)

	# 最大可购买数量：受铜币和背包容量限制
	var max_affordable := int(_run_director.copper) / per_unit_price if per_unit_price > 0 else default_amount
	var max_by_weight := int((_player.backpack_max_weight - _player.backpack_weight) / _player.ITEM_WEIGHTS.get(ammo_type, 0.01))
	var max_amount := maxi(1, mini(max_affordable, maxi(max_by_weight, 1)))

	var amount_label := Label.new()
	amount_label.name = "QuantityLabel"
	var current_amount := mini(default_amount, max_amount)
	amount_label.text = "×%d 发" % current_amount
	amount_label.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_2XL)
	amount_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_label.custom_minimum_size = Vector2(120, 40)
	amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slider_row.add_child(amount_label)

	var plus_btn := Button.new()
	plus_btn.text = "+1"
	plus_btn.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_MD)
	plus_btn.custom_minimum_size = Vector2(44, 36)
	slider_row.add_child(plus_btn)

	# 快捷数量按钮行
	var quick_row := HBoxContainer.new()
	quick_row.alignment = BoxContainer.ALIGNMENT_CENTER
	quick_row.add_theme_constant_override("separation", UITheme.SPACING_SM)
	quick_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(quick_row)

	# 价格信息（提前声明，供 quick_row 按钮 lambda 引用）
	var price_info := Label.new()
	price_info.name = "PriceInfo"
	price_info.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_MD)
	price_info.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)
	price_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_info.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 确认按钮（提前声明，供 quick_row 按钮 lambda 引用）
	var confirm_btn := Button.new()
	confirm_btn.text = "确认购买"
	confirm_btn.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_LG)
	confirm_btn.custom_minimum_size = Vector2(120, 44)

	for qty in [default_amount, default_amount * 2, default_amount * 5]:
		if qty > max_amount:
			break
		var quick_btn := Button.new()
		quick_btn.text = "×%d" % qty
		quick_btn.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SM)
		quick_btn.custom_minimum_size = Vector2(60, 32)
		quick_btn.pressed.connect(func(a=qty): _set_ammo_quantity(amount_label, a, max_amount, per_unit_price, price_info, confirm_btn))
		quick_row.add_child(quick_btn)

	vbox.add_child(price_info)

	# 背包信息
	var weight_info := Label.new()
	weight_info.name = "WeightInfo"
	weight_info.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SM)
	weight_info.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)
	weight_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weight_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(weight_info)

	# 更新价格和重量显示
	_update_ammo_price_display(price_info, weight_info, current_amount, per_unit_price, ammo_type)

	# +/- 按钮事件（从标签文本解析当前数量，避免 lambda 捕获过期变量）
	minus_btn.pressed.connect(func():
		var cur := _parse_quantity_label(amount_label)
		_set_ammo_quantity(amount_label, cur - 1, max_amount, per_unit_price, price_info, confirm_btn))
	plus_btn.pressed.connect(func():
		var cur := _parse_quantity_label(amount_label)
		_set_ammo_quantity(amount_label, cur + 1, max_amount, per_unit_price, price_info, confirm_btn))

	# 确认/取消按钮
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", UITheme.SPACING_XL)
	btn_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(btn_row)

	confirm_btn.pressed.connect(func():
		# 从标签文本中解析当前数量（避免 lambda 捕获过期变量）
		var text: String = amount_label.text
		var qty := 1
		var num_str := text.replace("×", "").replace("发", "").strip_edges()
		if num_str.is_valid_int():
			qty = clampi(int(num_str), 1, max_amount)
		var total_price := qty * per_unit_price
		if not _run_director.spend_copper(total_price):
			return
		var weight_per_unit: float = _player.ITEM_WEIGHTS.get(ammo_type, 0.01)
		_player.backpack_add(ammo_type, &"ammo", qty, weight_per_unit)
		if _player.has_method("_emit_ammo_updated"):
			_player._emit_ammo_updated()
		_refresh_ammo_zone_reserve_labels()
		_refresh_gold_label()
		_refresh_all_button_states()
		# 购买后自动打开背包显示物品和重量
		_open_backpack_after_purchase()
		dialog.queue_free()
	)
	btn_row.add_child(confirm_btn)

	var cancel_btn2 := Button.new()
	cancel_btn2.text = "取消"
	cancel_btn2.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_LG)
	cancel_btn2.custom_minimum_size = Vector2(100, 44)
	cancel_btn2.pressed.connect(func(): dialog.queue_free())
	btn_row.add_child(cancel_btn2)

	# 初始化价格显示
	_update_ammo_price_display(price_info, weight_info, current_amount, per_unit_price, ammo_type)

func _set_ammo_quantity(label: Label, amount: int, max_amount: int, per_unit_price: int, price_info: Label, confirm_btn: Button) -> void:
	var clamped := clampi(amount, 1, max_amount)
	label.text = "×%d 发" % clamped
	_update_ammo_price_display(price_info, null, clamped, per_unit_price, &"")

## 从数量标签 "×24 发" 中解析整数值
func _parse_quantity_label(label: Label) -> int:
	var text: String = label.text
	var num_str := text.replace("×", "").replace("发", "").strip_edges()
	if num_str.is_valid_int():
		return int(num_str)
	return 1

func _update_ammo_price_display(price_info: Label, weight_info: Label, amount: int, per_unit_price: int, ammo_type: StringName) -> void:
	var total_price := amount * per_unit_price
	if _run_director:
		price_info.text = "总价: %d 铜 (%s)" % [total_price, _run_director.format_currency(total_price)]
	else:
		price_info.text = "总价: %d 铜" % total_price
	if _run_director and _run_director.copper < total_price:
		price_info.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_DANGER)
	else:
		price_info.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)

	if weight_info:
		var wpu: float = _player.ITEM_WEIGHTS.get(ammo_type, 0.01)
		var total_w := amount * wpu
		weight_info.text = "重量: %.2f  |  背包: %.1f / %.1f" % [total_w, _player.backpack_weight, _player.backpack_max_weight]
		if _player.backpack_weight + total_w > _player.backpack_max_weight:
			weight_info.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_DANGER)
		else:
			weight_info.add_theme_color_override("font_color", UITheme.COLOR_TEXT_SECONDARY)

## 购买后自动打开背包 UI，让玩家查看物品和剩余重量
func _open_backpack_after_purchase() -> void:
	var hud_node := get_tree().get_first_node_in_group("hud")
	if hud_node and hud_node.has_method("show_backpack_ui"):
		# 延迟一点打开，避免和商店 UI 冲突
		hud_node.show_backpack_ui.call_deferred(_player)

# ============================================================
# 刷新辅助方法
# ============================================================

func _refresh_ammo_zone_reserve_labels() -> void:
	_refresh_zone_labels(_ammo_zone, "AmmoReserveLabel", _shop_ammo_types,
		AMMO_CONFIG, func(ammo_type: StringName) -> String:
			var reserve: int = _player.get_available_reloads(ammo_type) if _player else 0
			return "换弹次数: %d" % reserve)

func _refresh_grenade_zone_count_labels() -> void:
	_refresh_zone_labels(_grenade_zone, "GrenadeCountLabel", _shop_grenade_types,
		GRENADE_CONFIG, func(grenade_type: StringName) -> String:
			var count: int = _player.grenades.get(grenade_type, 0) if _player else 0
			var max_g: int = _player.max_grenades if _player else 5
			return "持有: %d/%d" % [count, max_g])

## 通用标签刷新：遍历 zone 中每个 HBoxContainer 行，找到 target_label_name 标签，
## 通过 display 名反向匹配 shop_types 中的类型，调用 format_func 生成新文本。
func _refresh_zone_labels(zone: VBoxContainer, target_label_name: String,
		shop_types: Array, config: Dictionary, format_func: Callable) -> void:
	if zone == null:
		return
	for row in zone.get_children():
		if not row is HBoxContainer:
			continue
		var target_label: Label = null
		var name_label: Label = null
		for child in row.get_children():
			if child is Label and child.name == target_label_name:
				target_label = child
			elif child is Label and name_label == null and child.name != target_label_name:
				name_label = child
		if target_label == null or name_label == null:
			continue
		var display_name: String = (name_label as Label).text
		for shop_type in shop_types:
			var cfg: Dictionary = config.get(shop_type, {})
			if cfg.get("display", "") == display_name:
				target_label.text = format_func.call(shop_type)
				break

func _refresh_all_button_states() -> void:
	if _run_director == null or _player == null or not is_instance_valid(_player):
		return
	var copper_amount: int = _run_director.copper

	# 武器区 — 匹配 "BuyWeaponBtn" 或 "ReplaceWeaponBtn"
	_refresh_zone_buttons(_weapon_zone, func(b): return b.name == "BuyWeaponBtn" or b.name == "ReplaceWeaponBtn",
		copper_amount, "金", 10000)

	# 弹药区 — 匹配 "BuyAmmoBtn"
	_refresh_zone_buttons(_ammo_zone, func(b): return b.name == "BuyAmmoBtn",
		copper_amount, "铜", 1)

	# 手雷区 — 匹配 "BuyGrenadeBtn"，且需检查手雷是否已满
	_refresh_zone_buttons(_grenade_zone, func(b): return b.name == "BuyGrenadeBtn",
		copper_amount, "银", 100, _grenade_full_check)

## 通用按钮状态刷新：遍历 zone 中每个 HBoxContainer 行，找到匹配 match_func 的按钮，
## 解析同行中带 price_suffix 的 Label 作为价格，× multiplier 转铜后与 copper_amount 比较决定 disabled。
## extra_check(btn, row) 可选，用于施加额外禁用条件（如手雷满上限）。
func _refresh_zone_buttons(zone: VBoxContainer, match_func: Callable, copper_amount: int,
		price_suffix: String, multiplier: int, extra_check: Callable = Callable()) -> void:
	if zone == null:
		return
	# 递归遍历 zone 的所有后代，找到匹配的按钮
	for row in zone.get_children():
		if not row is HBoxContainer:
			# 武器卡片是 PanelContainer，需要深入查找
			if row is PanelContainer:
				_refresh_card_buttons(row, match_func, copper_amount, price_suffix, multiplier, extra_check)
			continue
		for child in row.get_children():
			if child is Button and match_func.call(child):
				for c in row.get_children():
					if c is Label and price_suffix in c.text:
						var price_str: String = (c as Label).text.replace(" " + price_suffix, "").strip_edges()
						if price_str.is_valid_int():
							var price_copper := int(price_str) * multiplier
							child.disabled = copper_amount < price_copper
						break
				if extra_check.is_valid():
					extra_check.call(child, row)
				break

## 递归查找 PanelContainer（武器卡片）内的按钮
func _refresh_card_buttons(card: PanelContainer, match_func: Callable, copper_amount: int,
		price_suffix: String, multiplier: int, extra_check: Callable) -> void:
	for child in card.get_children():
		if child is HBoxContainer:
			for sub in child.get_children():
				if sub is Button and match_func.call(sub):
					for c in child.get_children():
						if c is Label and price_suffix in c.text:
							var price_str: String = (c as Label).text.replace(" " + price_suffix, "").strip_edges()
							if price_str.is_valid_int():
								var price_copper := int(price_str) * multiplier
								sub.disabled = copper_amount < price_copper
							break
					if extra_check.is_valid():
						extra_check.call(sub, child)
					return

## 手雷满上限时额外禁用按钮
func _grenade_full_check(btn: Button, row: HBoxContainer) -> void:
	for c in row.get_children():
		if c is Label and c.name != "GrenadeCountLabel" and "银" not in (c as Label).text:
			for gt in _shop_grenade_types:
				var cfg: Dictionary = GRENADE_CONFIG.get(gt, {})
				if cfg.get("display", "") == (c as Label).text:
					var count: int = _player.grenades.get(gt, 0)
					if count >= _player.max_grenades:
						btn.disabled = true
					return

# ============================================================
# 输入：ESC 关闭
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("mouse_capture_exit"):
		# 如果替换弹窗开着，先关弹窗
		if _replace_popup and is_instance_valid(_replace_popup):
			_close_replace_popup()
			get_viewport().set_input_as_handled()
			return
		# 关闭确认弹窗
		for child in get_children():
			if child is PanelContainer and child.name == "ConfirmDialog":
				child.queue_free()
				get_viewport().set_input_as_handled()
				return
		close()
		get_viewport().set_input_as_handled()