# 05 — 武器检视 + 背包 UI 现代化

**Status:** ready-for-agent

**Blocked by:** 01

## 父 PRD

`.scratch/ui-modernization/PRD.md` — UI 现代化设计系统

## 构建内容

重构 `weapon_inspect_ui.gd` + `backpack_ui.gd`，引用 UITheme token，UICard 复用对比卡片，统一动效。TAB 打开武器检视 / T 键打开背包看到全新设计。

## 验收标准

- [ ] 武器检视：全屏 bg_base 75% alpha，顶部标题栏（gun 图标 + "武器检视"），三张大卡片横排含 3D 预览 + 完整属性
- [ ] 当前武器金边高亮，pinned 参考蓝边，差异 ▲/▼ 复用 UICard.set_delta
- [ ] 精度/耐久条 ProgressBar 从 Theme 取统一样式，弹药实时刷新保留
- [ ] 背包：全屏 bg_base 80% alpha，中央 bg_panel 面板（70% 视口），左侧物品列表 + 右侧 10 个备弹槽 2×5 网格
- [ ] 重量 ProgressBar：超 80% 变 accent_warning，超 100% 变 accent_danger
- [ ] 底部提示：info 图标 + 操作说明 text_secondary 14pt
- [ ] 关闭按钮 + T 键关闭，整理期间背包图标在 HUD 上 pulse_glow 提示
- [ ] 打开/关闭过渡：`UIMotion.tween_modal_in/out`
- [ ] 测试通过：`test_weapon_inspect_ui` 卡片对比逻辑断言保持

## 阻塞于

- 01 — UI 基础设施