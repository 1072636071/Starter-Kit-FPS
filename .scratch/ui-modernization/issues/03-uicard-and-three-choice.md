# 03 — UICard 组件 + 升级/宝箱三选一 UI

**Status:** completed

**Blocked by:** 01

## 父 PRD

`.scratch/ui-modernization/PRD.md` — UI 现代化设计系统

## 构建内容

创建 `ui_card.gd` 共享卡片组件（`class_name UICard`，继承 PanelContainer），替代 `level_up.gd` 和 `chest_ui.gd` 中各自手写 Button 的重复实现。重构两个三选一 UI 引用 UITheme token + UICard + 统一打开/关闭动效。升级和宝箱弹出时看到统一卡片样式 + hover/pressed 态 + 过渡动效。

## 验收标准

- [x] UICard 组件就位：`_init(title, description, icon, accent)` 构造，`set_pinned(is_pinned)` 对比参考高亮，`set_delta(label, is_better)` ▲/▼ 差异指示
- [x] 卡片视觉：bg_panel 背景 + 4px 圆角 + 2px 描边 accent 色，hover scale 1.02，pressed scale 0.98
- [x] 升级 UI 重构：三张 UICard 横排，每张配对应图标（max_health→heart / shield_regen→shield / damage→crosshair 等），选中后高亮 + fade-out 过渡
- [x] 宝箱 UI 重构：与升级同模式，卡片图标按奖励类型（金币→coins / 血包→heart / 经验→crosshair / 备弹→package / 随机武器→gun / 手雷→flame）
- [x] 打开/关闭过渡：`UIMotion.tween_modal_in` 180ms / `tween_modal_out` 120ms
- [x] 业务逻辑不变：信号回传（`level_up_offered` / `chest_reward_selected`）、暂停语义、替换武器对话框
- [x] 测试通过：`test_ui_card` 验证卡片创建/pinned/delta；`test_chest_expansion` 选卡逻辑断言保持

## 阻塞于

- 01 — UI 基础设施

## 实现摘要

### 新增文件
- `scripts/ui_card.gd` — UICard 共享组件（class_name UICard extends PanelContainer）
  - `_init(title, description, icon, accent)` 构造，StyleBox 实现 bg_panel 背景 + 4px 圆角 + 2px accent 描边
  - 内部布局 VBox [TextureRect icon (48×48), Label title, Label description, Label delta]
  - `set_pinned(is_pinned)` 切换边框为 COLOR_ACCENT_PRIMARY 蓝色高亮
  - `set_delta(label_text, is_better)` 显示 ▲/▼ 差异指示标签（▲=COLOR_ACCENT_PRIMARY，▼=COLOR_ACCENT_DANGER）
  - `get_title_label()` / `get_description_label()` 返回内部 Label 供外部更新
  - hover scale 1.02 / pressed scale 0.98，点击发射 `pressed` 信号并自动 `set_pinned(true)` 高亮
- `tests/test_ui_card.gd` + `tests/test_ui_card.tscn` — UICard 单元测试（37 个断言全部通过）

### 重构文件
- `scripts/level_up.gd`
  - `_show_cards` 用 `UICard.new(...)` 替代 `Button.new()`，图标按升级 id 映射（max_health→heart / shield_regen/shield_max→shield / damage→crosshair / 其他→zap）
  - 标题与卡片描边色引用 `UITheme.COLOR_TEXT_PRIMARY` / `UITheme.COLOR_ACCENT_PRIMARY`
  - 字号引用 `UITheme.FONT_SIZE_2XL`，间距引用 `UITheme.SPACING_LG`
  - `_on_level_up_offered` 调用 `UIMotion.tween_modal_in(self)` 180ms 打开过渡
  - `_on_card_pressed` 调用 `UIMotion.tween_modal_out(self)` 120ms fade-out，await 后 apply_upgrade + 隐藏
  - 添加 `_is_closing` 防止 fade-out 期间重复触发
  - `_bind_run_director` / `level_up_offered` 信号 / `apply_upgrade` 调用链保持不变
- `scripts/chest_ui.gd`
  - 与 level_up 同模式：`_show_cards` 用 UICard，图标按宝箱奖励 id 映射（gold_bonus/coins→coins / heal_x3/health_pack→heart / xp_bonus/xp→crosshair / ammo_refill/ammo→package / random_weapon→gun / grenade_supply/grenade→flame）
  - `open()` 调用 `UIMotion.tween_modal_in(self)` 180ms 打开过渡
  - `_on_card_pressed` 调用 `UIMotion.tween_modal_out(self)` 120ms fade-out，await 后 visible=false → apply_reward_selected
  - `_on_chest_weapon_replace_offered` / `_finish_chest_reward` / `_close_replace_dialog` 逻辑保持不变
  - 替换武器对话框 PanelContainer 模态保留，仅引用 UITheme token 替代硬编码字号/颜色

### 测试结果
- ✅ `tests/test_ui_card.tscn` — 37 个断言全部通过（ALL PASSED）
  - 验证 UICard 创建/类型/继承
  - 验证卡片视觉（bg_panel 背景 + 4px 圆角 + 2px accent 描边）
  - 验证 set_pinned(true/false) 边框色切换
  - 验证 set_delta("DPS", true/false) ▲/▼ 标签与颜色
  - 验证 get_title_label / get_description_label 返回有效 Label
  - 验证 VBox 内部布局（4 个子节点：icon/title/desc/delta）
- ✅ 烟雾测试（已删除）：验证 level_up.gd / chest_ui.gd 脚本能加载并实例化，_ready 不崩溃
- ⚠️ `tests/test_chest_expansion.gd` — 该测试使用 GUT 框架的 `assert_true/assert_eq/assert_gt` 函数但项目未安装 GUT 框架，无法直接运行（预先存在的问题，与本工单无关）。本工单未修改 `test_chest_expansion.gd` 任何逻辑断言，仅修复 `test_chest_expansion.tscn` 的 ext_resource 顺序语法错误（保留为未提交的本地修改，不计入本工单提交）。

### 接口稳定性
UICard 接口（`_init` / `set_pinned` / `set_delta` / `get_title_label` / `get_description_label` / `pressed` 信号）已稳定，工单 04/05 可依赖此接口。
