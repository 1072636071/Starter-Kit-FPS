Status: ready-for-agent

# 近战挥砍过渡动画 — 消除"剑一闪而过"突兀感

## 问题陈述

玩家按 V 触发近战挥砍时，剑的视图模型**瞬间出现、瞬间消失**（`visible` 硬切），同时**枪械 viewmodel 在挥砍期间仍然可见**，剑与枪在屏幕上重叠，加上挥砍整体仅 0.4s 偏快，三方面叠加导致挥砍视觉"一闪而过、突兀"，缺乏分量感与过渡质感。玩家无法看清"拔剑→劈下→收剑"的动作弧线，剑像贴图闪一下就消失，破坏近战的临场感。

## 解决方案

为近战挥砍加入**入场/出场过渡动画**，并相应拉长时序：

1. **枪剑切换过渡**：挥砍期间枪械 viewmodel（`CameraItem/Container`）下沉出屏，剑 viewmodel 从屏幕右上方（肩鞘位置）滑入到下劈起点；挥砍结束反向过渡（剑滑出、枪回升）。
2. **时序拉长**：挥砍总时长从 0.4s 拉到 0.6s（前摇 0.2s / 活跃帧 0.2s / 后摇 0.2s），冷却从 0.5s 拉到 0.7s，给蓄力与收剑留出分量。
3. **过渡与原三段并行**：入场过渡并行进前摇、出场过渡并行进后摇，不增加挥砍总时长之外的额外延迟。

伤害数值（40）与活跃帧伤害窗口（0.2s）保持不变，仅时序边界平移。

## 用户故事

1. 作为玩家，我想要按 V 时剑从右上方滑入视野而不是凭空闪现，以便看清"拔剑"动作的发生。
2. 作为玩家，我想要挥砍期间枪械 viewmodel 下沉出屏，以便剑独占视觉舞台、不与枪重叠造成混乱。
3. 作为玩家，我想要挥砍动画有更长的前摇（0.2s），以便感受到"举剑蓄力"的分量。
4. 作为玩家，我想要挥砍动画有更长的后摇（0.2s），以便感受到"收剑"的余韵而不是瞬切消失。
5. 作为玩家，我想要挥砍结束后剑从右上方滑出视野，以便动作收尾自然而非突兀消失。
6. 作为玩家，我想要挥砍结束后枪械 viewmodel 从屏幕下方回升复位，以便射击视角无缝恢复。
7. 作为玩家，我想要挥砍伤害数值与伤害窗口保持不变（40 伤害 / 0.2s 活跃帧），以便近战 DPS 平衡不被过渡动画破坏。
8. 作为玩家，我想要冷却从 0.5s 调整到 0.7s 以匹配新的挥砍时长，以便节奏自然且不出现"挥砍未结束冷却已就绪"的冲突。
9. 作为玩家，我想要连续按 V 时不会出现动画叠加或状态残留，以便每次挥砍都是干净的完整动作。
10. 作为玩家，我想要挥砍结束后剑的 position/rotation 精确回到初始值，以便多次挥砍不产生累积漂移。
11. 作为玩家，我想要挥砍结束后枪 Container 的 position.y 精确回到 0，以便射击视角不偏移。
12. 作为玩家，我想要换弹中按 V 仍能触发过渡挥砍（近战-换弹互不阻塞语义不变），以便战斗灵活性不退化。
13. 作为玩家，我想要挥砍中按 R 仍能触发换弹，以便战斗灵活性不退化。
14. 作为玩家，我想要活跃帧命中区（Melee Hitbox）monitoring 窗口跟随新时序（0.2s 开启、0.4s 关闭），以便伤害结算时点与剑身位置一致。

## 实现决策

### 模块改动

- 修改 `objects/player.gd`：重写 `action_melee()` 的 Tween 链，更新时序常量与默认 cooldown
- 不修改场景结构（`melee_viewmodel.tscn` / `player.tscn` 保持现状），全部用 Tween 驱动现有节点
- 不修改 `Weapon` 资源、`action_shoot()`、弹药/换弹逻辑

### 时序契约（替换 ADR 006 后续决策中的旧契约）

| 量 | 旧值 | 新值 |
|---|---|---|
| `SWING_DURATION` | 0.4s | 0.6s |
| `melee_cooldown`（默认） | 0.5s | 0.7s |
| `ACTIVE_START` | 0.1s | 0.2s |
| `ACTIVE_END` | 0.3s | 0.4s |
| 前摇 windup | 0.1s | 0.2s |
| 活跃帧 active | 0.2s | 0.2s（不变） |
| 后摇 recover | 0.1s | 0.2s |

约束：`SWING_DURATION ≤ melee_cooldown` 仍成立（0.6 ≤ 0.7，留 0.1s 缓冲）。

### 动画 Tween 链结构

挥砍 Tween 链分三段，每段内并行 tween 枪 Container 与剑 viewmodel：

1. **前摇段（0.0→0.2s，0.2s 时长）** —— 并行：
   - 枪 Container：`position.y` 0 → -1.0（下沉出屏底部）
   - 剑 viewmodel：从屏外起点（`WINDUP_POS + (0.5, 0.5, 0)`、`WINDUP_ROT + (-30, 0, 30)`）滑入到 windup 终点（`start + WINDUP_POS`、`start + WINDUP_ROT`）
   - 同时剑 `visible = true` 在段首瞬设
2. **活跃帧段（0.2→0.4s，0.2s 时长）** —— 顺序：
   - 剑 viewmodel：从 windup 终点下劈到 `start - WINDUP_POS * 2` / `start - WINDUP_ROT * 2`（沿用原下劈偏移）
   - 枪 Container 保持下沉位不动
3. **后摇段（0.4→0.6s，0.2s 时长）** —— 并行：
   - 剑 viewmodel：从下劈终点滑出到屏外起点（与 intro 起点对称）
   - 枪 Container：`position.y` -1.0 → 0（回升复位）
4. **收尾回调**：`tween_callback` 设 `melee_viewmodel_instance.visible = false`

### 命中区 monitoring 时序

跟随新 `ACTIVE_START` / `ACTIVE_END`，仍用 `get_tree().create_timer()` 解耦（不嵌入 Tween）：

- `create_timer(0.2).timeout` → `melee_hitbox.monitoring = true`
- `create_timer(0.4).timeout` → `melee_hitbox.monitoring = false`

理由不变（见 CONTEXT.md「Active Frames」）：挥砍 Tween 被 `kill()` 时 monitoring 切换仍按时执行，避免滞留。

### 防漂移保障

- 剑 viewmodel 的 `start_position` / `start_rotation` 在 `action_melee()` 入口缓存
- 三段 Tween 的所有 `to_val` 均以缓存的 `start_*` 为基准（非"上一段终点"），与现有实现一致
- 枪 Container 的 `position.y` 在 outro 段显式 tween 回 0，不依赖"反向偏移"以防浮点累积

### 连续挥砍处理

- 入口 `if melee_swing_tween and melee_swing_tween.is_valid(): melee_swing_tween.kill()` 不变
- kill 后 `container.position.y` 与剑变换可能停留在中间值——`action_melee()` 入口需**强制重置**两者到初始值（枪 y=0、剑 position/rotation=start）后再启动新 Tween
- 这是与旧实现的关键差异（旧实现无过渡，kill 后立即重建无残留问题）

### 文档同步

- 新建 `docs/adr/019-melee-swing-transitions.md`：记录过渡动画决策、被取代的 ADR 006 子决策、新时序契约（注：ADR 018 已被 score-based-wave-composition 占用，故本 ADR 编号为 019）
- 更新 `CONTEXT.md`「近战系统（Melee）」：
  - `Swing Duration` 条目：0.4s → 0.6s
  - `Active Frames` 条目：0.1–0.3s → 0.2–0.4s
  - `Melee Tuning` 条目：`melee_cooldown` 0.5s → 0.7s
  - 新增术语 `Melee Viewmodel Transition`：描述枪下沉+剑滑入/出的过渡语义
- 更新 `docs/adr/006-melee-as-independent-system.md`「后续决策」表：在挥砍时序、挥砍动画样式两行加注"被 ADR 019 取代"

## 测试决策

### 测试 Seam

唯一 seam = `player.gd::action_melee()` 的**外部可观察状态**。Headless 测试调用 `action_melee()` + `await get_tree().create_timer(t).timeout` 推进时间，断言公共节点状态。复用现有 GUT + `await create_timer` 模式（参考 `test_monster_died_signal.gd`、`test_arena_shield.gd`）。

### 不测的（实现细节）

- Tween 内部曲线 / 缓动类型 / `tween.parallel()` 调用结构
- 剑在某个具体时刻的精确 position/rotation 数值（曲线细节）
- 枪 Container 在过渡中途的 y 值（中间状态）

### 测的（外部行为）

新建 `tests/test_melee_transitions.gd` + `tests/test_melee_transitions.tscn`，断言：

| 断言 | 时刻 | 期望 |
|---|---|---|
| 冷却门禁 | t=0 调用 `action_melee()` 后立即再调 | 第二次无副作用（`melee_swing_tween` 引用不变、cooldown_remaining 不重置） |
| hitbox monitoring 窗 | t=0 / 0.1 / 0.25 / 0.45 / 0.7 | false / false / true / false / false |
| 枪 Container 复位 | t=0.7 | `container.position.y == 0.0`（容差 0.001） |
| 剑隐藏 | t=0.7 | `melee_viewmodel_instance.visible == false` |
| 剑变换复位 | t=0.7 | position/rotation 等于挥砍前缓存的初始值（容差 0.001） |
| cooldown 解锁 | t=0.7 后再调 `action_melee()` | 新 Tween 创建（`melee_swing_tween` 引用变化）、`melee_cooldown_remaining` 重置为 0.7 |
| 连续挥砍无残留 | t=0.2 时再次调 `action_melee()`（kill 旧 Tween） | 枪 y 与剑变换被强制重置到初始值后再启动新 Tween，t=0.9 时全部复位 |

### 测试先例

- `tests/test_monster_died_signal.gd`：`await get_tree().create_timer(t).timeout` + 信号/状态断言
- `tests/test_arena_shield.gd`：实例化场景、调用公共方法、断言节点状态
- `tests/test_ammo_system.gd`：状态机时序断言

## 超出范围

- 挥砍音效（whoosh 素材）—— 仍跳过，需新增音频素材后单独接入
- AnimationPlayer 替代 Tween —— 已决策保留 Tween
- 左右交替挥砍变体 —— v2 增强
- 视角/相机程序的微小晃动（camera shake）增强打击感 —— 独立增强，可单独做
- 命中区几何调整 —— 不变（`BoxShape3D(1.5, 1.5, 2.0)`、中心 `(0, 0.5, -1.0)`）
- 怪物近战动画 —— 走 AnimationPlayer 骨骼剪辑体系（ADR 008），与玩家 viewmodel Tween 体系无关
- `melee_damage` 数值调整 —— 保持 40 不变

## 补充说明

### DPS 影响评估

- 旧 DPS：40 / 0.5s = 80
- 新 DPS：40 / 0.7s ≈ 57（-29%）
- 评估：近战定位为"短射程高单发"副攻击，DPS 下降由"过渡动画带来的可读性提升"补偿。若实战发现近战过弱，可单独调 `melee_damage`（不在本规格范围）。

### 与 ADR 006 的关系

ADR 006 的核心架构决策（独立近战入口、与武器/弹药体系解耦、Area3D 命中区、Melee Viewmodel Lifecycle、近战-换弹并发、冷却实现、挥砍音效跳过）**全部保留不变**。本规格仅修改 ADR 006「后续决策」表中的两个子决策（挥砍时序、挥砍动画样式）并新增过渡语义，以 ADR 019 形式记录演进（ADR 018 编号已被 score-based-wave-composition 占用）。

### 与 player.tscn 的关系

不修改 `player.tscn`。`container` 节点已有 `@onready var container` 引用（见 `player.gd:133`），`melee_viewmodel_instance` 在 `_ready()` 中实例化挂 `CameraItem` 下（见 `player.gd:169-172`）—— 两者均为现成节点引用，过渡动画纯靠 Tween 驱动，零场景改动。

### 防漂移设计动机

旧实现三段 Tween 的 `to_val` 均以 `start_*` 为基准，kill 后重建无残留问题。新实现加入过渡后，若在过渡中途 kill，剑/枪可能停留在屏外或下沉位——故 `action_melee()` 入口必须**强制重置**两者到初始值。这是新实现相对旧实现的关键防御性差异，测试用例 7（连续挥砍无残留）专门覆盖此路径。
