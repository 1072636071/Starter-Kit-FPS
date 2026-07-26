## 测试 UITheme 静态访问器：资源加载与 token 值。
## 运行：godot --headless --path . res://tests/test_ui_theme.tscn --quit-after 300
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
	# === 1. Theme 资源加载 ===
	var theme: Theme = UITheme.get_theme()
	_check(theme != null, "Theme 资源加载成功")
	_check(theme is Theme, "Theme 类型正确")

	# === 2. Color token 值 ===
	_check(UITheme.COLOR_BG_BASE == Color(0.05490, 0.07843, 0.09804, 1.0), "COLOR_BG_BASE 正确")
	_check(UITheme.COLOR_BG_PANEL == Color(0.10196, 0.13333, 0.18824, 1.0), "COLOR_BG_PANEL 正确")
	_check(UITheme.COLOR_BG_PANEL_RAISED == Color(0.14510, 0.17647, 0.24706, 1.0), "COLOR_BG_PANEL_RAISED 正确")
	_check(UITheme.COLOR_ACCENT_PRIMARY == Color(0.0, 0.87843, 0.78431, 1.0), "COLOR_ACCENT_PRIMARY 正确")
	_check(UITheme.COLOR_ACCENT_WARNING == Color(1.0, 0.47843, 0.27059, 1.0), "COLOR_ACCENT_WARNING 正确")
	_check(UITheme.COLOR_ACCENT_DANGER == Color(1.0, 0.27451, 0.33333, 1.0), "COLOR_ACCENT_DANGER 正确")
	_check(UITheme.COLOR_TEXT_PRIMARY == Color(0.90980, 0.91765, 0.92941, 1.0), "COLOR_TEXT_PRIMARY 正确")
	_check(UITheme.COLOR_TEXT_SECONDARY == Color(0.54510, 0.58431, 0.64706, 1.0), "COLOR_TEXT_SECONDARY 正确")

	# === 3. Font size token 值 ===
	_check(UITheme.FONT_SIZE_XS == 12, "FONT_SIZE_XS 正确")
	_check(UITheme.FONT_SIZE_SM == 14, "FONT_SIZE_SM 正确")
	_check(UITheme.FONT_SIZE_MD == 18, "FONT_SIZE_MD 正确")
	_check(UITheme.FONT_SIZE_LG == 22, "FONT_SIZE_LG 正确")
	_check(UITheme.FONT_SIZE_XL == 28, "FONT_SIZE_XL 正确")
	_check(UITheme.FONT_SIZE_2XL == 36, "FONT_SIZE_2XL 正确")
	_check(UITheme.FONT_SIZE_3XL == 48, "FONT_SIZE_3XL 正确")

	# === 4. Spacing token 值 ===
	_check(UITheme.SPACING_XS == 4, "SPACING_XS 正确")
	_check(UITheme.SPACING_SM == 8, "SPACING_SM 正确")
	_check(UITheme.SPACING_MD == 12, "SPACING_MD 正确")
	_check(UITheme.SPACING_LG == 16, "SPACING_LG 正确")
	_check(UITheme.SPACING_XL == 24, "SPACING_XL 正确")
	_check(UITheme.SPACING_2XL == 32, "SPACING_2XL 正确")

	# === 5. 字体文件存在 ===
	_check(ResourceLoader.exists(UITheme.FONT_RAJDHANI_LIGHT), "Rajdhani-Light 字体文件存在")
	_check(ResourceLoader.exists(UITheme.FONT_RAJDHANI_MEDIUM), "Rajdhani-Medium 字体文件存在")
	_check(ResourceLoader.exists(UITheme.FONT_RAJDHANI_SEMIBOLD), "Rajdhani-SemiBold 字体文件存在")
	_check(ResourceLoader.exists(UITheme.FONT_RAJDHANI_BOLD), "Rajdhani-Bold 字体文件存在")
	_check(ResourceLoader.exists(UITheme.FONT_JETBRAINS_REGULAR), "JetBrainsMono-Regular 字体文件存在")
	_check(ResourceLoader.exists(UITheme.FONT_JETBRAINS_BOLD), "JetBrainsMono-Bold 字体文件存在")

	# === 6. 图标文件存在 ===
	_check(ResourceLoader.exists(UITheme.ICON_COINS), "coins.svg 存在")
	_check(ResourceLoader.exists(UITheme.ICON_ZAP), "zap.svg 存在")
	_check(ResourceLoader.exists(UITheme.ICON_FLAME), "flame.svg 存在")
	_check(ResourceLoader.exists(UITheme.ICON_HEART), "heart.svg 存在")
	_check(ResourceLoader.exists(UITheme.ICON_SHIELD), "shield.svg 存在")
	_check(ResourceLoader.exists(UITheme.ICON_CHEVRON_UP), "chevron-up.svg 存在")
	_check(ResourceLoader.exists(UITheme.ICON_CROSSHAIR), "crosshair.svg 存在")
	_check(ResourceLoader.exists(UITheme.ICON_PACKAGE), "package.svg 存在")
	_check(ResourceLoader.exists(UITheme.ICON_KEY), "key.svg 存在")
	_check(ResourceLoader.exists(UITheme.ICON_SWORD), "sword.svg 存在")
	_check(ResourceLoader.exists(UITheme.ICON_GUN), "gun.svg 存在")

	# === 7. 字体加载 ===
	var font: Font = UITheme.get_font(UITheme.FONT_RAJDHANI_BOLD)
	_check(font != null, "Rajdhani-Bold 字体加载成功")
	_check(font is Font, "Rajdhani-Bold 类型正确")

	font = UITheme.get_font(UITheme.FONT_JETBRAINS_REGULAR)
	_check(font != null, "JetBrainsMono-Regular 字体加载成功")
	_check(font is Font, "JetBrainsMono-Regular 类型正确")

	# === 8. 图标加载 ===
	var tex: Texture2D = UITheme.get_icon(UITheme.ICON_COINS)
	_check(tex != null, "coins.svg 加载成功")
	_check(tex is Texture2D, "coins.svg 类型正确")

	tex = UITheme.get_icon(UITheme.ICON_HEART)
	_check(tex != null, "heart.svg 加载成功")
	_check(tex is Texture2D, "heart.svg 类型正确")

	# === 9. Theme 缓存 ===
	UITheme.clear_cache()
	_check(UITheme._cached_theme == null, "clear_cache 清除缓存")

	var theme2: Theme = UITheme.get_theme()
	_check(theme2 != null, "clear_cache 后重新加载 Theme 成功")
	_check(theme2 == UITheme.get_theme(), "get_theme 返回缓存实例")

	# === 报告 ===
	if failures == 0:
		print("[TEST] ALL PASSED")
	else:
		print("[TEST] %d FAILURES" % failures)

	# === 清理 ===
	UITheme.clear_cache()