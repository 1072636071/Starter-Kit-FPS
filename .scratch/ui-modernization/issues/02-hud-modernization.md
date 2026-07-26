# 02 — HUD 全面现代化

**Status:** completed

**Blocked by:** 01

## 父 PRD

`.scratch/ui-modernization/PRD.md` — UI 现代化设计系统

## 构建内容

重构 `hud.gd` 全部 6 个 HUD 元件（左上信息条 / 左下护盾 / 右下弹药 / 右下手雷 / 中下提示词 / 右上小地图框）。引用 UITheme token 取代硬编码颜色，emoji 替换为 SVG 图标，锚点+容器布局取代像素硬编码，引入 UIMotion 动效（出现/数值变化/低血脉冲）。玩家进入游戏即可看到全新 Valorant 风格 HUD。

## 验收标准

- [x] 左上信息条：4 个图标-数值对（coins / Lv / 波次 / 击杀），JetBrains Mono 数字 + Rajdhani 标签，锚定左上角
- [x] 左下护盾条：shield 图标 + 数值 + 充能速率 + ProgressBar，冷却中变橙色倒计时，归零脉冲警示
- [x] 右下弹药列表：当前武器 `accent_primary` 左边竖条高亮，JetBrains Mono 数字，空弹脉冲警示，换弹进度条 + 耐久度条
- [x] 右下手雷：zap/flame 图标区分 EMP/破片，选中态高亮
- [x] 中下提示词群：波次/宝箱/卡住/整理中提示，Rajdhani SemiBold，滑入/滑出动效 120ms
- [x] 右上小地图：描边外框 + 坐标信息条 + 屏外敌人指示器
- [x] 所有 emoji（🪙⚡💥●◆▬）已移除，全部替换为 SVG 图标
- [x] 所有 `offset_left = -220` 等绝对像素坐标已移除，改为锚点+容器
- [x] 测试通过：`test_arena_shield` 信号断言保持；`test_hud_layout` 验证元件挂树且无 emoji

## 阻塞于

- 01 — UI 基础设施

## 实现摘要

### 重构范围
- `scripts/hud.gd`：全面重构 6 个 HUD 元件，引用 UITheme token / SVG 图标 / 锚点容器布局 / UIMotion 动效
- `tests/test_hud_layout.gd` + `.tscn`：新增测试，验证元件挂树、SVG 图标类型、Label 无 emoji、UITheme token 引用、UIMotion 入场动画

### 关键改动
1. **左上信息条（InfoBar）**：HBoxContainer + 4 个图标-数值对（coins/crosshair/package/sword SVG + JetBrains Mono 数值），锚定左上角 SPACING_LG 边距
2. **左下护盾条（ShieldContainer）**：shield SVG 图标 + ShieldText + ShieldBar(ProgressBar) + ShieldRate + ShieldCooldown，归零时 `UIMotion.pulse_glow` 脉冲警示，冷却中 fill 切换为 `COLOR_ACCENT_WARNING`
3. **右下弹药列表（AmmoList）**：VBoxContainer 锚定右下角，每行含 ColorRect 左竖条（当前武器 `COLOR_ACCENT_PRIMARY` 高亮）+ name/ammo Label + 换弹 ProgressBar + 耐久度 ProgressBar；空弹时 `UIMotion.pulse_glow(COLOR_ACCENT_DANGER)` 脉冲警示
4. **右下手雷（GrenadeContainer）**：VBoxContainer 含 EMP 行（zap.svg）+ 破片行（flame.svg），选中态高亮 `COLOR_ACCENT_PRIMARY`
5. **中下提示词群**：4 个 Label（WavePrompt/ChestPrompt/StuckPrompt/PackingPrompt）使用 Rajdhani SemiBold + 居中锚点，`UIMotion.tween_in/out` 滑入滑出 120ms + 防 race token
6. **右上小地图框（MinimapFrame）**：PanelContainer 描边外框（`COLOR_ACCENT_PRIMARY` 边框）+ CoordBar 坐标信息条（JetBrains Mono）+ OffscreenIndicator（chevron-up.svg，`COLOR_ACCENT_DANGER`）

### 动效集成
- 入场动画：`UIMotion.tween_in` 为 InfoBar / ShieldContainer / AmmoList / GrenadeContainer / MinimapFrame 添加 120ms 上滑 + 淡入
- 状态脉冲：`UIMotion.pulse_glow` 用于护盾归零（`COLOR_ACCENT_DANGER`）和空弹（`COLOR_ACCENT_DANGER`）警示
- 提示词动效：`UIMotion.tween_in/out` 用于波次/宝箱/卡住/整理中提示的滑入滑出

### 测试结果
- `test_hud_layout`：PASS（38 项断言全通过，验证 9 个顶层元件挂树、4 个图标-数值对子节点、5 个 SVG 图标 TextureRect 类型、所有 Label 无 emoji、UITheme token 引用、UIMotion 入场动画）
- `test_arena_shield`：PASS（保持原有护盾吸收/溢出/died 信号/heal/cooldown 断言全通过）