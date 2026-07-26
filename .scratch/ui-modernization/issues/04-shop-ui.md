# 04 — 商店 UI 现代化

**Status:** ready-for-agent

**Blocked by:** 01

## 父 PRD

`.scratch/ui-modernization/PRD.md` — UI 现代化设计系统

## 构建内容

重构 `shop_ui.gd` 三区布局（武器/弹药/手雷），引用 UITheme token，emoji 弹药图标（●◆∴▬⚡✱）替换为 SVG，武器卡片复用 UICard，统一打开/关闭动效。玩家走入商店看到全新设计。

## 验收标准

- [ ] 全屏 bg_base 80% alpha 背景 + 中央 bg_panel 圆角面板（80% 视口）
- [ ] 标题栏：store 图标 + "军火商店" Rajdhani Bold 36pt + 右侧 coins 图标+余额
- [ ] 三栏布局：武器区 / 弹药区 / 手雷区，每栏独立标题（text_secondary 14pt）
- [ ] 武器卡片：UICard 复用，含武器名 + 售价 + 3D 预览旋转保留 + "购买" 按钮
- [ ] 弹药捆卡片：UICard 简化版，含弹种 SVG 图标 + 捆量 + 单价
- [ ] 手雷卡片：同上
- [ ] 替换武器对话框：模态中模态，bg_base 95% alpha + 中央小卡片
- [ ] 关闭：右上角 X 按钮 + ESC 键，120ms 过渡后隐藏
- [ ] 打开/关闭过渡：`UIMotion.tween_modal_in/out`
- [ ] 测试通过：`test_shop_ui_redesign` 区段标题断言保持，颜色断言改引用 UITheme token

## 阻塞于

- 01 — UI 基础设施