> **[ARCHIVED]** 本 PRD 对应功能已实现。决策权威见 ADR 024，术语定义见 CONTEXT.md。

# PRD — 按键说明面板（Controls Help Overlay）

Status: ready-for-agent
Date: 2026-07-25

## 问题陈述

玩家在竞技场中难以回忆全部操作键位（移动 / 射击 / 战斗 / 系统 / 经济共约 20 个动作）。当前游戏内没有集中查看键位的途径，只能靠记忆或退出游戏查看外部文档。

## 解决方案

按 **F5** 弹出暂停态模态面板，以分组形式展示全部操作键位。面板暂停游戏（第 4 个暂停源），玩家可安全阅读后再按 F5 或点击背景关闭回到游戏。键位文案从 InputMap 动态读取，键位改绑后自动同步。

## 用户故事

1. 作为玩家，在战斗中我想要按 F5 暂停游戏并查看所有操作键位说明，以便我能回忆起某个不常用操作的按键。
2. 作为玩家，我想要按键说明按移动 / 射击 / 战斗 / 系统类别分组展示，以便我能快速定位到某一类操作。
3. 作为玩家，我想要面板显示的键名与我实际绑定的按键一致，以便我改键后说明不会误导我。
4. 作为玩家，我想要再按一次 F5 关闭面板并回到游戏，以便操作流程顺畅无阻。
5. 作为玩家，我想要点击面板外的暗色背景也能关闭面板，以便鼠标操作也能方便退出。
6. 作为新玩家，我想要在游戏进行中随时查看键位，以便我不需要在开局前强记所有按键。
7. 作为玩家，我不希望在已被商店/升级/死亡暂停时误触 F5 打开面板，以免多个面板叠加造成混乱。
8. 作为玩家，我希望打开面板时游戏完全暂停（怪物不动、不受伤害），以便我能安心阅读键位说明。

## 实现决策

### 架构

- Controls Help 是第 4 个暂停源（前 3 个：Shop walk-in / Level Up / Game Over），并入 Pause Semantics（ADR 015）互斥框架。
- 优先级：死亡 > 商店 / 升级 > Controls Help；Controls Help 为最低优先级暂停源。
- 由 HUD 托管面板，复用武器检视 UI 的 `_build_*_ui()` 加载模式。新增输入动作 `controls_help`。

### 暂停行为

- 打开时：`get_tree().paused = true`、鼠标 `MOUSE_MODE_VISIBLE`、面板 `PROCESS_MODE_WHEN_PAUSED`。
- 关闭时：恢复 `MOUSE_MODE_CAPTURED`（仅当游戏未因其他原因暂停时）。
- 门控：仅当 `get_tree().paused == false` 时 F5 才响应（与武器检视 TAB 的 `_can_open_weapon_inspect()` 逻辑一致）。

### 关闭方式

- F5 切换打开/关闭
- 鼠标点击面板外暗色背景关闭
- 不用 Esc 关闭——Esc 在暂停语义中已有"退出暂停"含义

### 面板内容

- 策划分组子集（约 20 条），按移动 / 射击 / 战斗 / 系统 / 经济分类。
- 不暴露内部动作（`mouse_capture`、`camera_left` 等手柄轴）。
- 数据源：手维护的 `action → {label, group}` 映射字典提供中文标签，键名从 `InputMap.action_get_events()` + `as_text_physical_keycode()` 实时读取（复用 `hud._wave_prompt_text()` 写法）。
- 键位改绑后面板自动同步、不写死。

### 文件

- 场景与脚本遵循项目 `<功能>_ui.t/scn` 命名模式。
- 场景 UID 按语义化约定。

## 测试决策

### 好测试的定义

测试外部可观察行为，不测试面板内部实现细节（具体控件布局、字体颜色等视觉细节）。

### 测试 seam

- 集成测试：加载含 HUD + Player mock + ControlsHelpUi 的测试场景 → 通过 `Input.parse_input_event()` 注入 F5 按键事件 → 断言：`get_tree().paused == true`、面板 `visible == true`、鼠标 `MOUSE_MODE_VISIBLE` → 再次注入 F5 → 断言：`get_tree().paused == false`、面板 `visible == false`。
- 门控测试：先暂停游戏（模拟商店打开），再注入 F5 → 断言面板不出现。
- 关闭测试：面板打开状态下模拟点击背景区域 → 断言面板关闭、游戏恢复。

### 先例

与 `tests/test_shop.gd` 和 `tests/test_chest_expansion.gd` 的测试模式一致：场景级集成测试 + `Input.parse_input_event()` 按键注入 + 信号/状态断言。

### 测试文件

- `tests/test_controls_help.gd` + `tests/test_controls_help.tscn`

## 超出范围

- 不在标题界面或 Game Over 结算界面提供按键说明（仅游戏进行中可用）
- 不支持键盘导航在面板内切换标签页（v1 所有分组同屏展示、滚动查看）
- 不支持手柄按键显示（v1 仅展示键盘/鼠标绑定；手柄绑定通过 InputMap 的 joypad event 自然过滤，但面板不主动处理手柄布局优化）
- 不提供按键重新绑定功能（仅为只读展示）
- 音频反馈在 v1 中不做（面板打开/关闭不播放音效）

## 补充说明

- 笔记本用户需按 `Fn+F5` 才能发出 F5 键码，属于已知可用性边缘情况，记录于此但不在 v1 中特殊处理。
- 面板可被更高优先级暂停源（商店/升级/死亡）接管并隐藏，Controls Help 不与其他暂停 UI 叠加。
- 相关 ADR：024（Controls Help Overlay）、015（Pause Semantics）。
