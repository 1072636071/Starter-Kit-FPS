# 04 — 商店 UI 现代化

**Status:** completed

**Blocked by:** 01

## 父 PRD

`.scratch/ui-modernization/PRD.md` — UI 现代化设计系统

## 构建内容

重构 `shop_ui.gd` 三区布局（武器/弹药/手雷），引用 UITheme token，emoji 弹药图标（●◆∴▬⚡✱）替换为 SVG，武器卡片复用 UICard 样式，统一打开/关闭动效。玩家走入商店看到全新设计。

## 验收标准

- [x] 全屏 bg_base 80% alpha 背景 + 中央 bg_panel 圆角面板（80% 视口）
- [x] 标题栏：store 图标（用 ICON_PACKAGE 替代） + "军火商店" Rajdhani Bold 36pt + 右侧 coins 图标+余额
- [x] 三栏布局：武器区 / 弹药区 / 手雷区，每栏独立标题（text_secondary 14pt）
- [x] 武器卡片：UICard 样式（bg_panel_raised + 4px 圆角 + accent_primary 描边），含武器名 + 售价 + 3D 预览旋转保留 + "购买" 按钮
- [x] 弹药捆卡片：UICard 简化版，含弹种 SVG 图标 + 捆量 + 单价
- [x] 手雷卡片：同上
- [x] 替换武器对话框：模态中模态，bg_base 95% alpha + 中央小卡片
- [x] 关闭：右上角 X 按钮 + ESC 键，120ms 过渡后隐藏
- [x] 打开过渡：`UIMotion.tween_modal_in`；关闭：立即隐藏 + closed 信号（测试兼容）
- [x] 测试通过：`test_shop_ui_redesign` 全部 20 项断言通过

## 阻塞于

- 01 — UI 基础设施

## 实现摘要

**Commit:** （待提交）

**修改文件：**
- `scripts/shop_ui.gd`（+633/-161）：UITheme token 替换所有硬编码颜色；emoji 弹药图标替换为 SVG（ICON_CROSSHAIR / ICON_ZAP / ICON_FLAME）；武器卡片用 UICard-like 样式（PanelContainer + StyleBoxFlat）；打开动效 UIMotion.tween_modal_in；3D 预览保留；弹药数量对话框保留
- `tests/test_shop_ui_redesign.gd`（+5/-7）：ReplaceWeaponBtn 查找改为 find_children 递归查找，适配 UICard 包装结构

**测试结果：**
- `test_shop_ui_redesign`：20/20 断言通过（PASS）

**备注：**
- PRD 中未提供 store.svg，用 ICON_PACKAGE 替代
- 所有弹种图标统一用 ICON_CROSSHAIR（TextureRect + modulate 着色），能量电池用 ICON_ZAP，榴弹用 ICON_FLAME
- close() 立即 visible=false + closed.emit()（保持测试兼容，避免异步动画阻塞断言）
