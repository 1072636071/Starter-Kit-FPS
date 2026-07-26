# PRD — UI 现代化设计系统（UI Modernization Design System）

Status: needs-triage
Date: 2026-07-26

## 问题陈述

当前游戏所有 UI（HUD + 7 个 modal 屏幕）均为程序化构建、各自硬编码颜色与字号、用 emoji 当图标、无统一设计语言、无动效、像素硬编码不缩放。视觉上离"现代游戏 UI"差距明显：

1. **无统一设计语言** — 每个 UI 脚本有自己的 `Color(...)` 常量，配色杂乱，无品牌主色
2. **emoji 当图标** — 🪙⚡💥●◆▬，不同设备渲染不一致、不可着色、不专业
3. **像素硬编码** — `offset_left = -220` 等绝对坐标，1280×720 下设计，分辨率不缩放
4. **默认字体** — Godot 自带 Noto Sans，无 display font，无字重对比
5. **无动效** — 出现/消失是瞬切，无 fade/slide/glow pulse
6. **modal 同质化** — 三个"三选一卡"（升级/宝箱/武器检视）逻辑相似但实现重复

## 解决方案

引入 Godot `Theme` 资源作为集中设计系统载体，统一所有 UI 的配色、字体、字号、StyleBox、动效曲线。所有 UI 脚本通过 `add_theme_*_override` 或直接采用默认 theme 取代硬编码，emoji 图标统一替换为可着色的 SVG 图标库。HUD 重构为锚点+容器响应式布局，启用 `canvas_items` + `expand` 拉伸模式适配多分辨率。modal 屏幕统一过渡动效（180ms ease-out cubic 滑入淡入）。

视觉风格锚定：**战术写实风**（对标 Valorant / CS2 / 使命召唤）——低饱和深色底、细字重无衬线、青紫橙红高亮、信息密度高、几乎无装饰。与 FPS 严肃射击题材贴合，且与已有青白色玩家剑弧 / 红橙色敌人剑弧配色天然兼容。

## 用户故事

1. 作为玩家，我希望 HUD 看起来像现代射击游戏（Valorant/CS2）那样专业、信息清晰，以便沉浸感不被粗糙 UI 破坏。
2. 作为玩家，我希望图标在不同设备上显示一致（而不是 emoji），以便识别速度稳定。
3. 作为玩家，我希望弹出的 modal（商店/升级/宝箱）有平滑过渡动画，以便操作流畅不突兀。
4. 作为玩家，我希望在不同分辨率（1080p / 1440p / 4K）下 HUD 自适应缩放，以便在小屏笔记本与大屏显示器上都能看清。
5. 作为玩家，我希望关键状态（低血/低弹/低耐久）有视觉警示（脉冲发光），以便紧急情况不被忽略。
6. 作为开发者，我希望所有 UI 颜色/字体集中在一个 Theme 资源里管理，以便未来调色一个文件搞定、不复发颜色漂移。
7. 作为开发者，我希望新增 modal 时能复用统一的设计 token 与动效工具，以便不重复造轮子。

## 实现决策

### 视觉风格锚点

**战术写实风（Valorant/CS2/COD）。** 低饱和深色底、细字重无衬线、青紫橙红高亮、信息密度高、几乎无装饰。理由：与 FPS 严肃射击题材贴合，与已有青白/红橙剑弧 VFX 配色天然兼容。

### 配色（Valorant 青紫红方案）

锁定 6 色 Color token（在 Theme 资源中定义为常量，所有 UI 引用）：

| Token | Hex | 用途 |
|-------|-----|------|
| `bg_base` | `#0E1419` | 屏幕最底层背景 |
| `bg_panel` | `#1A2230` | 面板/卡片背景 |
| `bg_panel_raised` | `#252D3F` | 高亮面板/hover 态 |
| `accent_primary` | `#00E0C8` | 主色：友方/能量/护盾/当前武器高亮 |
| `accent_warning` | `#FF7A45` | 警告：换弹/低耐久/冷却 |
| `accent_danger` | `#FF4655` | 危险：低血/空弹/敌方 |
| `text_primary` | `#E8EAED` | 主文字（标题/数值） |
| `text_secondary` | `#8B95A5` | 次文字（标签/说明） |

### 架构：引入 Godot Theme 资源

**创建 `assets/ui.theme` 资源文件**，集中定义：
- Color 常量（上述 8 色 token）
- FontFamily（Rajdhani display + body、JetBrains Mono 数字、Noto Sans CJK 中文回退）
- StyleBox（panel_bg、button_normal、button_hover、button_pressed、progress_fill、progress_bg）
- 字号阶（12 / 14 / 18 / 22 / 28 / 36 / 48）
- 间距常量（4 / 8 / 12 / 16 / 24 / 32）

所有 UI 脚本以 `add_theme_*_override` 取代硬编码 Color，或直接采用默认 theme。后续调色只需改一个文件。

代价：所有 UI 脚本都要改一遍，会冲击现有 UI 测试（颜色断言失败）—— 见测试决策。

### 字体

- **Display + Body：Rajdhani**（OFL，方形几何无衬线，战术感，多字重 light/medium/semibold/bold）。Valorant 的 Tungsten 字体免费替代。
- **Monospaced 数字：JetBrains Mono**（OFL，等宽 tabular，现代编码字体）。用于弹药数/金币/倒计时等需要对齐的数字。
- **CJK 回退：Noto Sans CJK**（Godot 自带）。Rajdhani 缺中文字形，回退到 Noto。
- 字体文件存放 `assets/fonts/`。

### 图标策略

**替换所有 emoji 为 Lucide SVG 图标**（MIT，现代扁平，可着色）：
- `coins.svg` → 货币（替代 🪙）
- `zap.svg` → EMP（替代 ⚡）
- `flame.svg` → 破片手雷（替代 💥）
- `heart.svg` → 血量
- `shield.svg` → 护盾
- `chevron-up.svg` → 屏外敌人指示
- `crosshair.svg` → 准星/瞄准
- `package.svg` → 背包
- `key.svg` → 按键说明
- `sword.svg` → 近战
- `gun.svg` → 武器检视

图标文件存放 `assets/icons/`，Godot 4 导入 SVG 为 `Texture2D`，通过 `modulate` 着色适配主题。

### 动效语言

**战术风 = 严肃 = 无弹性。** 全部使用 `TRANS_CUBIC + EASE_OUT`，时长 180ms（modal）或 120ms（HUD 元素）。

- **HUD 元素出现**：8-12px 上滑 + fade-in（120ms）
- **Modal 打开**：scale 0.96→1.0 + fade-in（180ms）
- **Modal 关闭**：scale 1.0→0.96 + fade-out（120ms）
- **数值变化**：tween count up/down（250ms）
- **关键状态警示**：低血/低弹/低耐久时控件 `modulate` 脉冲（1.0→0.7→1.0，1.2s 循环）
- **不使用**：弹性、回弹、过冲（spring/elastic/bounce）

实现：`scripts/ui_motion.gd` 静态工具类，提供 `tween_in(control)` / `tween_out(control)` / `tween_value(label, from, to, duration)` / `pulse_glow(control, color)` 四个静态方法。

### 布局与缩放

**切换 `project.godot` 拉伸模式**：`window/stretch/mode = "canvas_items"` + `window/stretch/aspect = "expand"`。Godot 自动按视口缩放 UI 控件。

**HUD 元件重构为锚点 + 容器**：
- 左上信息条：`anchor_left=0, anchor_top=0` + `MarginContainer` 24px padding
- 左下护盾：`anchor_left=0, anchor_bottom=1` + `MarginContainer`
- 右下弹药列表：`anchor_right=1, anchor_bottom=1` + `MarginContainer` + `VBoxContainer`
- 右下手雷：弹药列表左侧，同锚点带负偏移
- 右上小地图：`anchor_right=1, anchor_top=0` + `MarginContainer`
- 中下提示：`anchor_left=0.5, anchor_top=0.7` 居中
- 取消所有 `offset_left = -220` 等绝对像素硬编码

### 范围与执行顺序

4 阶段递进，每阶段独立可验收：

**Phase 1 — 基础设施**（issue 01）
- 创建 `assets/ui.theme` 资源
- 创建 `scripts/ui_motion.gd` 动效工具
- 导入 Rajdhani / JetBrains Mono 字体到 `assets/fonts/`
- 导入 Lucide SVG 图标到 `assets/icons/`
- 切换 `project.godot` 拉伸模式
- 创建 `scripts/ui_theme.gd` 静态访问器（暴露 token 常量给脚本使用）

**Phase 2 — HUD 现代化**（issue 02）
- `scripts/hud.gd` 全面重构：信息条/护盾/弹药列表/手雷/提示词/小地图外框
- 所有 emoji 替换为 SVG 图标
- 引入 ui_motion 动效（HUD 元素出现/数值变化/低血脉冲）
- 重写为锚点+容器响应式布局

**Phase 3 — Modal 屏幕现代化**（issue 03）
- 7 个 modal 各自重构：商店/升级/宝箱/武器检视/背包/按键说明/游戏结束
- 统一打开/关闭过渡动效
- 抽取 `scripts/ui_card.gd` 三选一卡组件（升级/宝箱/武器检视复用）

**Phase 4 — 测试与文档**（issue 04）
- 更新 UI 测试断言到新 theme token
- 添加 UI 烟雾测试（验证 UI 构建不崩溃）
- 创建 ADR 027
- 更新 CONTEXT.md 添加 UI 设计系统术语

## 测试决策

### 好测试的定义

测试外部可观察行为（信号、暂停状态、键位响应、可见性切换），不测试视觉细节（具体颜色 hex、字号 px、控件坐标）。

### 现有测试冲击

| 测试 | 冲击点 | 处理 |
|------|--------|------|
| `test_arena_shield.gd` | 断言 `shield_updated` 信号值 | 保留——信号语义不变 |
| `test_shop_ui_redesign.gd` | 断言商店区段标题文本 | 保留——文本不变 |
| `test_weapon_inspect_ui.gd` | 断言卡片对比逻辑 | 保留——逻辑不变 |
| `test_controls_help.gd` | 断言面板打开/关闭、暂停 | 保留——行为不变 |
| 任何断言 `Color(...)` 等于某 hex 的测试 | 颜色断言失败 | 改为断言引用 `UITheme.COLOR_*` |

### 新增测试

- `tests/test_ui_theme.gd` — 验证 `ui.theme` 资源加载成功、所有 token 颜色非空、字体文件存在
- `tests/test_ui_motion.gd` — 验证 `tween_in/out` 创建有效 Tween、`pulse_glow` 持续运行

### 测试 seam

- Theme 资源加载：`load("res://assets/ui.theme")` 不为 null
- 动效工具：调用 `UIMotion.tween_in(control)` 后返回有效 Tween 引用
- 不验证视觉效果（像素级），仅验证不崩溃与接口契约

## 超出范围

- 不重做小地图的 SubViewport 渲染逻辑（仅在 Phase 2 重画外框/坐标网格）
- 不引入本地化（i18n）系统——中文文案继续硬编码
- 不增加 UI 音效反馈（点击/悬停音效）
- 不增加游戏内 UI 自定义选项（玩家不可调字号/透明度）
- 不重写 modal 业务逻辑（仅视觉重构，不改购买/选卡/暂停语义）
- 不支持手柄 UI 导航（D-pad 切换控件）
- 不增加多语言切换

## 补充说明

- 视觉风格锚点选择参考了项目已有 VFX 配色：玩家剑弧青白 (0.3, 0.7, 1.0) 与 Valorant 主色 `#00E0C8` 同色系；敌人剑弧红橙 (1.0, 0.25, 0.15) 与 Valorant 危险色 `#FF4655` 同色系。
- Rajdhani / JetBrains Mono / Lucide 均为 OFL/MIT 免费许可，可商用。
- 字体文件大小：Rajdhani 全字重约 200KB、JetBrains Mono 约 150KB，对包体影响可忽略。
- 相关 ADR：027（UI 现代化设计系统）。
