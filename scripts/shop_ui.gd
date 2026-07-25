extends Control
## issue 22（ADR 022）：商店 UI 三区重构（武器 / 弹药 / 手雷）
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

# 弹药捆图标映射（Unicode 符号区分弹种）
const AMMO_ICON: Dictionary = {
	&"手枪弹": "●",
	&"步枪弹": "◆",
	&"霰弹":   "∴",
	&"狙击弹": "▬",
	&"能量电池": "⚡",
	&"榴弹":   "✱",
}

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

# 替换对话框引用
var _replace_popup: Control
var _replace_weapon_idx: int = -1

# UI 根节点引用
@onready var _panel: PanelContainer = _build_panel()
@onready var _scroll: ScrollContainer = _build_scroll()
@onready var _content: VBoxContainer = _build_content()
@onready var _title: Label = _build_title()
@onready var _gold_label: Label = _build_gold_label()
@onready var _close_btn: Button = _build_close_button()

# 三个区的容器引用（每次 open 重建）
var _weapon_zone: VBoxContainer
var _ammo_zone: VBoxContainer
var _grenade_zone: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	_panel.add_child(_scroll)
	_scroll.add_child(_content)
	_content.add_child(_title)
	_content.add_child(_gold_label)
	_content.add_child(_close_btn)
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

func open(player: Node3D, run_director: Node) -> void:
	if _open:
		return
	_player = player
	_run_director = run_director
	_open = true

	# 用 run_director.rng 生成本局库存
	_generate_shop_stock()

	# 重建三区 UI
	_build_all_zones()

	_refresh_gold_label()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if _run_director and _run_director.has_signal("currency_changed"):
		if not _run_director.currency_changed.is_connected(_on_currency_changed):
			_run_director.currency_changed.connect(_on_currency_changed)

func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
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
	_shop_weapons = _pick_random_n(all_weapons, 3, rng)

	# --- 弹药区：随机抽 3–4 种不重复弹种 ---
	var ammo_count := rng.randi_range(3, 4)
	_shop_ammo_types = _pick_random_n(ALL_AMMO_TYPES, ammo_count, rng)

	# --- 手雷区：随机 1–2 种 ---
	var grenade_types: Array[StringName] = [&"emp", &"frag"]
	var grenade_count := rng.randi_range(1, 2)
	_shop_grenade_types = _pick_random_n(grenade_types, grenade_count, rng)

## 扫描 res://weapons/ 目录下所有 .tres 文件，加载为 Weapon 资源（委托给 WeaponUtils）
func _scan_weapon_tres_files() -> Array:
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
	p.anchor_left = 0.2
	p.anchor_top = 0.08
	p.anchor_right = 0.8
	p.anchor_bottom = 0.92
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p

func _build_scroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	s.mouse_filter = Control.MOUSE_FILTER_PASS
	return s

func _build_content() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 12)
	return v

func _build_title() -> Label:
	var l := Label.new()
	l.text = "商店  |  ESC 关闭"
	l.add_theme_font_size_override("font_size", 28)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build_gold_label() -> Label:
	var l := Label.new()
	l.text = "🪙 0铜"
	l.add_theme_font_size_override("font_size", 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build_close_button() -> Button:
	var b := Button.new()
	b.text = "关闭 (ESC)"
	b.add_theme_font_size_override("font_size", 18)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.pressed.connect(close)
	return b

func _refresh_gold_label() -> void:
	if _run_director:
		_gold_label.text = "🪙 %s" % _run_director.format_currency()

# ============================================================
# 三区构建
# ============================================================

func _build_all_zones() -> void:
	# 清除旧的区（保留 title / gold_label / close_btn）
	for child in _content.get_children():
		if child != _title and child != _gold_label and child != _close_btn:
			_content.remove_child(child)
			child.queue_free()

	# 清空武器预览旋转器映射（旧 SubViewport 将被释放）
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

	# 关闭按钮放最后
	_content.move_child(_close_btn, _content.get_child_count() - 1)

func _build_weapon_zone() -> void:
	_weapon_zone = VBoxContainer.new()
	_weapon_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weapon_zone.add_theme_constant_override("separation", 6)

	var header := _make_zone_header("═══ 武器区 ═══")
	_weapon_zone.add_child(header)

	if _shop_weapons.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "（暂无武器库存）"
		empty_lbl.add_theme_font_size_override("font_size", 16)
		empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_weapon_zone.add_child(empty_lbl)
	else:
		for i in range(_shop_weapons.size()):
			var w: Weapon = _shop_weapons[i]
			var row := _build_weapon_row(w, i)
			_weapon_zone.add_child(row)

	_content.add_child(_weapon_zone)

func _build_weapon_row(w: Weapon, shop_idx: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)

	# 武器 3D 模型预览（SubViewport + Camera3D，渲染层 2 隔离）
	var preview := _build_weapon_preview(w)
	row.add_child(preview)

	# 名称
	var name_lbl := Label.new()
	name_lbl.text = w.display_name
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.custom_minimum_size = Vector2(100, 0)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_lbl)

	# 价格（金）
	var price_lbl := Label.new()
	@warning_ignore("integer_division")
	var weapon_price_gold: int = w.weapon_cost / 10
	price_lbl.text = "%d 金" % weapon_price_gold
	price_lbl.add_theme_font_size_override("font_size", 18)
	price_lbl.custom_minimum_size = Vector2(60, 0)
	price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(price_lbl)

	# 弹药类型
	var ammo_lbl := Label.new()
	ammo_lbl.text = str(w.ammo_type)
	ammo_lbl.add_theme_font_size_override("font_size", 16)
	ammo_lbl.custom_minimum_size = Vector2(80, 0)
	ammo_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ammo_lbl)

	# 耐久度条 — spec 未要求但有益于购买决策，保留以帮助玩家评估武器状态
	var dura_bar := ProgressBar.new()
	dura_bar.name = "DurabilityBar"
	dura_bar.min_value = 0.0
	dura_bar.max_value = 1.0
	dura_bar.value = 1.0
	dura_bar.custom_minimum_size = Vector2(80, 14)
	dura_bar.show_percentage = false
	dura_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 设置耐久条样式（满条绿色）
	var dura_style := StyleBoxFlat.new()
	dura_style.bg_color = Color(0.2, 0.9, 0.2, 0.85)
	dura_bar.add_theme_stylebox_override("fill", dura_style)
	row.add_child(dura_bar)

	# 购买按钮
	var has_empty_slot: bool = _player.weapons.size() < 3
	if has_empty_slot:
		var buy_btn := Button.new()
		buy_btn.text = "购买"
		buy_btn.name = "BuyWeaponBtn"
		buy_btn.add_theme_font_size_override("font_size", 18)
		buy_btn.custom_minimum_size = Vector2(70, 36)
		buy_btn.pressed.connect(_buy_weapon.bind(shop_idx))
		row.add_child(buy_btn)
	else:
		var replace_btn := Button.new()
		replace_btn.text = "购买并替换"
		replace_btn.name = "ReplaceWeaponBtn"
		replace_btn.add_theme_font_size_override("font_size", 18)
		replace_btn.custom_minimum_size = Vector2(110, 36)
		replace_btn.pressed.connect(_show_replace_popup.bind(shop_idx))
		row.add_child(replace_btn)

	return row

# ============================================================
# 武器 3D 模型预览（SubViewport + Camera3D，渲染层 2 隔离）
# ============================================================

func _build_weapon_preview(w: Weapon) -> SubViewport:
	var svp := SubViewport.new()
	svp.custom_minimum_size = WEAPON_PREVIEW_SIZE
	svp.size = WEAPON_PREVIEW_SIZE
	svp.transparent_bg = true
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svp.mouse_filter = Control.MOUSE_FILTER_IGNORE

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

	return svp

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
	_ammo_zone.add_theme_constant_override("separation", 6)

	var header := _make_zone_header("═══ 弹药区 ═══")
	_ammo_zone.add_child(header)

	if _shop_ammo_types.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "（暂无弹药库存）"
		empty_lbl.add_theme_font_size_override("font_size", 16)
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
	row.add_theme_constant_override("separation", 10)

	# 弹药捆图标（Unicode 符号区分弹种）
	var icon_lbl := Label.new()
	icon_lbl.text = AMMO_ICON.get(ammo_type, "?")
	icon_lbl.add_theme_font_size_override("font_size", 20)
	icon_lbl.custom_minimum_size = Vector2(30, 0)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_lbl)

	# 弹药名
	var name_lbl := Label.new()
	name_lbl.name = "AmmoNameLabel"
	name_lbl.text = cfg["display"]
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.custom_minimum_size = Vector2(80, 0)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_lbl)

	# 捆量
	var bundle_lbl := Label.new()
	bundle_lbl.text = "×%d" % cfg["bundle_amount"]
	bundle_lbl.add_theme_font_size_override("font_size", 18)
	bundle_lbl.custom_minimum_size = Vector2(50, 0)
	bundle_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bundle_lbl)

	# 价格（铜）
	var price_lbl := Label.new()
	price_lbl.text = "%d 铜" % cfg["price"]
	price_lbl.add_theme_font_size_override("font_size", 18)
	price_lbl.custom_minimum_size = Vector2(50, 0)
	price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(price_lbl)

	# 当前储备量（从备弹槽计算）
	var reserve_lbl := Label.new()
	reserve_lbl.name = "AmmoReserveLabel"
	var current_reserve: int = _player.get_available_reloads(ammo_type) if _player else 0
	reserve_lbl.text = "当前: %d" % current_reserve
	reserve_lbl.add_theme_font_size_override("font_size", 16)
	reserve_lbl.custom_minimum_size = Vector2(90, 0)
	reserve_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(reserve_lbl)

	# 购买按钮
	var buy_btn := Button.new()
	buy_btn.text = "购买"
	buy_btn.name = "BuyAmmoBtn"
	buy_btn.add_theme_font_size_override("font_size", 18)
	buy_btn.custom_minimum_size = Vector2(70, 36)
	buy_btn.pressed.connect(_buy_ammo.bind(ammo_type))
	row.add_child(buy_btn)

	return row

func _build_grenade_zone() -> void:
	_grenade_zone = VBoxContainer.new()
	_grenade_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grenade_zone.add_theme_constant_override("separation", 6)

	var header := _make_zone_header("═══ 手雷区 ═══")
	_grenade_zone.add_child(header)

	if _shop_grenade_types.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "（暂无手雷库存）"
		empty_lbl.add_theme_font_size_override("font_size", 16)
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
	row.add_theme_constant_override("separation", 10)

	# 手雷名
	var name_lbl := Label.new()
	name_lbl.text = cfg["display"]
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.custom_minimum_size = Vector2(60, 0)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_lbl)

	# 价格（银）
	var price_lbl := Label.new()
	price_lbl.text = "%d 银" % cfg["price"]
	price_lbl.add_theme_font_size_override("font_size", 18)
	price_lbl.custom_minimum_size = Vector2(60, 0)
	price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(price_lbl)

	# 当前持有
	var count_lbl := Label.new()
	count_lbl.name = "GrenadeCountLabel"
	var current_count: int = _player.grenades.get(grenade_type, 0) if _player else 0
	count_lbl.text = "持有: %d/%d" % [current_count, _player.max_grenades if _player else 5]
	count_lbl.add_theme_font_size_override("font_size", 16)
	count_lbl.custom_minimum_size = Vector2(90, 0)
	count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(count_lbl)

	# 购买按钮
	var buy_btn := Button.new()
	buy_btn.text = "购买"
	buy_btn.name = "BuyGrenadeBtn"
	buy_btn.add_theme_font_size_override("font_size", 18)
	buy_btn.custom_minimum_size = Vector2(70, 36)
	buy_btn.pressed.connect(_buy_grenade.bind(grenade_type))
	row.add_child(buy_btn)

	return row

func _make_zone_header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

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

	# 构建替换弹窗
	if _replace_popup and is_instance_valid(_replace_popup):
		_replace_popup.queue_free()
	_replace_popup = null

	var popup := PanelContainer.new()
	popup.name = "ReplacePopup"
	popup.anchor_left = 0.3
	popup.anchor_top = 0.25
	popup.anchor_right = 0.7
	popup.anchor_bottom = 0.75
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(popup)

	var popup_vbox := VBoxContainer.new()
	popup_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	popup_vbox.add_theme_constant_override("separation", 12)
	popup_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(popup_vbox)

	var popup_title := Label.new()
	popup_title.text = "选择要替换的武器（购买 %s - %d 金）" % [w.display_name, weapon_price_gold]
	popup_title.add_theme_font_size_override("font_size", 20)
	popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_vbox.add_child(popup_title)

	for i in range(_player.weapons.size()):
		var slot_w: Weapon = _player.weapons[i]
		var slot_row := HBoxContainer.new()
		slot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_row.add_theme_constant_override("separation", 10)

		var slot_lbl := Label.new()
		slot_lbl.text = "槽 %d: %s" % [i + 1, slot_w.display_name]
		slot_lbl.add_theme_font_size_override("font_size", 18)
		slot_lbl.custom_minimum_size = Vector2(180, 0)
		slot_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_row.add_child(slot_lbl)

		var replace_btn := Button.new()
		replace_btn.text = "替换此槽"
		replace_btn.add_theme_font_size_override("font_size", 16)
		replace_btn.custom_minimum_size = Vector2(100, 36)
		replace_btn.pressed.connect(_confirm_replace.bind(i))
		slot_row.add_child(replace_btn)

		popup_vbox.add_child(slot_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.add_theme_font_size_override("font_size", 18)
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

func _close_replace_popup() -> void:
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

	var price: int = cfg["price"]
	var bundle: int = cfg["bundle_amount"]
	var display: String = cfg["display"]

	if _run_director.copper < price:
		_show_confirm_dialog("铜币不足", "需要 %d 铜，当前 %s。" % [price, _run_director.format_currency()], false)
		return

	_show_confirm_dialog("购买弹药", "确认购买 %s ×%d？\n价格: %d 铜" % [display, bundle, price], true, func():
		if not _run_director.spend_copper(price):
			return
		# 弹药添加到背包
		var weight_per_unit: float = _player.ITEM_WEIGHTS.get(ammo_type, 0.01)
		_player.backpack_add(ammo_type, &"ammo", bundle, weight_per_unit)
		if _player.has_method("_emit_ammo_updated"):
			_player._emit_ammo_updated()
		# 刷新弹药区的储备量显示
		_refresh_ammo_zone_reserve_labels()
		_refresh_gold_label()
		_refresh_all_button_states()
	)

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
	add_child(dialog)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = title_text
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_lbl)

	var body_lbl := Label.new()
	body_lbl.text = body_text
	body_lbl.add_theme_font_size_override("font_size", 18)
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(body_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	btn_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(btn_row)

	if show_confirm:
		var confirm_btn := Button.new()
		confirm_btn.text = "确认"
		confirm_btn.add_theme_font_size_override("font_size", 20)
		confirm_btn.custom_minimum_size = Vector2(100, 44)
		confirm_btn.pressed.connect(func():
			callback.call()
			dialog.queue_free()
		)
		btn_row.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.add_theme_font_size_override("font_size", 20)
	cancel_btn.custom_minimum_size = Vector2(100, 44)
	cancel_btn.pressed.connect(func(): dialog.queue_free())
	btn_row.add_child(cancel_btn)

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
	for row in zone.get_children():
		if not row is HBoxContainer:
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
