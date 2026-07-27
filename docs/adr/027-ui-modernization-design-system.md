# ADR 027 — UI 现代化设计系统（UI Modernization Design System）

- 状态：已接纳
- 日期：2026-07-26
- 相关：ADR 011（升级三选一卡）、ADR 014（Game Over）、ADR 015（暂停语义）、ADR 022（武器扩展，商店/检视 UI）、ADR 024（按键说明面板）

## 背景 / 上下文

当前游戏所有 UI（HUD + 7 个 modal 屏幕）均为程序化构建、各自硬编码颜色与字号、用 emoji 当图标、无统一设计语言、无动效、像素硬编码不缩放。视觉上离"现代游戏 UI"差距明显：

- **无统一设计语言** — 每个 UI 脚本有自己的 `Color(...)` 常量（如 `hud.gd` 的 `HIGHLIGHT_COLOR`、`weapon_inspect_ui.gd` 的 `CARD_BG` / `CARD_BORDER_*`、`controls_help_ui.gd` 的 `BG_COLOR` / `PANEL_BG` 等十余处），配色杂乱、无品牌主色
- **emoji 当图标** — `🪙⚡💥●◆▬` 在 HUD/商店/手雷容器中广泛使用，不同设备渲染不一致、不可着色、不专业
- **像素硬编码** — `offset_left = -220` / `offset_top = 596` 等绝对坐标在 1280×720 下设计，分辨率不缩放
- **默认字体** — Godot 自带 Noto Sans，无 display font，无字重对比
- **无动效** — Modal 出现/消失是瞬切，无 fade/slide/glow pulse
- **modal 同质化** — 三个"三选一卡"（升级 / 宝箱 / 武器检视）逻辑相似但实现重复，没有共享组件

需求：将全部 UI 现代化为对标 Valorant / CS2 / 使命召唤 的战术写实风。

## 决策

引入 **Godot `Theme` 资源 + 设计 token 系统** 作为集中设计语言载体，配套动效工具类与共享卡片组件，分四阶段重构所有 UI。详细规划见 [`.scratch/ui-modernization/PRD.md`](../../.scratch/ui-modernization/PRD.md)。

### 8 项核心设计决策

1. **视觉风格锚点：战术写实风**（Valorant/CS2/COD）—— 低饱和深色底、细字重无衬线、青紫橙红高亮、信息密度高、几乎无装饰。理由：与 FPS 严肃射击题材贴合，与已有青白玩家剑弧 / 红橙敌人剑弧 VFX 配色天然兼容。
2. **配色（Valorant 青紫红方案）** — 8 色 Color token：`bg_base #0E1419` / `bg_panel #1A2230` / `bg_panel_raised #252D3F` / `accent_primary #00E0C8` / `accent_warning #FF7A45` / `accent_danger #FF4655` / `text_primary #E8EAED` / `text_secondary #8B95A5`。
3. **架构：引入 Godot Theme 资源** — `assets/ui.theme` 集中定义 Color/FontFamily/StyleBox/字号阶/间距常量。所有 UI 脚本以 `add_theme_*_override` 或直接采用默认 theme 取代硬编码。配套 `scripts/ui_theme.gd` 静态访问器在脚本侧暴露 token 常量。
4. **字体：Rajdhani + JetBrains Mono + Noto Sans CJK** — Rajdhani（OFL，方形几何无衬线）作 display+body，JetBrains Mono（OFL，等宽 tabular）作数字，Noto Sans CJK（Godot 自带）作中文回退。
5. **图标：Lucide SVG 替换所有 emoji** — MIT 许可、可着色（通过 `modulate`）。11 个图标：`coins/zap/flame/heart/shield/chevron-up/crosshair/package/key/sword/gun.svg`。
6. **动效语言：cubic ease-out，无弹性** — 全部 `TRANS_CUBIC + EASE_OUT`：HUD 元素 120ms 滑入淡入 / Modal 180ms scale+fade / 数值 250ms tween / 警示 1.2s 脉冲循环。不使用 spring/elastic/bounce。实现 `scripts/ui_motion.gd` 静态工具。
7. **布局：canvas_items + expand 拉伸 + 锚点容器** — `project.godot` 切换 `window/stretch/mode = "canvas_items"` + `aspect = "expand"`。HUD 元件重构为 `MarginContainer` + `VBoxContainer/HBoxContainer` 锚点布局，移除所有 `offset_left = -220` 等绝对像素硬编码。
8. **范围：4 阶段递进** — Phase 1 基础设施（theme/字体/图标/动效工具）/ Phase 2 HUD 现代化 / Phase 3 Modal 屏幕现代化 / Phase 4 测试与文档。每阶段独立可验收，分别对应 `.scratch/ui-modernization/issues/01-04`。

## 被否决的替代

### 否决：不引入 Theme，逐脚本调优

**理由：** 增量改动、测试冲击小的优点不抵长期成本——颜色漂移会复发（每个新 UI 又要重复造轮、调色需逐脚本改）。一次性引入 Theme 是设计系统化的最小代价路径。

### 否决：只提取静态常量类（`scripts/ui_theme.gd` 仅常量，不走 Godot Theme 资源）

**理由：** 折衷方案虽代码集中，但不享受 Godot Theme 资源在编辑器内的可视化预览与继承机制——无法在 `.tscn` 中通过节点 theme 属性直接覆写、无法让 `Button` / `ProgressBar` 等内置控件自动采用默认样式。Theme 资源是 Godot 原生设计，应使用其完整能力。

### 否决：科幻发光风（Cyberpunk/Halo/Destiny）

**理由：** 深蓝紫底色 + 霓虹发光 + 显示器字体视觉冲击强，但与项目已有 Kenney 卡通低模美术风格冲突。Valorant 风的低饱和深色底 + 青紫红高亮既现代又兼容现有 VFX 配色（玩家剑弧青白 `Color(0.3, 0.7, 1.0)` ≈ Valorant 主色 `#00E0C8`；敌人剑弧红橙 `Color(1.0, 0.25, 0.15)` ≈ Valorant 危险色 `#FF4655`）。

### 否决：卡通扁平风（糖豆人/元梦之星）

**理由：** 高饱和明亮配色 + 圆角粗边框与 Kenney 低多边形美术一致，但削弱 FPS 紧张感。射击游戏的 HUD 应传递"严肃、致命、信息密度"的语义，卡通风格与之冲突。

### 否决：暗黑哥特风（艾尔登法环/暗黑破坏神 4）

**理由：** 羊皮纸/金属质感 + 衬线字体 + 暗红金色 + 纹理背景与 FPS 现代射击题材不匹配。

### 否决：CS2 香黄红方案

**理由：** 香黄是传统射击游戏 HUD 色谱，但与项目已有 VFX 配色（青白玩家剑弧）不同色系，强行引入会造成视觉割裂。Valorant 青紫红方案天然兼容现有 VFX。

### 否决：冷调纯青方案

**理由：** 偏严肃零情绪，但缺乏警示色（橙）的中性过渡，所有警告都直跳红色会过度刺激。Valorant 青紫红方案的三色阶（青主 → 橙警 → 红危）符合直觉。

### 否决：弹性/回弹动效

**理由：** 战术风 = 严肃 = 无弹性。spring/elastic/bounce 适合卡通或休闲游戏，与 FPS 紧张感冲突。cubic ease-out 既现代又克制，是 Valorant/CS2 的实际选择。

### 否决：本地化（i18n）系统

**理由：** 超出现代化范围。中文文案继续硬编码，未来增加多语言时再统一抽 key。

### 否决：UI 音效反馈

**理由：** 超出现代化范围。点击/悬停音效需配套音频资源与混音策略，单独议题。

### 否决：手柄 UI 导航

**理由：** 超出现代化范围。D-pad 切换控件需重新设计 focus 链路，单独议题。

## 后果 / 影响

### 正面

- **设计系统化** — 所有 UI 颜色/字体/动效集中管理，未来调色一个文件搞定
- **视觉现代化** — 从"程序员 UI"升级为对标 Valorant 的专业射击游戏 UI
- **响应式** — `canvas_items + expand` 拉伸模式适配多分辨率（1080p/1440p/4K）
- **可访问性** — 字体清晰度提升（Rajdhani 在小字号下可读性优于 Noto Sans）
- **可维护性** — 共享 `UICard` 组件消除三处"三选一卡"重复实现
- **品牌一致性** — 与已有 VFX 配色（青白/红橙剑弧）天然兼容

### 负面

- **测试冲击** — 现有 UI 测试中颜色断言失败（如 `Color(0.15, 0.5, 0.85, 0.9)` 等），需更新为引用 `UITheme.COLOR_*`。Phase 4 集中处理。
- **外部资源依赖** — 需下载 Rajdhani / JetBrains Mono / Lucide SVG（OFL/MIT 免费许可），增加约 350KB 包体
- **重构工作量** — 所有 UI 脚本（hud/shop_ui/chest_ui/level_up/weapon_inspect_ui/backpack_ui/controls_help_ui/game_over）均需重构，4 阶段递进以控制风险
- **Godot Theme 学习曲线** — 团队需熟悉 Theme 资源的 StyleBox/FontFamily/字号阶机制（中等复杂度）

### 互斥与协调

- **暂停语义不变** — 4 个暂停源（Shop/LevelUp/GameOver/ControlsHelp）的 `process_mode` 与互斥规则（ADR 015）保持，仅视觉重构
- **业务逻辑不变** — 商店购买、升级抽卡、宝箱选奖、武器检视对比、背包分配等业务逻辑保留，仅视觉与布局重构
- **测试 seam 不变** — 信号契约（`shield_updated` / `shield_cooldown_changed` / `level_up_offered` / `chest_reward_selected` / `game_over` 等）保留，仅断言视觉细节的测试需更新

## 已决议的设计决策（逐次 grill）

### 1. 视觉风格锚点 ✅

**战术写实风（Valorant/CS2/COD）。** 用户在 grill 会话中确认。理由见决策第 1 项与被否决的替代。

### 2. 配色方案 ✅

**Valorant 青紫红方案。** 用户在 grill 会话中确认 8 色 token。理由：与已有 VFX 配色天然兼容。

### 3. Theme 架构 ✅

**引入 Godot Theme 资源。** 用户在 grill 会话中确认。被否决的替代：逐脚本调优、仅静态常量类。

### 4. 字体 ✅

**Rajdhani + JetBrains Mono + Noto Sans CJK 回退。** 用户授权"其他问题自行决定"。Rajdhani 是 Valorant Tungsten 字体的免费 OFL 替代，方形几何无衬线符合战术风。JetBrains Mono 用于需要对齐的数字（弹药/货币/倒计时）。

### 5. 图标策略 ✅

**Lucide SVG 替换所有 emoji。** 用户授权"其他问题自行决定"。Lucide 是 MIT 许可的现代扁平图标库，可着色、可缩放、设备渲染一致。11 个图标覆盖 HUD/Modal 全部用例。

### 6. 动效语言 ✅

**Cubic ease-out，无弹性。** 用户授权"其他问题自行决定"。120ms HUD / 180ms Modal / 250ms 数值 / 1.2s 脉冲。`scripts/ui_motion.gd` 静态工具类统一管理。

### 7. 布局与缩放 ✅

**canvas_items + expand 拉伸 + 锚点容器。** 用户授权"其他问题自行决定"。移除所有 `offset_left = -220` 等绝对像素硬编码，改为 `MarginContainer + VBoxContainer/HBoxContainer` 锚点布局。

### 8. 范围与执行顺序 ✅

**4 阶段递进。** 用户授权"其他问题自行决定"。Phase 1 基础设施 → Phase 2 HUD → Phase 3 Modal → Phase 4 测试与文档。每阶段独立可验收，降低重构风险。

---

## 实施清单

详细实施清单见 7 个 issue 文件（从原始 4 阶段细化为 7 个垂直切片）：

- [`.scratch/ui-modernization/issues/01-theme-infrastructure.md`](../../.scratch/ui-modernization/issues/01-theme-infrastructure.md) — Phase 1：基础设施（theme/字体/图标/动效工具）
- [`.scratch/ui-modernization/issues/02-hud-modernization.md`](../../.scratch/ui-modernization/issues/02-hud-modernization.md) — Phase 2：HUD 全面现代化
- [`.scratch/ui-modernization/issues/03-uicard-and-three-choice.md`](../../.scratch/ui-modernization/issues/03-uicard-and-three-choice.md) — Phase 3a：UICard 组件 + 升级/宝箱三选一
- [`.scratch/ui-modernization/issues/04-shop-ui.md`](../../.scratch/ui-modernization/issues/04-shop-ui.md) — Phase 3b：商店 UI 现代化
- [`.scratch/ui-modernization/issues/05-weapon-inspect-backpack.md`](../../.scratch/ui-modernization/issues/05-weapon-inspect-backpack.md) — Phase 3c：武器检视 + 背包 UI
- [`.scratch/ui-modernization/issues/06-controls-help-game-over.md`](../../.scratch/ui-modernization/issues/06-controls-help-game-over.md) — Phase 3d：按键说明 + 游戏结束 UI
- [`.scratch/ui-modernization/issues/07-smoke-test-and-docs.md`](../../.scratch/ui-modernization/issues/07-smoke-test-and-docs.md) — Phase 4：烟雾测试 + 文档收尾

## 实施结果

全部 7 个 issue 已完成，所有验收标准通过。

### 测试验证

| 测试 | 断言数 | 状态 |
|------|--------|------|
| `test_ui_theme` | 49 | ALL PASSED |
| `test_ui_motion` | 18 | ALL PASSED |
| `test_ui_card` | 37 | ALL PASSED |
| `test_hud_layout` | 38 | PASS |
| `test_controls_help` | 33 | ALL PASSED |
| `test_weapon_inspect_ui` | 26 | ALL PASSED |
| `test_arena_shield` | 35 | PASS |
| `test_shop_ui_redesign` | 20 | PASS |
| `test_ui_smoke` | 40 | ALL PASSED |

**共 296 个断言全部通过，零回归。**

### 交付物

- **基础设施**：`assets/ui.tres`（Theme 资源）+ `scripts/ui_theme.gd`（静态访问器）+ `scripts/ui_motion.gd`（动效工具）+ `scripts/ui_card.gd`（共享卡片组件）
- **字体**：Rajdhani 4 字重 + JetBrains Mono 2 字重（OFL 许可）
- **图标**：11 个 Lucide SVG 图标（MIT 许可）
- **现代化 UI**：7 个 UI 脚本全部引用 UITheme token，emoji 全部替换为 SVG 图标
- **拉伸模式**：`project.godot` 切换为 `canvas_items` + `expand`
- **烟雾测试**：`tests/test_ui_smoke.gd` 验证完整游戏流程 UI 完整性
