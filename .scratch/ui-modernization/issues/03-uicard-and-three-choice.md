# 03 — UICard 组件 + 升级/宝箱三选一 UI

**Status:** ready-for-agent

**Blocked by:** 01

## 父 PRD

`.scratch/ui-modernization/PRD.md` — UI 现代化设计系统

## 构建内容

创建 `ui_card.gd` 共享卡片组件（`class_name UICard`，继承 PanelContainer），替代 `level_up.gd` 和 `chest_ui.gd` 中各自手写 Button 的重复实现。重构两个三选一 UI 引用 UITheme token + UICard + 统一打开/关闭动效。升级和宝箱弹出时看到统一卡片样式 + hover/pressed 态 + 过渡动效。

## 验收标准

- [ ] UICard 组件就位：`_init(title, description, icon, accent)` 构造，`set_pinned(is_pinned)` 对比参考高亮，`set_delta(label, is_better)` ▲/▼ 差异指示
- [ ] 卡片视觉：bg_panel 背景 + 4px 圆角 + 2px 描边 accent 色，hover scale 1.02，pressed scale 0.98
- [ ] 升级 UI 重构：三张 UICard 横排，每张配对应图标（max_health→heart / shield_regen→shield / damage→crosshair 等），选中后高亮 + fade-out 过渡
- [ ] 宝箱 UI 重构：与升级同模式，卡片图标按奖励类型（金币→coins / 血包→heart / 经验→star / 备弹→package / 随机武器→gun / 手雷→flame）
- [ ] 打开/关闭过渡：`UIMotion.tween_modal_in` 180ms / `tween_modal_out` 120ms
- [ ] 业务逻辑不变：信号回传（`level_up_offered` / `chest_reward_selected`）、暂停语义、替换武器对话框
- [ ] 测试通过：`test_ui_card` 验证卡片创建/pinned/delta；`test_chest_expansion` 选卡逻辑断言保持

## 阻塞于

- 01 — UI 基础设施