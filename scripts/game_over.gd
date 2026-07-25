extends Control
## issue 06（ADR 014 / 015）：游戏结束界面
##
## 监听 RunDirector.game_over(stats) → 显示本局战绩（存活波数 / 击杀数 / 累计金币 / 达到等级）
## + "重开一局"按钮。process_mode = WHEN_PAUSED（暂停期间可点击）。
##
## 重开：get_tree().paused = false → reload_current_scene()（天然重置所有状态，无需手动 reset）。
## 暂停互斥：死亡优先级最高，显示时隐藏 shop/level-up UI。

var _run_director: Node

@onready var _bg: ColorRect = _build_bg()
@onready var _title: Label = _build_title()
@onready var _stats_label: Label = _build_stats_label()
@onready var _restart_btn: Button = _build_restart_btn()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)
	add_child(_title)
	add_child(_stats_label)
	add_child(_restart_btn)
	call_deferred("_bind_run_director")

func _bind_run_director() -> void:
	# GameOver 挂在 HUD（CanvasLayer）下，HUD 在 Main 下，RunDirector 也在 Main 下
	var main := get_parent().get_parent() if get_parent() != null else null
	if main != null:
		_run_director = main.get_node_or_null("RunDirector")
	if _run_director == null and get_tree() != null:
		for n in get_tree().get_nodes_in_group("run_director"):
			if n and n.has_signal("game_over"):
				_run_director = n
				break
	if _run_director and _run_director.has_signal("game_over"):
		_run_director.game_over.connect(_on_game_over)

func _on_game_over(stats: Dictionary) -> void:
	_stats_label.text = "存活波数: %d\n击杀数: %d\n累计铜币: %d\n达到等级: %d" % [
		int(stats.get("wave", 0)),
		int(stats.get("kills", 0)),
		int(stats.get("copper_earned_total", 0)),
		int(stats.get("level", 1)),
	]
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# 暂停互斥：死亡优先级最高，隐藏其它暂停 UI（shop/level-up）
	for n in get_tree().get_nodes_in_group("shop_ui"):
		if is_instance_valid(n):
			n.visible = false
	var hud := get_parent()
	if hud:
		var level_up := hud.get_node_or_null("LevelUp")
		if level_up:
			level_up.visible = false

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

# ============================================================
# UI 构建
# ============================================================

func _build_bg() -> ColorRect:
	var r := ColorRect.new()
	r.anchor_right = 1.0
	r.anchor_bottom = 1.0
	r.color = Color(0, 0, 0, 0.75)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r

func _build_title() -> Label:
	var l := Label.new()
	l.text = "游戏结束"
	l.add_theme_font_size_override("font_size", 48)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	l.anchor_top = 0.2
	l.anchor_bottom = 0.2
	l.offset_left = -200
	l.offset_right = 200
	l.offset_top = -30
	l.offset_bottom = 30
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build_stats_label() -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 28)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	l.anchor_top = 0.45
	l.anchor_bottom = 0.45
	l.offset_left = -200
	l.offset_right = 200
	l.offset_top = -80
	l.offset_bottom = 80
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build_restart_btn() -> Button:
	var b := Button.new()
	b.text = "重开一局"
	b.add_theme_font_size_override("font_size", 28)
	b.anchor_left = 0.5
	b.anchor_right = 0.5
	b.anchor_top = 0.72
	b.anchor_bottom = 0.72
	b.offset_left = -100
	b.offset_right = 100
	b.offset_top = -25
	b.offset_bottom = 25
	b.grow_horizontal = Control.GROW_DIRECTION_BOTH
	b.pressed.connect(_on_restart_pressed)
	return b
