# 01 — UI 基础设施（预重构）

**Status:** ready-for-agent

**Blocked by:** 无 — 可立即开始

## 父 PRD

`.scratch/ui-modernization/PRD.md` — UI 现代化设计系统

## 构建内容

创建 Godot Theme 资源、导入字体与图标、搭建动效工具类、切换项目拉伸模式。**不改变任何现有 UI 可视效果。** 所有后续工单可引用统一设计 token。

## 验收标准

- [ ] 字体就位：Rajdhani 4 字重 + JetBrains Mono 2 字重，含 OFL 许可文本
- [ ] 图标就位：11 个 Lucide SVG 图标，含 MIT 许可文本
- [ ] Theme 资源就位：8 色 token + 3 FontFamily + 7 级字号阶 + 6 个 StyleBox + 6 级间距常量
- [ ] `UITheme` 静态访问器就位：暴露 Color/字号/间距常量 + `get_theme()` 缓存方法
- [ ] `UIMotion` 动效工具就位：`tween_in` / `tween_out` / `tween_modal_in` / `tween_modal_out` / `tween_value` / `pulse_glow` 六个静态方法
- [ ] `project.godot` 拉伸模式切换为 `canvas_items` + `expand`
- [ ] 测试通过：`test_ui_theme` 验证资源加载与 token 值；`test_ui_motion` 验证 Tween 创建与生命周期

## 阻塞于

无 — 可立即开始