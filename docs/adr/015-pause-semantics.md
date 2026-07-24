# ADR 015: 暂停语义（Shop / Level Up / Game Over 三处统一）

## 决策

本功能有三处独立的暂停源，统一采用 Godot 的 `get_tree().paused = true` + 节点 `process_mode` 分层：

| 暂停源 | 触发 | 恢复 |
|--------|------|------|
| **Shop**（issue 04） | 玩家走入 `Shop Station` 的 `Area3D` | 玩家走出 / 关闭 UI |
| **Level Up**（issue 05） | XP 跨阈值（即时） | 玩家选 1 张卡 |
| **Game Over**（issue 06） | `health <= 0` | 玩家点"重开一局" → `reload_current_scene()` |

### process_mode 分层

| 节点层 | `process_mode` | 理由 |
|--------|----------------|------|
| **Shop UI / Level Up UI / Game Over UI**（CanvasLayer 下的 Control） | `PROCESS_MODE_WHEN_PAUSED` | 必须在暂停期间响应输入与动画 |
| **RunDirector** | `PROCESS_MODE_PAUSABLE`（默认） | 触发暂停的信号已发射完毕；暂停期间无需运行 |
| **Player / Monsters / 弹体 / 血包 / Shield regen 计时器** | `PROCESS_MODE_PAUSABLE`（默认） | 游戏逻辑冻结 |
| **HUD**（护盾/金币/经验/波数指示） | `PROCESS_MODE_PAUSABLE`（默认） | 暂停期间无新信号；UI 自身的购买/选卡刷新由对应的 WHEN_PAUSED UI 自己处理 |

### 鼠标模式

- 进入暂停（shop / level-up / game-over）时：`Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)`
- 退出暂停（恢复游戏）时：`Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)`
- 由各暂停 UI 在 `_ready()` / `tree_exited()`（或 open/close 方法）中设置，不集中到 RunDirector。

### 护盾 regen 计时器

- 护盾的 `shield_regen_delay` 倒计时与 `shield_regen_rate` 每帧回盾**在暂停期间冻结**（因为 Player 是 PAUSABLE）。
- 即：在商店里停留 10 秒，护盾不会回。
- 这是"游戏暂停=时间停止"的一致语义。

### 暂停源互斥

- 三处暂停不会同时触发（shop 是 walk-in、level-up 是 XP 跨阈值、game over 是死亡）。
- 但理论边界：玩家在商店里时，已有的飞行弹体可能命中玩家触发死亡。此时以**先触发的暂停源为准**，后续暂停源忽略（即 shop 期间死亡 → 直接进 Game Over，跳过 shop UI）。
- 实现上：RunDirector 在触发新暂停前检查 `get_tree().paused`，若已暂停则不再叠加。

## 背景

issue 04（shop walk-in 暂停）、issue 05（XP 即时暂停）、issue 06（死亡冻结）三处都涉及暂停，但 Godot 的 `get_tree().paused` 是全局开关——任何 `PROCESS_MODE_PAUSABLE` 节点都会被冻结。若不在 ADR 层面统一 `process_mode`，会出现：UI 打开了但点不动（UI 也被冻结）、护盾在商店里偷偷回满、鼠标被锁死无法点按钮等 bug。

## 替代方案

| 方案 | 描述 | 否决原因 |
|------|------|----------|
| **A. 全局 pause + process_mode 分层（选中）** | 见上 | 与 Godot 惯例一致，最简单可靠 |
| B. 不用全局 pause，手动冻结各子系统 | RunDirector 维护 `frozen: bool`，各系统自己检查 | 侵入性大，每个怪物/AI/输入都得加 `if frozen: return`，易漏 |
| C. 每个暂停源用独立 `CanvasLayer` + 时间缩放 | `Engine.time_scale = 0` | time_scale 不冻结输入、不冻结 `_process`，不适合需要 UI 交互的场景 |

## 影响

- 三个暂停 UI 场景/节点的根节点必须设 `process_mode = PROCESS_MODE_WHEN_PAUSED`。
- 进入/退出暂停时需切换鼠标模式（由各 UI 自己负责）。
- RunDirector 触发暂停前需检查 `get_tree().paused` 做互斥。
- 护盾 regen 不需要特殊处理（Player 的 PAUSABLE 自然冻结 `_process`）。
- 测试时需注意：headless 测试若涉及暂停，被测 UI 节点要显式设 `process_mode`。
