## Regression 测试：商店 X 关闭按钮尺寸过大
## Bug：进入商店后，X 按钮特别大，挡住了整个购买 UI
## 根因：_close_btn 作为 _panel (PanelContainer, Container) 的直接子节点，
## 被 Container 强制 stretch 到面板内容区尺寸，覆盖整个购买 UI 并吞掉鼠标事件。
## 修复：将 _close_btn 改为 _title_bar (HBoxContainer) 的末尾子节点。HBoxContainer
## 尊重子节点 custom_minimum_size (32x32)，不会 stretch；按钮随标题栏自然位于面板右上角。
## 运行：godot --headless --path . res://tests/test_shop_close_button_size.tscn --quit-after 600
extends Node3D

var failures: int = 0

func _ready():
	call_deferred("_run_tests")

func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1

func _run_tests() -> void:
	# 准备 player + run_director
	var player_scene := preload("res://objects/player.tscn")
	var player: CharacterBody3D = player_scene.instantiate()
	player.add_to_group("player")
	add_child(player)
	player.reset_backpack()

	var rd := preload("res://scripts/run_director.gd").new()
	rd.rng_seed = 42
	add_child(rd)
	rd.add_copper(50000)

	# 实例化 shop_ui
	var shop_ui_scene := preload("res://scenes/shop_ui.tscn")
	var shop_ui: Control = shop_ui_scene.instantiate()
	add_child(shop_ui)
	shop_ui.closed.connect(func(): pass)

	# 打开商店
	shop_ui.open(player, rd)
	_check(shop_ui.is_open() == true, "shop_ui opened")

	# 等待布局稳定（Container 在 notification_post_draw 才完成子节点布局）
	for _i in range(10):
		await get_tree().process_frame

	# 重置 UIMotion 引入的 scale，避免影响尺寸断言
	# （UIMotion.tween_modal_in 把 shop_ui.scale 设为 0.96→1.0，但 shop_ui.process_mode =
	# WHEN_PAUSED，测试中 tree 未暂停时 tween 不会前进，scale 卡在 0.96）
	shop_ui.scale = Vector2.ONE

	var close_btn: Button = shop_ui._close_btn
	var panel: PanelContainer = shop_ui._panel
	_check(is_instance_valid(close_btn), "close_btn is valid")
	_check(is_instance_valid(panel), "panel is valid")

	# === R1: 关闭按钮不是 _panel (PanelContainer) 的直接子节点 ===
	# 修复前：close_btn 是 _panel 直接子节点，被 Container 强制 stretch。
	# 修复后：close_btn 是 _title_bar (HBoxContainer) 的子节点。
	_check(close_btn.get_parent() != panel,
		"regression: close_btn is NOT direct child of _panel (parent class=%s)" % [
			close_btn.get_parent().get_class() if close_btn.get_parent() else "null"])
	_check(close_btn.get_parent() is HBoxContainer,
		"regression: close_btn parent is HBoxContainer (title_bar)")

	# === R2: 关闭按钮尺寸 ≈ 32x32（与 custom_minimum_size 一致）===
	# 修复前：(1153, 1000)，被 PanelContainer stretch；修复后：(32, 32)
	var expected_size := Vector2(32, 32)
	var size_diff := close_btn.size - expected_size
	var size_ok: bool = abs(size_diff.x) <= 10 and abs(size_diff.y) <= 10
	_check(size_ok,
		"regression: close_btn size ≈ 32x32 (got %s, diff=%s)" % [str(close_btn.size), str(size_diff)])

	# === R3: 关闭按钮不覆盖面板（覆盖率 < 10%）===
	# 修复前：覆盖率 ~137%（按钮甚至超出面板内容区），吞掉所有点击；
	# 修复后：覆盖率 ~0.1%
	var close_btn_rect: Rect2 = close_btn.get_global_rect()
	var panel_rect: Rect2 = panel.get_global_rect()
	var coverage_ratio: float = (close_btn_rect.size.x * close_btn_rect.size.y) / (panel_rect.size.x * panel_rect.size.y)
	_check(coverage_ratio < 0.1,
		"regression: close_btn coverage < 10%% of panel area (got %.1f%%)" % [coverage_ratio * 100])

	# === R4: 关闭按钮位于面板内（不应超出面板边界）===
	# 修复前：close_btn 被拉伸到面板内容区，size 几乎等于 panel；
	# 修复后：close_btn 在 title_bar 内，位于面板右上角。
	_check(close_btn_rect.end.x <= panel_rect.end.x + 1,
		"regression: close_btn right edge within panel (close_btn.end.x=%.1f, panel.end.x=%.1f)" % [
			close_btn_rect.end.x, panel_rect.end.x])
	_check(close_btn_rect.position.x >= panel_rect.position.x - 1,
		"regression: close_btn left edge within panel (close_btn.x=%.1f, panel.x=%.1f)" % [
			close_btn_rect.position.x, panel_rect.position.x])
	_check(close_btn_rect.position.y >= panel_rect.position.y - 1,
		"regression: close_btn top edge within panel (close_btn.y=%.1f, panel.y=%.1f)" % [
			close_btn_rect.position.y, panel_rect.position.y])
	# 关闭按钮应在面板顶部 20% 区域内（title_bar 所在位置）
	var top_zone_threshold: float = panel_rect.position.y + panel_rect.size.y * 0.2
	_check(close_btn_rect.end.y <= top_zone_threshold,
		"regression: close_btn in top 20%% of panel (close_btn.end.y=%.1f, threshold=%.1f)" % [
			close_btn_rect.end.y, top_zone_threshold])

	# 清理
	shop_ui.close()
	for _i in range(30):
		await get_tree().process_frame
	shop_ui.queue_free()
	player.queue_free()
	rd.queue_free()
	await get_tree().process_frame

	if failures == 0:
		print("[TEST] PASS — close button size is reasonable")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)


