# 06 — 按键说明 + 游戏结束 UI 现代化

**Status:** completed

**Blocked by:** 01

## 父 PRD

`.scratch/ui-modernization/PRD.md` — UI 现代化设计系统

## 构建内容

重构 `controls_help_ui.gd` + `game_over.gd`，引用 UITheme token，键名 kbd 样式统一从 Theme 取，游戏结束界面阶梯式过渡动效。F5 按键说明 / 死亡结算界面看到全新设计。

## 验收标准

- [x] 按键说明：全屏 bg_base 78% alpha，中央 bg_panel 面板（60% 视口），keyboard 图标 + "按键说明" Rajdhani Bold 32pt
- [x] 分组（移动/战斗/系统）每行 kbd 样式：bg_panel_raised 圆角 4px 内边距 + JetBrains Mono 键名 + Rajdhani 描述
- [x] 底部提示："按 F5 或点击外部关闭" text_secondary 12pt
- [x] 游戏结束：全屏 bg_base 90% alpha，标题 "游戏结束" Rajdhani Bold 64pt accent_danger
- [x] 战绩面板：bg_panel 圆角 8px + 4 行（图标+标签+数值），JetBrains Mono Bold 28pt
- [x] 重开按钮：chevron-up 图标 + "重开一局" Rajdhani SemiBold 24pt + accent_primary 描边
- [x] 出现过渡：标题 fade-in 300ms → 战绩 slide-up+fade 400ms → 按钮 fade-in 200ms
- [x] 打开/关闭过渡：`UIMotion.tween_modal_in/out`（按键说明）；游戏结束独立阶梯式过渡
- [x] 测试通过：`test_controls_help` 打开/关闭/暂停断言保持

## 阻塞于

- 01 — UI 基础设施

## 实现摘要

### controls_help_ui.gd
- 所有硬编码 Color 常量替换为 UITheme token（COLOR_BG_BASE、COLOR_BG_PANEL、COLOR_TEXT_PRIMARY 等）
- 背景：`Color(COLOR_BG_BASE, 0.78)` 全屏 ColorRect
- 面板：60% 视口（anchor 0.2→0.8），bg_panel 圆角 8px
- 标题：HBox[TextureRect(ICON_KEY) + Label("按键说明")]，Rajdhani Bold 32pt
- 键名：PanelContainer + StyleBoxFlat(bg_panel_raised, 圆角 4px, content_margin 4px) + JetBrains Mono Regular 20pt + COLOR_ACCENT_WARNING
- 底部提示改为 "按 F5 或点击外部关闭"，FONT_SIZE_XS + COLOR_TEXT_SECONDARY
- open() 结尾调用 UIMotion.tween_modal_in(panel)
- _build_ui() 开头清理旧子节点，避免重复添加

### game_over.gd
- 背景：`Color(COLOR_BG_BASE, 0.90)` 全屏 ColorRect
- 标题："游戏结束" Rajdhani Bold 64pt + COLOR_ACCENT_DANGER
- 战绩面板：PanelContainer + StyleBoxFlat(bg_panel, 圆角 8px)，4 行 HBox[TextureRect icon + Label 标签 + Label 数值]
  - 存活波次 → ICON_CROSSHAIR、击杀数 → ICON_SWORD、累计铜币 → ICON_COINS、达到等级 → ICON_ZAP
  - 数值用 JetBrains Mono Bold 28pt + COLOR_TEXT_PRIMARY
- 重开按钮：ICON_CHEVRON_UP 图标 + "重开一局" Rajdhani SemiBold 24pt + COLOR_ACCENT_PRIMARY 描边
- 阶梯式过渡：标题 fade-in 300ms → 战绩 slide-up+fade 400ms（延迟 300ms）→ 按钮 fade-in 200ms（延迟 700ms）
- 使用 UIMotion.TRANS_TYPE / EASE_TYPE 保持动效一致性

### 测试
- test_controls_help 全部 33 项测试通过（打开/关闭/暂停/信号/点击背景/KEY_MAP 完整性）