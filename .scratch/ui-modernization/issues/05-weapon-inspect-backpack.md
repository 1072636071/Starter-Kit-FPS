# 05 — 武器检视 + 背包 UI 现代化

**Status:** done

**Blocked by:** 01

## 父 PRD

`.scratch/ui-modernization/PRD.md` — UI 现代化设计系统

## 构建内容

重构 `weapon_inspect_ui.gd` + `backpack_ui.gd`，引用 UITheme token，UICard 复用对比卡片，统一动效。TAB 打开武器检视 / T 键打开背包看到全新设计。

## 验收标准

- [x] 武器检视：全屏 bg_base 75% alpha，顶部标题栏（gun 图标 + "武器检视"），三张大卡片横排含 3D 预览 + 完整属性
- [x] 当前武器金边高亮，pinned 参考蓝边，差异 ▲/▼ 复用 UICard.set_delta
- [x] 精度/耐久条 ProgressBar 从 Theme 取统一样式，弹药实时刷新保留
- [x] 背包：全屏 bg_base 80% alpha，中央 bg_panel 面板（70% 视口），左侧物品列表 + 右侧 10 个备弹槽 2×5 网格
- [x] 重量 ProgressBar：超 80% 变 accent_warning，超 100% 变 accent_danger
- [x] 底部提示：info 图标 + 操作说明 text_secondary 14pt
- [x] 关闭按钮 + T 键关闭，整理期间背包图标在 HUD 上 pulse_glow 提示
- [x] 打开/关闭过渡：`UIMotion.tween_modal_in/out`
- [x] 测试通过：`test_weapon_inspect_ui` 卡片对比逻辑断言保持

## 实现说明

### `scripts/weapon_inspect_ui.gd`
- 所有硬编码颜色替换为 UITheme token（COLOR_BG_BASE / COLOR_ACCENT_PRIMARY / COLOR_ACCENT_WARNING / COLOR_ACCENT_DANGER / COLOR_TEXT_PRIMARY / COLOR_TEXT_SECONDARY 等）
- `_build_title_bar()` 新增 gun 图标 + 标题文字横排
- `open()` / `close()` 调用 `UIMotion.tween_modal_in/out` 过渡动效
- 暂停自动关闭：连接 `SceneTree.process_frame` 信号（暂停期间也会发射），在 `_on_process_frame` 回调中检测 `get_tree().paused` 并调用 `close()`。比 `_process` 更可靠（PROCESS_MODE_ALWAYS 在 headless 测试中暂停时不会触发 `_process`）
- `close()` 保持 `visible = false` 立即生效的 API 契约（测试依赖）

### `scripts/backpack_ui.gd`
- 所有硬编码颜色替换为 UITheme token
- `_build_title_bar()` 新增 package 图标 + "背  包" 标题
- `_build_panel()` 使用 bg_panel 风格 + 2px 描边 + 8px 圆角
- `_build_right_grid()` 2 列网格容器（2×5 备弹槽）
- `_refresh_weight_label()` 重量 ProgressBar 颜色逻辑：超 80% warning / 超 100% danger
- `open()` / `close_and_pack()` 调用 `UIMotion.tween_modal_in/out`
- 备弹槽按钮样式按剩余量分色（>50% primary / >0% warning / =0% danger）

### 测试
- `tests/test_weapon_inspect_ui.gd` 26/26 断言全部通过
- 修复 `test_auto_close_on_pause` 失败：根因是 `PROCESS_MODE_PAUSABLE` 暂停时 `_process` 不被调用，改为 `process_frame` 信号回调

## 阻塞于

- 01 — UI 基础设施
