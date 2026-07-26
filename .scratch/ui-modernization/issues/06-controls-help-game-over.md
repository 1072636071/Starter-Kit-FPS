# 06 — 按键说明 + 游戏结束 UI 现代化

**Status:** ready-for-agent

**Blocked by:** 01

## 父 PRD

`.scratch/ui-modernization/PRD.md` — UI 现代化设计系统

## 构建内容

重构 `controls_help_ui.gd` + `game_over.gd`，引用 UITheme token，键名 kbd 样式统一从 Theme 取，游戏结束界面阶梯式过渡动效。F5 按键说明 / 死亡结算界面看到全新设计。

## 验收标准

- [ ] 按键说明：全屏 bg_base 78% alpha，中央 bg_panel 面板（60% 视口），keyboard 图标 + "按键说明" Rajdhani Bold 32pt
- [ ] 分组（移动/战斗/系统）每行 kbd 样式：bg_panel_raised 圆角 4px 内边距 + JetBrains Mono 键名 + Rajdhani 描述
- [ ] 底部提示："按 F5 或点击外部关闭" text_secondary 12pt
- [ ] 游戏结束：全屏 bg_base 90% alpha，标题 "游戏结束" Rajdhani Bold 64pt accent_danger
- [ ] 战绩面板：bg_panel 圆角 8px + 4 行（图标+标签+数值），JetBrains Mono Bold 28pt
- [ ] 重开按钮：refresh-cw 图标 + "重开一局" Rajdhani SemiBold 24pt + accent_primary 描边
- [ ] 出现过渡：标题 fade-in 300ms → 战绩 slide-up+fade 400ms → 按钮 fade-in 200ms
- [ ] 打开/关闭过渡：`UIMotion.tween_modal_in/out`（按键说明）；游戏结束独立阶梯式过渡
- [ ] 测试通过：`test_controls_help` 打开/关闭/暂停断言保持

## 阻塞于

- 01 — UI 基础设施