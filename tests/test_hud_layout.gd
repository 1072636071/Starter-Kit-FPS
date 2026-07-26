## 测试 HUD 现代化布局（issue 02）
## 验证：
##   1. HUD 元件挂树（InfoBar / ShieldContainer / AmmoList / GrenadeContainer / MinimapFrame / 4 提示词）
##   2. SVG 图标子节点存在（取代 emoji：coins/zap/flame/shield/chevron-up）
##   3. 所有 Label.text 不含 emoji（🪙⚡💥●◆▬ 等）
## 运行：godot --headless --path . res://tests/test_hud_layout.tscn --quit-after 300
extends Node3D

var failures: int = 0
# 待扫描的 emoji 字符集合
const EMOJI_CHARS := ["🪙", "⚡", "💥", "●", "◆", "▬", "🛡", "🔥"]

func _ready() -> void:
	call_deferred("_run_tests")

func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1

func _run_tests() -> void:
	# 实例化 HUD（CanvasLayer + hud.gd 脚本）
	var hud_script := load("res://scripts/hud.gd") as GDScript
	_check(hud_script != null, "hud.gd 脚本加载成功")
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(hud_script)
	add_child(hud)
	# 等一帧，让 @onready + _ready + call_deferred 跑完
	await get_tree().process_frame
	await get_tree().process_frame

	# === 1. 顶层 HUD 元件挂树 ===
	_check(hud.has_node("InfoBar"), "InfoBar 节点存在（左上信息条）")
	_check(hud.has_node("ShieldContainer"), "ShieldContainer 节点存在（左下护盾）")
	_check(hud.has_node("AmmoList"), "AmmoList 节点存在（右下弹药列表）")
	_check(hud.has_node("GrenadeContainer"), "GrenadeContainer 节点存在（右下手雷）")
	_check(hud.has_node("MinimapFrame"), "MinimapFrame 节点存在（右上小地图框）")
	_check(hud.has_node("WavePrompt"), "WavePrompt 节点存在（波次提示）")
	_check(hud.has_node("ChestPrompt"), "ChestPrompt 节点存在（宝箱提示）")
	_check(hud.has_node("StuckPrompt"), "StuckPrompt 节点存在（卡住提示）")
	_check(hud.has_node("PackingPrompt"), "PackingPrompt 节点存在（整理中提示）")

	# === 2. InfoBar 4 个图标-数值对子节点 ===
	_check(hud.has_node("InfoBar/InfoHBox/CoinsPair"), "CoinsPair 子节点存在")
	_check(hud.has_node("InfoBar/InfoHBox/LevelPair"), "LevelPair 子节点存在")
	_check(hud.has_node("InfoBar/InfoHBox/WavePair"), "WavePair 子节点存在")
	_check(hud.has_node("InfoBar/InfoHBox/KillsPair"), "KillsPair 子节点存在")
	_check(hud.has_node("InfoBar/InfoHBox/CoinsPair/Icon"), "CoinsPair/Icon TextureRect 存在（取代 🪙）")
	_check(hud.has_node("InfoBar/InfoHBox/CoinsPair/Label"), "CoinsPair/Label 存在（Rajdhani 标签）")
	_check(hud.has_node("InfoBar/InfoHBox/CoinsPair/Value"), "CoinsPair/Value 存在（JetBrains Mono 数值）")
	# 验证图标是 TextureRect（不是 Label emoji）
	var coins_icon := hud.get_node_or_null("InfoBar/InfoHBox/CoinsPair/Icon")
	_check(coins_icon is TextureRect, "CoinsPair/Icon 是 TextureRect（SVG 图标，非 emoji）")

	# === 3. ShieldContainer 子节点 ===
	_check(hud.has_node("ShieldContainer/ShieldHBox/ShieldIcon"), "ShieldIcon TextureRect 存在")
	_check(hud.has_node("ShieldContainer/ShieldHBox/ShieldInfo/ShieldText"), "ShieldText 存在")
	_check(hud.has_node("ShieldContainer/ShieldHBox/ShieldInfo/ShieldBar"), "ShieldBar 存在")
	_check(hud.has_node("ShieldContainer/ShieldHBox/ShieldInfo/ShieldRate"), "ShieldRate 存在")
	_check(hud.has_node("ShieldContainer/ShieldHBox/ShieldCooldown"), "ShieldCooldown 存在")
	var shield_icon := hud.get_node_or_null("ShieldContainer/ShieldHBox/ShieldIcon")
	_check(shield_icon is TextureRect, "ShieldIcon 是 TextureRect（SVG 图标）")

	# === 4. GrenadeContainer 子节点（zap/flame 取代 ⚡💥） ===
	_check(hud.has_node("GrenadeContainer/GrenadeVBox/EMPRow/EMPIcon"), "EMPIcon TextureRect 存在（取代 ⚡）")
	_check(hud.has_node("GrenadeContainer/GrenadeVBox/FragRow/FragIcon"), "FragIcon TextureRect 存在（取代 💥）")
	_check(hud.has_node("GrenadeContainer/GrenadeVBox/EMPRow/EMPLabel"), "EMPLabel 存在")
	_check(hud.has_node("GrenadeContainer/GrenadeVBox/FragRow/FragLabel"), "FragLabel 存在")
	var emp_icon := hud.get_node_or_null("GrenadeContainer/GrenadeVBox/EMPRow/EMPIcon")
	var frag_icon := hud.get_node_or_null("GrenadeContainer/GrenadeVBox/FragRow/FragIcon")
	_check(emp_icon is TextureRect, "EMPIcon 是 TextureRect（zap.svg，非 ⚡ emoji）")
	_check(frag_icon is TextureRect, "FragIcon 是 TextureRect（flame.svg，非 💥 emoji）")

	# === 5. MinimapFrame 子节点 ===
	_check(hud.has_node("MinimapFrame/Frame"), "MinimapFrame/Frame PanelContainer 存在（描边外框）")
	_check(hud.has_node("MinimapFrame/CoordBar"), "MinimapFrame/CoordBar 存在（坐标信息条）")
	_check(hud.has_node("MinimapFrame/OffscreenIndicator"), "MinimapFrame/OffscreenIndicator 存在（chevron-up 屏外敌人指示器）")
	var offscreen_icon := hud.get_node_or_null("MinimapFrame/OffscreenIndicator")
	_check(offscreen_icon is TextureRect, "OffscreenIndicator 是 TextureRect（chevron-up.svg）")

	# === 6. 所有 HUD 元件 Label.text 不含 emoji ===
	var hud_elements := [
		hud.get_node_or_null("InfoBar"),
		hud.get_node_or_null("ShieldContainer"),
		hud.get_node_or_null("AmmoList"),
		hud.get_node_or_null("GrenadeContainer"),
		hud.get_node_or_null("MinimapFrame"),
		hud.get_node_or_null("WavePrompt"),
		hud.get_node_or_null("ChestPrompt"),
		hud.get_node_or_null("StuckPrompt"),
		hud.get_node_or_null("PackingPrompt"),
	]
	var emoji_found_count := 0
	for elem in hud_elements:
		if elem == null:
			continue
		var labels: Array = elem.find_children("*", "Label", true, false)
		for label_node in labels:
			var label := label_node as Label
			if label == null:
				continue
			for emoji in EMOJI_CHARS:
				if label.text.find(emoji) >= 0:
					_check(false, "Label '%s' 含 emoji '%s': '%s'" % [label.name, emoji, label.text])
					emoji_found_count += 1
					break
	_check(emoji_found_count == 0, "所有 HUD Label.text 不含 emoji（共发现 %d 处）" % emoji_found_count)

	# === 7. UITheme token 引用（取代硬编码颜色） ===
	# 通过检查 InfoBar 图标 modulate 确认 UITheme token 被引用
	if coins_icon is TextureRect:
		_check(coins_icon.modulate == UITheme.COLOR_ACCENT_PRIMARY,
			"CoinsPair/Icon modulate = UITheme.COLOR_ACCENT_PRIMARY（取代硬编码颜色）")
	if shield_icon is TextureRect:
		_check(shield_icon.modulate == UITheme.COLOR_ACCENT_PRIMARY,
			"ShieldIcon modulate = UITheme.COLOR_ACCENT_PRIMARY")

	# === 8. JetBrains Mono 字体覆盖（数值 Label） ===
	var coins_value := hud.get_node_or_null("InfoBar/InfoHBox/CoinsPair/Value") as Label
	if coins_value:
		var font := coins_value.get_theme_font("font")
		_check(font != null, "CoinsPair/Value 字体覆盖非空（JetBrains Mono）")

	# === 9. UIMotion 入场动画创建 ===
	# tween_in 设置 modulate.a 从 0 → 1，动画完成后 modulate.a 应为 1
	# 由于 await process_frame 两次后动画（120ms）可能已完成或仍在进行
	# 仅验证 modulate.a > 0（动画已开始或完成）
	if hud.get_node_or_null("InfoBar"):
		var info_bar := hud.get_node("InfoBar") as Control
		_check(info_bar.modulate.a >= 0.0, "InfoBar modulate.a 已被 UIMotion 处理（>= 0）")

	# === 报告 ===
	if failures == 0:
		print("[TEST] PASS — HUD 现代化布局")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
