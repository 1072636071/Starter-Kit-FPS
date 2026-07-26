## UITheme — 静态访问器，暴露设计 token 常量与 Theme 资源缓存。
##
## 用法：
##   UITheme.get_theme()          → 返回缓存的 Theme 资源
##   UITheme.COLOR_BG_BASE        → Color token 常量
##   UITheme.FONT_SIZE_LG         → 字号常量
##   UITheme.SPACING_XL           → 间距常量
##
## 所有后续 UI 脚本可通过 UITheme.COLOR_* / FONT_SIZE_* / SPACING_*
## 取代硬编码的 Color(...) 和魔数。
class_name UITheme
extends Node

## ── Color tokens ─────────────────────────────────────────
const COLOR_BG_BASE         := Color(0.05490, 0.07843, 0.09804, 1.0)  ## #0E1419
const COLOR_BG_PANEL        := Color(0.10196, 0.13333, 0.18824, 1.0)  ## #1A2230
const COLOR_BG_PANEL_RAISED := Color(0.14510, 0.17647, 0.24706, 1.0)  ## #252D3F
const COLOR_ACCENT_PRIMARY  := Color(0.0, 0.87843, 0.78431, 1.0)       ## #00E0C8
const COLOR_ACCENT_WARNING  := Color(1.0, 0.47843, 0.27059, 1.0)       ## #FF7A45
const COLOR_ACCENT_DANGER   := Color(1.0, 0.27451, 0.33333, 1.0)       ## #FF4655
const COLOR_TEXT_PRIMARY    := Color(0.90980, 0.91765, 0.92941, 1.0)   ## #E8EAED
const COLOR_TEXT_SECONDARY  := Color(0.54510, 0.58431, 0.64706, 1.0)   ## #8B95A5

## ── Font size tokens ─────────────────────────────────────
const FONT_SIZE_XS   := 12
const FONT_SIZE_SM   := 14
const FONT_SIZE_MD   := 18
const FONT_SIZE_LG   := 22
const FONT_SIZE_XL   := 28
const FONT_SIZE_2XL  := 36
const FONT_SIZE_3XL  := 48

## ── Spacing tokens ───────────────────────────────────────
const SPACING_XS  := 4
const SPACING_SM  := 8
const SPACING_MD  := 12
const SPACING_LG  := 16
const SPACING_XL  := 24
const SPACING_2XL := 32

## ── Theme resource paths ─────────────────────────────────
const THEME_PATH := "res://assets/ui.tres"

## ── Font paths ───────────────────────────────────────────
const FONT_RAJDHANI_LIGHT    := "res://assets/fonts/Rajdhani-Light.ttf"
const FONT_RAJDHANI_MEDIUM   := "res://assets/fonts/Rajdhani-Medium.ttf"
const FONT_RAJDHANI_SEMIBOLD := "res://assets/fonts/Rajdhani-SemiBold.ttf"
const FONT_RAJDHANI_BOLD     := "res://assets/fonts/Rajdhani-Bold.ttf"
const FONT_JETBRAINS_REGULAR := "res://assets/fonts/JetBrainsMono-Regular.ttf"
const FONT_JETBRAINS_BOLD    := "res://assets/fonts/JetBrainsMono-Bold.ttf"

## ── Icon paths ───────────────────────────────────────────
const ICON_COINS       := "res://assets/icons/coins.svg"
const ICON_ZAP         := "res://assets/icons/zap.svg"
const ICON_FLAME       := "res://assets/icons/flame.svg"
const ICON_HEART       := "res://assets/icons/heart.svg"
const ICON_SHIELD      := "res://assets/icons/shield.svg"
const ICON_CHEVRON_UP  := "res://assets/icons/chevron-up.svg"
const ICON_CROSSHAIR   := "res://assets/icons/crosshair.svg"
const ICON_PACKAGE     := "res://assets/icons/package.svg"
const ICON_KEY         := "res://assets/icons/key.svg"
const ICON_SWORD       := "res://assets/icons/sword.svg"
const ICON_GUN         := "res://assets/icons/gun.svg"

## ── 缓存的 Theme 资源 ─────────────────────────────────────
static var _cached_theme: Theme


## 返回缓存的 Theme 资源（惰性加载）。
static func get_theme() -> Theme:
	if _cached_theme == null:
		_cached_theme = load(THEME_PATH) as Theme
	return _cached_theme


## 清除缓存（测试用，强制重新加载 Theme 资源）。
static func clear_cache() -> void:
	_cached_theme = null


## 加载字体资源（带缓存）。
static func get_font(path: String) -> Font:
	return load(path) as Font


## 加载图标 Texture2D（带缓存）。
static func get_icon(path: String) -> Texture2D:
	return load(path) as Texture2D