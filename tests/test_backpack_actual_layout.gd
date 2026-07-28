## 背包 UI 实际布局回归测试（jxx-diagnosing-bugs 阶段 1 反馈循环）
## 现有 test_backpack_ui_layout.gd 只断言 anchor 值 == 1.0，未检查实际渲染 size 与 panel 位置。
## 本测试驱动真实 bug 模式：根 Control 是否真正填满视口、_panel 是否在中央而非 (0,0)。
##
## 运行：godot --headless --path . res://tests/test_backpack_actual_layout.tscn --quit-after 300
extends Control

var failures: int = 0
var _backpack: Control
var _phase: int = 0

func _ready() -> void:
	# 用一个有明确 size 的 Control 根，模拟 HUD/CanvasLayer 给子节点的父矩形
	set_anchors_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(1280, 720)
	call_deferred("_run_phase_0")

func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1

func _run_phase_0() -> void:
	# === 诊断：对比 set_anchors_preset vs set_anchors_and_offsets_preset 在 fresh Control 上的行为 ===
	# 这段对比作为"文档化诊断证据"保留，说明为什么 backpack_ui.gd 必须用后者。
	var fresh1 := Control.new()
	add_child(fresh1)
	fresh1.set_anchors_preset(Control.PRESET_FULL_RECT)
	print("[TEST] fresh1 set_anchors_preset(FULL_RECT): anchor_right=", fresh1.anchor_right, " offset_right=", fresh1.offset_right, " size=", fresh1.size)
	_check(fresh1.offset_right == -1280.0, "BUG REPRO: set_anchors_preset leaves offset_right = -parent_width (-1280.0), got %s" % fresh1.offset_right)
	_check(fresh1.size.x == 0.0, "BUG REPRO: fresh1 size.x == 0 (set_anchors_preset kept current size 0 as offset), got %s" % fresh1.size.x)

	var fresh2 := Control.new()
	add_child(fresh2)
	fresh2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	print("[TEST] fresh2 set_anchors_and_offsets_preset(FULL_RECT): anchor_right=", fresh2.anchor_right, " offset_right=", fresh2.offset_right, " size=", fresh2.size)
	_check(fresh2.offset_right == 0.0, "FIX: set_anchors_and_offsets_preset resets offset_right = 0, got %s" % fresh2.offset_right)
	_check(absf(fresh2.size.x - 1280.0) < 1.0, "FIX: fresh2 size.x ≈ 1280, got %s" % fresh2.size.x)

	# === 实例化 backpack_ui（与 hud.gd::_build_backpack_ui 同模式）===
	var script := load("res://scripts/backpack_ui.gd") as GDScript
	_backpack = script.new() as Control
	_backpack.visible = false
	add_child(_backpack)
	print("[TEST] backpack right after add_child (sync):")
	print("[TEST]   anchor_right=", _backpack.anchor_right, " offset_right=", _backpack.offset_right, " size=", _backpack.size)
	await get_tree().process_frame
	await get_tree().process_frame
	_run_phase_1()

func _run_phase_1() -> void:
	print("[TEST] === Phase 1: backpack root layout (visible=false) ===")
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	print("[TEST] viewport visible_rect size = ", vp_size)
	print("[TEST] test root (self) size = ", size, " position = ", position)
	_check(size.x > 0, "TEST ROOT size.x > 0 (got %s) — if 0, headless viewport is 0x0" % size.x)
	_check(_backpack.size.x > 0, "root size.x > 0 (got %s)" % _backpack.size.x)
	_check(_backpack.size.y > 0, "root size.y > 0 (got %s)" % _backpack.size.y)
	_check(absf(_backpack.size.x - 1280.0) < 1.0, "root size.x ≈ 1280 (got %s)" % _backpack.size.x)
	_check(absf(_backpack.size.y - 720.0) < 1.0, "root size.y ≈ 720 (got %s)" % _backpack.size.y)
	_check(_backpack.offset_right == 0.0, "root offset_right == 0 (set_anchors_and_offsets_preset reset, got %s)" % _backpack.offset_right)
	# 切换 visible=true 后再次验证（visible=false 不影响 layout 计算，但保险起见）
	_backpack.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	print("[TEST] === Phase 2: after visible=true ===")
	print("[TEST] backpack.size = ", _backpack.size, " position = ", _backpack.position)
	print("[TEST] backpack anchor_right = ", _backpack.anchor_right, " offset_right = ", _backpack.offset_right)
	_check(_backpack.size.x > 0, "after visible=true, root size.x > 0 (got %s)" % _backpack.size.x)
	_check(_backpack.size.y > 0, "after visible=true, root size.y > 0 (got %s)" % _backpack.size.y)
	_check(absf(_backpack.size.x - 1280.0) < 1.0, "after visible=true, root size.x ≈ 1280 (got %s)" % _backpack.size.x)
	_check(absf(_backpack.size.y - 720.0) < 1.0, "after visible=true, root size.y ≈ 720 (got %s)" % _backpack.size.y)

	# 内部 _panel 引用（@onready，已构建）
	var panel: PanelContainer = _backpack.get("_panel")
	_check(panel != null, "_panel reference is non-null")
	if panel:
		print("[TEST] panel.size = ", panel.size, " panel.position = ", panel.position)
		_check(panel.size.x > 100, "panel size.x > 100 (got %s)" % panel.size.x)
		_check(panel.size.y > 100, "panel size.y > 100 (got %s)" % panel.size.y)
		# panel 锚点 0.15..0.85 → 位置应在 ~15% 视口宽（≈138），非 (0,0)
		_check(panel.position.x > 100, "panel.position.x > 100 (NOT upper-left, got %s)" % panel.position.x)
		_check(panel.position.y > 30, "panel.position.y > 30 (NOT upper-left, 0.15*720=108 minus padding ≈ 45, got %s)" % panel.position.y)

	# 内部 _bg 引用
	var bg: ColorRect = _backpack.get("_bg")
	_check(bg != null, "_bg reference is non-null")
	if bg:
		print("[TEST] bg.size = ", bg.size, " bg.position = ", bg.position)
		_check(absf(bg.size.x - 1280.0) < 1.0, "bg size.x ≈ 1280 (got %s)" % bg.size.x)
		_check(absf(bg.size.y - 720.0) < 1.0, "bg size.y ≈ 720 (got %s)" % bg.size.y)

	# === Phase 3: shop_ui 的 _bg_overlay（ColorRect.new() + set_anchors_and_offsets_preset）===
	# shop_ui.tscn 根节点 anchor 在 .tscn 显式设置不走 set_anchors_preset，但其 _bg_overlay
	# 是 ColorRect.new() 后调用 set_anchors_and_offsets_preset（修复后），需验证布局正确。
	var shop_ui_scene := load("res://scenes/shop_ui.tscn")
	var shop_ui: Control = shop_ui_scene.instantiate()
	add_child(shop_ui)
	await get_tree().process_frame
	await get_tree().process_frame
	print("[TEST] === Phase 3: shop_ui root + _bg_overlay ===")
	print("[TEST] shop_ui.size = ", shop_ui.size, " anchor_right = ", shop_ui.anchor_right, " offset_right = ", shop_ui.offset_right)
	_check(shop_ui.size.x > 0, "shop_ui root size.x > 0 (got %s)" % shop_ui.size.x)
	_check(shop_ui.size.y > 0, "shop_ui root size.y > 0 (got %s)" % shop_ui.size.y)
	_check(shop_ui.offset_right == 0.0, "shop_ui root offset_right == 0 (got %s)" % shop_ui.offset_right)

	var shop_bg: ColorRect = shop_ui.get("_bg_overlay")
	_check(shop_bg != null, "shop_ui._bg_overlay reference is non-null")
	if shop_bg:
		print("[TEST] shop_ui._bg_overlay.size = ", shop_bg.size, " position = ", shop_bg.position, " offset_right = ", shop_bg.offset_right)
		_check(shop_bg.offset_right == 0.0, "shop_ui._bg_overlay offset_right == 0 (set_anchors_and_offsets_preset reset, got %s)" % shop_bg.offset_right)
		_check(absf(shop_bg.size.x - 1280.0) < 1.0, "shop_ui._bg_overlay size.x ≈ 1280 (got %s)" % shop_bg.size.x)
		_check(absf(shop_bg.size.y - 720.0) < 1.0, "shop_ui._bg_overlay size.y ≈ 720 (got %s)" % shop_bg.size.y)

	_finish()

func _finish() -> void:
	if failures == 0:
		print("[TEST] ALL PASSED")
	else:
		print("[TEST] %d FAILURES" % failures)
	get_tree().quit()
