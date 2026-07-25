extends Control
## 武器检视 UI（ADR 022 配套）
##
## 按 TAB 打开，显示所有 3 个武器槽的完整属性面板：
##   - 伤害 / DPS / 射速(RPM) / 精度 / 弹匣 / 备弹 / 换弹
##   - 弹药类型 / 耐久度 / 售价 / 定位 / 可靠性 ★
##   - 当前弹药状态（弹匣/备弹，实时取自 player）
##
## 对比功能：点击一张武器卡片将其"固定为参考"——
##   其他卡片会显示相对参考的差异（▲ 更优 / ▼ 更差）。
##   再次点击已固定的卡片取消对比。

signal closed

const CARD_BG := Color(0.08, 0.08, 0.13, 0.94)
const CARD_BORDER_CURRENT := Color(0.9, 0.7, 0.2, 1.0)   # 当前武器金边
const CARD_BORDER_NORMAL := Color(0.25, 0.25, 0.35, 0.7)
const CARD_BORDER_PINNED := Color(0.4, 0.8, 1.0, 1.0)     # 对比参考蓝边
const STAT_LABEL_COLOR := Color(0.6, 0.6, 0.65)
const STAT_VALUE_COLOR := Color(0.95, 0.95, 0.95)
const BETTER_COLOR := Color(0.25, 0.85, 0.3)
const WORSE_COLOR := Color(0.9, 0.35, 0.3)
const STAR_COLOR := Color(0.95, 0.75, 0.2)
const EMPTY_STAR_COLOR := Color(0.3, 0.3, 0.3)
const BAR_BG := Color(0.12, 0.12, 0.18)

var _player: Node3D
var _open := false
var _pinned_index := -1  # 对比参考槽位，-1 = 无
var _card_panels: Array[PanelContainer] = []
var _card_content_refs: Array[Dictionary] = []  # 每张卡的可更新子节点引用

@onready var _bg: ColorRect = _build_bg()

func _ready() -> void:
	# 暂停期间不可交互（武器检视只在游戏进行中可用）
	process_mode = Node.PROCESS_MODE_PAUSABLE
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

func _build_bg() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, 0.75)
	r.anchor_left = 0.0
	r.anchor_top = 0.0
	r.anchor_right = 1.0
	r.anchor_bottom = 1.0
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r

# ============================================================
# 公共 API
# ============================================================

func is_open() -> bool:
	return _open

func open(player: Node3D) -> void:
	if _open:
		return
	_player = player
	_pinned_index = -1
	_open = true
	_build_ui()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	# 仅当游戏未暂停时才恢复鼠标捕获（其他 UI 如 shop/levelup 会在暂停打开时自行设置鼠标）
	if not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()

func _process(_delta: float) -> void:
	# 若游戏被其他 UI（商店/升级/死亡）暂停，自动关闭武器检视
	if _open and get_tree().paused:
		close()

# ============================================================
# 整体布局构建
# ============================================================

func _build_ui() -> void:
	# 清除旧内容（保留 _bg）
	for c in get_children():
		if c != _bg:
			c.queue_free()
	_card_panels.clear()
	_card_content_refs.clear()

	var root := VBoxContainer.new()
	root.anchor_left = 0.05
	root.anchor_top = 0.08
	root.anchor_right = 0.95
	root.anchor_bottom = 0.92
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	# 标题
	var title := Label.new()
	title.text = "武器检视  |  TAB 关闭  |  点击卡片对比"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title)

	# 卡片区域
	var cards_row := HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cards_row.add_theme_constant_override("separation", 20)
	root.add_child(cards_row)
	cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# 提示
	var hint := Label.new()
	hint.text = "按 Q / 滚轮 切换武器  |  按 X 丢弃当前武器"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)

	# 为每个槽位构建卡片
	var slot_count := _player.weapons.size()
	for i in range(3):
		var card := _build_weapon_card(i, slot_count)
		cards_row.add_child(card)

# ============================================================
# 单张武器卡片
# ============================================================

func _build_weapon_card(slot: int, slot_count: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(280, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# 背景
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD_BG
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)

	# 内边距 VBox
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)

	var refs := {}

	# 卡片可点击——设为对比参考
	panel.gui_input.connect(_on_card_clicked.bind(slot))

	if slot >= slot_count:
		_build_empty_card(content, refs)
	else:
		_build_filled_card(content, refs, slot)

	_card_panels.append(panel)
	_card_content_refs.append(refs)
	_apply_card_border(panel, slot, slot_count)

	return panel

func _build_empty_card(content: VBoxContainer, refs: Dictionary) -> void:
	var label := Label.new()
	label.text = "（空槽）"
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(label)

	var hint := Label.new()
	hint.text = "商店购买或\n地面拾取获得"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.3, 0.3, 0.35))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(hint)

func _build_filled_card(content: VBoxContainer, refs: Dictionary, slot: int) -> void:
	var w: Weapon = _player.weapons[slot]

	# ── 武器名 ──
	var name_lbl := Label.new()
	name_lbl.text = w.display_name
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(name_lbl)

	# ── 定位 + 可靠性 ──
	var role_str := _role_display(w)
	var role_lbl := Label.new()
	role_lbl.text = role_str
	role_lbl.add_theme_font_size_override("font_size", 15)
	role_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(role_lbl)
	refs["role"] = role_lbl

	_add_separator(content)

	# ── 弹药类型 ──
	refs["ammo_type"] = _add_stat_row(content, "弹药", _ammo_display(w), STAT_LABEL_COLOR, Color(0.5, 0.7, 0.9))

	# ── DPS ──
	var dps_val := _calc_dps(w)
	refs["dps"] = _add_stat_row(content, "DPS", "%.0f/s" % dps_val, STAT_LABEL_COLOR, STAT_VALUE_COLOR)

	# ── 伤害 ──
	var dmg_str := _damage_display(w)
	refs["damage"] = _add_stat_row(content, "伤害", dmg_str, STAT_LABEL_COLOR, STAT_VALUE_COLOR)

	# ── 射速 ──
	var rpm_val := 60.0 / w.cooldown
	refs["fire_rate"] = _add_stat_row(content, "射速", "%.0f RPM" % rpm_val, STAT_LABEL_COLOR, STAT_VALUE_COLOR)
	refs["cooldown_val"] = w.cooldown

	# ── 精度条 ──
	refs["accuracy_bar"] = _add_stat_bar(content, "精度", _accuracy_label(w), _accuracy_fill(w), _bar_color_for_accuracy(w.spread))

	# ── 弹匣 / 备弹 ──
	var mag := _player.magazine[slot] if slot < _player.magazine.size() else 0
	var res := _player.reserve[slot] if slot < _player.reserve.size() else 0
	refs["ammo_state"] = _add_stat_row(content, "弹药", "%d / %d" % [mag, res], STAT_LABEL_COLOR, STAT_VALUE_COLOR)
	refs["magazine_label"] = _add_stat_row(content, "弹匣容量", "%d 发" % w.magazine_size, STAT_LABEL_COLOR, STAT_VALUE_COLOR)
	refs["reserve_label"] = _add_stat_row(content, "备弹上限", "%d 发" % w.max_reserve, STAT_LABEL_COLOR, STAT_VALUE_COLOR)

	# ── 换弹时间 ──
	refs["reload"] = _add_stat_row(content, "换弹", "%.1fs" % w.reload_time, STAT_LABEL_COLOR, STAT_VALUE_COLOR)

	# ── 耐久条 ──
	refs["durability_bar"] = _add_stat_bar(content, "耐久", "%d" % w.durability_max, 1.0, _bar_color_for_durability(w.durability_max))
	refs["durability_val"] = w.durability_max

	# ── 售价 ──
	refs["price"] = _add_stat_row(content, "售价", "%d 金" % w.weapon_cost, STAT_LABEL_COLOR, Color(1, 0.85, 0.3))

	# ── 当前武器标记 ──
	if slot == _player.weapon_index:
		var current_mark := Label.new()
		current_mark.text = "◆ 当前装备"
		current_mark.add_theme_font_size_override("font_size", 14)
		current_mark.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		current_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		current_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(current_mark)

# ============================================================
# UI 构件
# ============================================================

func _add_separator(parent: Control) -> void:
	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(sep)

func _add_stat_row(parent: Control, label_text: String, value_text: String, label_color: Color, value_color: Color) -> Label:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", label_color)
	lbl.custom_minimum_size = Vector2(64, 0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	var val := Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", 15)
	val.add_theme_color_override("font_color", value_color)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(val)
	return val

func _add_stat_bar(parent: Control, label_text: String, value_text: String, fill_ratio: float, fill_color: Color) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", STAT_LABEL_COLOR)
	lbl.custom_minimum_size = Vector2(64, 0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	var bar_container := Control.new()
	bar_container.custom_minimum_size = Vector2(0, 16)
	bar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar_container)

	var bar_bg := ColorRect.new()
	bar_bg.color = BAR_BG
	bar_bg.anchor_left = 0.0
	bar_bg.anchor_top = 0.0
	bar_bg.anchor_right = 1.0
	bar_bg.anchor_bottom = 1.0
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(bar_bg)

	var bar_fill := ColorRect.new()
	bar_fill.color = fill_color
	bar_fill.anchor_top = 0.0
	bar_fill.anchor_bottom = 1.0
	bar_fill.anchor_left = 0.0
	bar_fill.anchor_right = fill_ratio
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(bar_fill)

	var val := Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", 13)
	val.add_theme_color_override("font_color", STAT_VALUE_COLOR)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.anchor_left = 0.0
	val.anchor_right = 1.0
	val.anchor_top = 0.0
	val.anchor_bottom = 1.0
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(val)

	return bar_container

# ============================================================
# 卡片边框
# ============================================================

func _apply_card_border(panel: PanelContainer, slot: int, slot_count: int) -> void:
	var sb := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if sb == null:
		return
	if slot == _pinned_index:
		sb.border_color = CARD_BORDER_PINNED
		sb.border_width_left = 3
		sb.border_width_right = 3
		sb.border_width_top = 3
		sb.border_width_bottom = 3
	elif slot >= slot_count:
		sb.border_color = CARD_BORDER_NORMAL
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.border_width_top = 1
		sb.border_width_bottom = 1
	elif slot == _player.weapon_index and _pinned_index < 0:
		sb.border_color = CARD_BORDER_CURRENT
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 2
	else:
		sb.border_color = CARD_BORDER_NORMAL
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.border_width_top = 1
		sb.border_width_bottom = 1

func _refresh_all_borders() -> void:
	var slot_count := _player.weapons.size()
	for i in range(3):
		if i < _card_panels.size():
			_apply_card_border(_card_panels[i], i, slot_count)

# ============================================================
# 点击卡片 → 对比
# ============================================================

func _on_card_clicked(event: InputEvent, slot: int) -> void:
	if not (event is InputEventMouseButton):
		return
	if not event.pressed:
		return
	if slot >= _player.weapons.size():
		return  # 空槽不可选为参考
	if _pinned_index == slot:
		# 取消对比
		_pinned_index = -1
	else:
		_pinned_index = slot
	_refresh_all_borders()
	_refresh_compare_indicators()

# ============================================================
# 对比指示器
# ============================================================

func _refresh_compare_indicators() -> void:
	if _pinned_index < 0 or _pinned_index >= _player.weapons.size():
		# 非对比模式：所有值为默认颜色
		_reset_all_comparisons()
		return

	var ref_w: Weapon = _player.weapons[_pinned_index]
	var ref_dps := _calc_dps(ref_w)
	var slot_count := _player.weapons.size()

	for i in range(slot_count):
		if i == _pinned_index:
			continue
		if i >= _card_content_refs.size():
			continue
		var refs := _card_content_refs[i]
		if refs.is_empty():
			continue
		var w: Weapon = _player.weapons[i]

		# DPS
		var dps := _calc_dps(w)
		_apply_compare_tint(refs, "dps", dps, ref_dps, "%.0f/s" % dps, false)
		# 伤害
		var dmg_str := _damage_display(w)
		_apply_compare_tint(refs, "damage", w.damage * w.shot_count, ref_w.damage * ref_w.shot_count, dmg_str, false)
		# 射速 (cooldown 越小越好)
		_apply_compare_tint(refs, "cooldown_val", -w.cooldown, -ref_w.cooldown, "%.0f RPM" % (60.0 / w.cooldown), false)
		# 精度 (spread 越小越好)
		_apply_compare_tint(refs, "accuracy_bar", -w.spread, -ref_w.spread, _accuracy_label(w), true)
		# 弹匣
		_apply_compare_tint(refs, "magazine_label", w.magazine_size, ref_w.magazine_size, "%d 发" % w.magazine_size, false)
		# 备弹
		_apply_compare_tint(refs, "reserve_label", w.max_reserve, ref_w.max_reserve, "%d 发" % w.max_reserve, false)
		# 换弹 (越小越好)
		_apply_compare_tint(refs, "reload", -w.reload_time, -ref_w.reload_time, "%.1fs" % w.reload_time, false)
		# 耐久
		_apply_compare_tint(refs, "durability_val", w.durability_max, ref_w.durability_max, "%d" % w.durability_max, false)
		# 售价 (越小越好)
		_apply_compare_tint(refs, "price", -w.weapon_cost, -ref_w.weapon_cost, "%d 金" % w.weapon_cost, false)

		# 精度条颜色
		if "accuracy_bar" in refs:
			var bar_ctrl: Control = refs["accuracy_bar"]
			_update_bar_fill(bar_ctrl, _accuracy_fill(w), _bar_color_for_accuracy(w.spread))

		# 耐久条颜色
		if "durability_bar" in refs:
			var bar_ctrl: Control = refs["durability_bar"]
			_update_bar_fill(bar_ctrl, 1.0, _bar_color_for_durability(w.durability_max))

	# 也刷新参考卡片本身（确保无对比标记）
	var pinned_refs := _card_content_refs[_pinned_index]
	if not pinned_refs.is_empty():
		_mark_as_reference(pinned_refs, ref_w)

func _apply_compare_tint(refs: Dictionary, key: String, val: float, ref_val: float, display: String, _is_bar: bool) -> void:
	var node = refs.get(key, null)
	if node == null:
		return
	if val > ref_val:
		if node is Label:
			node.add_theme_color_override("font_color", BETTER_COLOR)
			node.text = "▲ " + display
	elif val < ref_val:
		if node is Label:
			node.add_theme_color_override("font_color", WORSE_COLOR)
			node.text = "▼ " + display
	else:
		if node is Label:
			node.add_theme_color_override("font_color", STAT_VALUE_COLOR)
			node.text = "= " + display

func _mark_as_reference(refs: Dictionary, _w: Weapon) -> void:
	for key in refs:
		var node = refs[key]
		if node is Label:
			var t := node.text
			if t.begins_with("▲") or t.begins_with("▼") or t.begins_with("= "):
				node.text = t.substr(2)
			node.add_theme_color_override("font_color", STAT_VALUE_COLOR)
		# bar 归位
		if key in ["accuracy_bar", "durability_bar"] and node is Control:
			pass  # _refresh_compare_indicators 里已处理

func _reset_all_comparisons() -> void:
	var slot_count := _player.weapons.size()
	for i in range(slot_count):
		if i >= _card_content_refs.size():
			continue
		var refs := _card_content_refs[i]
		if refs.is_empty():
			continue
		var w: Weapon = _player.weapons[i]
		for key in refs:
			var node = refs[key]
			if node is Label:
				var t := node.text
				if t.begins_with("▲") or t.begins_with("▼") or t.begins_with("= "):
					node.text = t.substr(2)
				node.add_theme_color_override("font_color", STAT_VALUE_COLOR)
		if "accuracy_bar" in refs:
			_update_bar_fill(refs["accuracy_bar"], _accuracy_fill(w), _bar_color_for_accuracy(w.spread))
		if "durability_bar" in refs:
			_update_bar_fill(refs["durability_bar"], 1.0, _bar_color_for_durability(w.durability_max))

func _update_bar_fill(bar_container: Control, fill_ratio: float, fill_color: Color) -> void:
	fill_ratio = clampf(fill_ratio, 0.0, 1.0)
	for c in bar_container.get_children():
		if c is ColorRect and c != bar_container.get_child(0):  # skip bg (first child)
			c.color = fill_color
			c.anchor_right = fill_ratio

# ============================================================
# 计算公式
# ============================================================

func _calc_dps(w: Weapon) -> float:
	return w.damage * float(w.shot_count) / w.cooldown

func _damage_display(w: Weapon) -> String:
	if w.shot_count > 1:
		return "%.0f × %d" % [w.damage, w.shot_count]
	return "%.0f" % w.damage

func _ammo_display(w: Weapon) -> String:
	var s := str(w.ammo_type)
	if s == "" or s == "&\"\"":
		return "—"
	return s

func _role_display(w: Weapon) -> String:
	var parts: Array[String] = []
	if w.role_title != "":
		parts.append(w.role_title)
	parts.append(_reliability_stars(w.reliability_stars))
	return "  ".join(parts) if parts.size() > 0 else ""

func _reliability_stars(stars: int) -> String:
	stars = clampi(stars, 1, 3)
	var s := ""
	for i in range(3):
		if i < stars:
			s += "★"
		else:
			s += "☆"
	return s

func _accuracy_label(w: Weapon) -> String:
	if w.spread < 0.5:
		return "极高"
	elif w.spread < 1.5:
		return "高"
	elif w.spread < 3.0:
		return "中"
	elif w.spread < 5.0:
		return "低"
	return "极低"

func _accuracy_fill(w: Weapon) -> float:
	return clampf((5.0 - w.spread) / 5.0, 0.0, 1.0)

func _bar_color_for_accuracy(spread: float) -> Color:
	if spread < 1.0:
		return Color(0.25, 0.85, 0.3)
	elif spread < 2.5:
		return Color(0.85, 0.75, 0.2)
	return Color(0.85, 0.35, 0.2)

func _bar_color_for_durability(durability: int) -> Color:
	# 匹配 ADR 022 可靠性阈值：★★★ ≥200, ★★☆ 86-199, ★☆☆ ≤85
	if durability >= 200:
		return Color(0.25, 0.85, 0.3)  # 极高 — 绿色
	elif durability >= 85:
		return Color(0.85, 0.75, 0.2)  # 一般 — 黄色
	return Color(0.85, 0.35, 0.2)       # 易损 — 红色

# ============================================================
# 实时刷新（由 HUD 在 ammo_updated / 武器切换时调用）
# ============================================================

func refresh_ammo() -> void:
	if not _open or _player == null:
		return
	var slot_count := _player.weapons.size()
	for i in range(slot_count):
		if i >= _card_content_refs.size():
			continue
		var refs := _card_content_refs[i]
		if refs.is_empty():
			continue
		if "ammo_state" in refs:
			var mag := _player.magazine[i] if i < _player.magazine.size() else 0
			var res := _player.reserve[i] if i < _player.reserve.size() else 0
			var lbl: Label = refs["ammo_state"]
			lbl.text = "%d / %d" % [mag, res]
	# 边框随当前武器变化而更新
	if _pinned_index < 0:
		_refresh_all_borders()

func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("mouse_capture_exit"):
		close()
		get_viewport().set_input_as_handled()
