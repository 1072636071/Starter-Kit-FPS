# ADR 024 — 按键说明面板（Controls Help Overlay）

- 状态：已接纳
- 日期：2026-07-25
- 相关：ADR 015（暂停语义）

## 背景 / 上下文

玩家在竞技场中难以回忆全部操作键位（移动 / 射击 / 战斗 / 系统 / 经济等）。需求：按 **F5** 弹出一个集中展示键位的说明面板。

事实核查（`project.godot` 输入段）：**F5 当前空闲**——无任何 F5 绑定；唯一的 `F` 键是 `start_wave`（physical_keycode 70）。功能键 F1–F12 均未被占用，无冲突。（注意：笔记本需按 `Fn+F5` 才能发出 F5，属于已知可用性边缘情况，记录于此不阻塞。）

## 决策

**按键说明面板做成暂停态模态面板（方案 A）。**

- 打开时 `get_tree().paused = true`、鼠标 `MOUSE_MODE_VISIBLE`、面板 `PROCESS_MODE_WHEN_PAUSED`。
- 成为项目第 4 个暂停源（原 3 个：Shop walk-in / Level Up / Game Over），并入 Pause Semantics（ADR 015）的"暂停源互斥"框架。
- 由 HUD（`scripts/hud.gd`）托管，复用武器检视 UI 的 `_build_*_ui()` 加载 `scenes/controls_help_ui.tscn` 模式。
- 新增输入动作 `controls_help`，绑定 F5。

## 被否决的替代

**方案 B：不暂停的只读叠加层**（武器检视 UI `weapon_inspect_ui` 的模式，TAB 打开、游戏继续跑）。

否决理由：按键说明是"停下来学习"的参考信息，不是边打边看的 HUD 元素；暂停态更符合玩家对"帮助界面"的心智模型，且读面板时不会被怪打死。武器检视之所以不暂停，恰恰因为它是战斗中需边打边看的属性面板——两者目的不同，故 Controls Help 选暂停。

## 后果 / 影响

- Pause Semantics（ADR 015 / CONTEXT.md）需补第 4 个暂停源，明确优先级：**死亡 > 商店 / 升级 / Controls Help**；Controls Help 为最低优先级，可被任意其它暂停源或玩家主动关闭接管。
- 新增输入动作 `controls_help`（F5）。
- HUD 新增托管代码与子场景 `scenes/controls_help_ui.tscn` + `scripts/controls_help_ui.gd`。

## 已决议的设计决策（逐次 grill）

### 2. 面板内容范围 ✅
**策划分组子集。** 只收录约 20 条玩家可操作动作，按移动 / 射击 / 战斗 / 系统 / 经济分类。不暴露内部动作（`mouse_capture`、`camera_left` 等手柄轴）。

### 3. 键位数据来源 ✅
**中文标签字典 + InputMap 动态取键名。** 手维护 `action → {label, group}` 映射字典提供可读文案，键名实时从 `InputMap.action_get_events()` + `as_text_physical_keycode()` 读取。组合进一方案既解决文案可控（分类、说明），又确保键位改绑后自动同步。

### 1. 切换与关闭方式 ✅
**F5 切换 + 点击暗色背景关闭。** 不用 Esc——Esc 在暂停语义中已有"退出暂停"含义，Controls Help 的开关由 F5 独管路径更干净。点击面板外暗色背景作为辅助关闭方式（模态 UI 常见便利）。

### 4. 可用时机 ✅
**仅游戏进行中**（`get_tree().paused == false`）。已被其他暂停源（商店/升级/死亡）暂停时 F5 无效。理由：按键说明是操作参考，只在"能操作"的上下文中才有意义；避免暂停源叠加的交互复杂度。与武器检视 UI（TAB）的 `_can_open_weapon_inspect()` 逻辑一致。

### 5. 文件命名约定 ✅
**`scenes/controls_help_ui.tscn` + `scripts/controls_help_ui.gd`。** 遵循项目 `<功能>_ui.t/scn` 命名模式（与 `weapon_inspect_ui`、`backpack_ui` 一致）。场景 UID 按语义化约定使用 `bcontrolshelp24`。

---

> 所有设计决策已决议，grill 会话结束。实施清单见下方。

> 参见 [ADR 027](027-ui-modernization-design-system.md) — UI 现代化设计系统（按键说明面板重构为 UITheme token + kbd 样式 + UIMotion 动效）
