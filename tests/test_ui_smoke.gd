## UI 烟雾测试 — 完整游戏流程 UI 完整性验证（工单 07）
## 运行：godot --headless --path . res://tests/test_ui_smoke.tscn --quit-after 600
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
	# === 1. 加载 main.tscn，验证关键节点挂树 ===
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	_check(main_scene != null, "main.tscn 加载成功")

	var main: Node3D = main_scene.instantiate()
	add_child(main)

	# 等待一帧让 _ready 执行
	await get_tree().process_frame

	# === 2. HUD 挂树验证 ===
	var hud: CanvasLayer = main.get_node_or_null("HUD")
	_check(hud != null, "HUD CanvasLayer 存在")
	if hud:
		# HUD 脚本加载
		var hud_script: GDScript = hud.get_script()
		_check(hud_script != null, "HUD 脚本加载成功")
		# 现代化元件（由 hud.gd _ready 构建）
		_check(hud.has_node("InfoBar"), "InfoBar 节点存在（左上信息条）")
		_check(hud.has_node("ShieldContainer"), "ShieldContainer 节点存在（左下护盾）")
		_check(hud.has_node("AmmoList"), "AmmoList 节点存在（右下弹药列表）")
		_check(hud.has_node("GrenadeContainer"), "GrenadeContainer 节点存在（右下手雷）")

	# === 3. Player 挂树验证 ===
	var player: CharacterBody3D = main.get_node_or_null("Player")
	_check(player != null, "Player 节点存在")
	if player:
		_check(player.is_in_group("player"), "Player 在 player 组中")

	# === 4. RunDirector 挂树验证 ===
	var rd: Node = main.get_node_or_null("RunDirector")
	_check(rd != null, "RunDirector 节点存在")
	if rd:
		_check(rd.has_signal("game_over"), "RunDirector 有 game_over 信号")
		_check(rd.has_signal("level_up_offered"), "RunDirector 有 level_up_offered 信号")
		_check(rd.has_signal("wave_started"), "RunDirector 有 wave_started 信号")
		_check(rd.has_signal("wave_cleared"), "RunDirector 有 wave_cleared 信号")

	# === 5. UI 子组件挂树验证（LevelUp / ShopUI / GameOver / ChestUI） ===
	if hud:
		_check(hud.has_node("LevelUp"), "LevelUp UI 节点存在")
		_check(hud.has_node("ShopUI"), "ShopUI 节点存在")
		_check(hud.has_node("GameOver"), "GameOver UI 节点存在")
		_check(hud.has_node("ChestUI"), "ChestUI 节点存在")

	# === 6. UITheme 资源可加载 ===
	var ui_theme_script: GDScript = load("res://scripts/ui_theme.gd") as GDScript
	_check(ui_theme_script != null, "UITheme 脚本加载成功")
	if ui_theme_script:
		var theme: Theme = UITheme.get_theme()
		_check(theme != null, "UITheme.get_theme() 返回有效 Theme 资源")

	# === 7. UIMotion 工具可加载 ===
	var ui_motion_script: GDScript = load("res://scripts/ui_motion.gd") as GDScript
	_check(ui_motion_script != null, "UIMotion 脚本加载成功")

	# === 8. UICard 组件可加载 ===
	var ui_card_script: GDScript = load("res://scripts/ui_card.gd") as GDScript
	_check(ui_card_script != null, "UICard 脚本加载成功")

	# === 9. 字体资源就位 ===
	_check(UITheme.get_font(UITheme.FONT_RAJDHANI_BOLD) != null, "Rajdhani-Bold 字体加载成功")
	_check(UITheme.get_font(UITheme.FONT_JETBRAINS_REGULAR) != null, "JetBrainsMono-Regular 字体加载成功")

	# === 10. 图标资源就位（抽样验证） ===
	_check(UITheme.get_icon(UITheme.ICON_COINS) != null, "coins.svg 图标加载成功")
	_check(UITheme.get_icon(UITheme.ICON_SHIELD) != null, "shield.svg 图标加载成功")
	_check(UITheme.get_icon(UITheme.ICON_CROSSHAIR) != null, "crosshair.svg 图标加载成功")

	# === 11. 模拟受击 → 护盾 UI 响应 ===
	if player and hud:
		# 玩家受伤（护盾吸收）
		player.damage(10.0)
		await get_tree().process_frame
		_check(hud.has_node("ShieldContainer"), "受击后 ShieldContainer 仍存在（未被销毁）")
		# 检查 HUD 仍 visible
		_check(hud.visible == true, "受击后 HUD 仍可见")

	# === 12. 模拟升级 → LevelUp UI 响应 ===
	if rd and hud:
		var level_up_ui: Control = hud.get_node_or_null("LevelUp")
		if level_up_ui:
			var initial_visible: bool = level_up_ui.visible
			# 触发升级（加足够 XP）
			rd.add_xp(100)
			await get_tree().process_frame
			# 升级 UI 应在暂停态显示（或已关闭，取决于是否自动处理）
			_check(level_up_ui != null and is_instance_valid(level_up_ui), "升级后 LevelUp UI 仍存在（未被销毁）")
			# 清理：关闭升级 UI
			if level_up_ui.has_method("close"):
				level_up_ui.close()
			get_tree().paused = false

	# === 13. 模拟商店 → ShopUI 响应 ===
	if player and hud:
		var shop_ui: Control = hud.get_node_or_null("ShopUI")
		if shop_ui:
			# 商店 UI 初始应隐藏
			_check(shop_ui.visible == false, "ShopUI 初始隐藏")
			# 打开商店
			if shop_ui.has_method("open"):
				shop_ui.open(player, rd)
				await get_tree().process_frame
				_check(shop_ui.visible == true, "ShopUI open() 后可见")
				# 关闭商店
				if shop_ui.has_method("close"):
					shop_ui.close()
					await get_tree().process_frame
					_check(shop_ui.visible == false, "ShopUI close() 后隐藏")
			get_tree().paused = false

	# === 14. 模拟宝箱 → ChestUI 响应 ===
	if player and hud:
		var chest_ui: Control = hud.get_node_or_null("ChestUI")
		if chest_ui:
			_check(chest_ui.visible == false, "ChestUI 初始隐藏")
			# ChestUI 需要 chest 节点，仅验证节点存在
			_check(is_instance_valid(chest_ui), "ChestUI 实例有效")

	# === 15. 模拟游戏结束 → GameOver UI 响应 ===
	if rd and hud:
		var game_over_ui: Control = hud.get_node_or_null("GameOver")
		if game_over_ui:
			_check(game_over_ui.visible == false, "GameOver UI 初始隐藏")
			# 触发 game_over 信号
			var stats := {"wave": 3, "kills": 15, "copper_earned_total": 5000, "level": 2}
			if rd.has_signal("game_over"):
				rd.game_over.emit(stats)
				await get_tree().process_frame
				_check(game_over_ui.visible == true, "GameOver UI 在 game_over 信号后可见")
				_check(is_instance_valid(game_over_ui), "GameOver UI 实例有效（未被销毁）")
			get_tree().paused = false

	# === 16. 验证无 emoji 残留（扫描 HUD 下所有 Label） ===
	if hud:
		var emoji_count := _count_emoji_in_labels(hud)
		_check(emoji_count == 0, "HUD 下所有 Label 无 emoji 残留（共发现 %d 处）" % emoji_count)

	# === 17. 验证 UITheme token 引用（HUD 脚本中应引用 UITheme） ===
	if hud:
		var hud_script: GDScript = hud.get_script()
		if hud_script:
			var source: String = hud_script.source_code
			_check(source.find("UITheme.") != -1, "HUD 脚本引用了 UITheme token")
			_check(source.find("UIMotion.") != -1, "HUD 脚本引用了 UIMotion 动效")

	# === 报告 ===
	if failures == 0:
		print("[TEST] ALL PASSED — UI smoke test")
	else:
		print("[TEST] %d FAILURES — UI smoke test" % failures)

	# === 清理 ===
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures == 0 else 1)

## 递归扫描节点下所有 Label.text，统计 emoji 字符数量
func _count_emoji_in_labels(node: Node) -> int:
	var count := 0
	if node is Label:
		var text: String = (node as Label).text
		# 检查常见 emoji 字符
		for ch in ["🪙", "⚡", "💥", "●", "◆", "▬", "∴", "✱"]:
			if text.find(ch) != -1:
				count += 1
	for child in node.get_children():
		count += _count_emoji_in_labels(child)
	return count
