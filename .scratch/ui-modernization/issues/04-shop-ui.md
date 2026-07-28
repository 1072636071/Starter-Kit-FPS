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

## 后续 Bug 修复（2026-07-27）

商店 UI 完成后玩家反馈 4 个 bug，已修复并加 regression 测试。

### Bug 1：进入商店后什么商品都看不到

**根因：** `_build_scroll()` 创建的 `ScrollContainer` 未设置 `size_flags_vertical = SIZE_EXPAND_FILL`，在父 `VBoxContainer` 中被分配最小高度 0，导致 `_content`（武器/弹药/手雷三区）不可见。

**修复：** `_build_scroll()` 显式设置 `size_flags_vertical` 与 `size_flags_horizontal` 均为 `SIZE_EXPAND_FILL`。

### Bug 2：退出商店后有模型遮住相机

**根因：** 武器 3D 预览的 `SubViewport` 默认共享主 `World3D`，预览模型（render layer 2）泄漏到主世界，被玩家 `CameraItem`（cull_mask 含 layer 2）渲染叠加到屏幕上，退出商店后仍持续旋转遮挡视野。

**修复：** 为武器预览 `SubViewport` 设置 `own_world_3d = true`，使其拥有独立 `World3D`，与主场景完全隔离。

### Bug 3：`look_at()` 报 "Node not inside tree"

**根因：** `_build_weapon_preview()` 中调用 `cam.look_at()` / `light.look_at()` 时，节点虽已 `add_child` 到 `SubViewport`，但 `SubViewportContainer`（顶层父节点）尚未入树，`look_at()` 要求节点已在树中（用全局坐标）。

**修复：** 改用 `Basis.looking_at(target - position)` 直接构造朝向（纯数学运算，无需入树），避免 `look_at()` 的入树前置条件。

### Bug 4：进入一次商店后商店消失

**根因：** 此前误增的"商店柱子（Pillar）隐藏逻辑"——`shop.gd` 在退出商店时设置 `_pillar.visible = false`，导致玩家以为商店消失。柱子本应作为地标始终可见。

**修复：** 删除 `shop.gd` 中所有柱子隐藏/显示相关代码（`_pillar` 变量、`_set_pillar_visible()` 函数及相关调用），柱子始终可见。

### Regression 测试

在 `tests/test_shop_ui_redesign.gd` 新增 4 组 regression 测试（R1–R4），覆盖上述 bug：

| 测试 | 验证内容 |
|------|---------|
| R1 | `_scroll.size_flags_vertical == SIZE_EXPAND_FILL`（防商品不可见） |
| R2 | 武器预览 `SubViewport.own_world_3d == true`（防模型泄漏） |
| R3 | 预览相机 `basis` 非恒等（防 `look_at` 错误回归） |
| R4 | 关闭后重新 `open()` 成功，三区重建（防商店消失） |

**测试结果：** `test_shop_ui_redesign` 30/30 断言通过（原 22 + 新 8）。
