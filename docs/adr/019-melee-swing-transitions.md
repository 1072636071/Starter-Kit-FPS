# ADR 019: 近战挥砍过渡动画 —— 消除"剑一闪而过"突兀感

## 决策

为玩家近战挥砍加入**入场/出场过渡动画**，并相应拉长时序：

1. **枪剑切换过渡**：挥砍期间枪械 viewmodel（`CameraItem/Container`）下沉出屏（`position.y -= 1.0`），剑 viewmodel 从屏幕右上方（肩鞘位置）滑入到下劈起点；挥砍结束反向过渡（剑滑出、枪回升）。
2. **时序拉长**：挥砍总时长 `SWING_DURATION` 从 0.4s 拉到 0.6s（前摇 0.2s / 活跃帧 0.2s / 后摇 0.2s）；冷却 `melee_cooldown` 从 0.5s 拉到 0.7s，给蓄力与收剑留出分量。
3. **过渡与原三段并行**：入场过渡并行进前摇、出场过渡并行进后摇，不增加挥砍总时长之外的额外延迟。
4. **`_melee_active` 标志**：过渡期间 `_process` 中跳过 container lerp，让过渡 Tween 完全控制 `container.position`。
5. **剑初始变换缓存**：`_ready()` 中缓存 `_melee_sword_init_pos` / `_melee_sword_init_rot`，作为 `action_melee()` 入口强制重置基准，防连续挥砍残留与漂移。

伤害数值（40）与活跃帧伤害窗口（0.2s）保持不变，仅时序边界平移。

## 背景

旧实现（ADR 006 后续决策）中，剑的视图模型**瞬间出现、瞬间消失**（`visible` 硬切），同时**枪械 viewmodel 在挥砍期间仍然可见**，剑与枪在屏幕上重叠，加上挥砍整体仅 0.4s 偏快，三方面叠加导致挥砍视觉"一闪而过、突兀"，缺乏分量感与过渡质感。玩家无法看清"拔剑→劈下→收剑"的动作弧线，剑像贴图闪一下就消失，破坏近战的临场感。

## 替代方案

| 方案 | 描述 | 否决原因 |
|------|------|----------|
| **A. 三段 Tween 过渡（选中）** | 前摇并行（枪下沉+剑滑入）/ 活跃帧（剑下劈）/ 后摇并行（剑滑出+枪回升） | 视觉过渡自然；复用现有 Tween 机制；零场景改动 |
| B. AnimationPlayer 替代 Tween | 引入 AnimationPlayer 资源驱动过渡 | 需新建动画资源、维护成本高；与现有 Tween 风格不一致 |
| C. 仅拉长时序不做过渡 | 时序拉到 0.6s，但枪不下沉、剑不滑入 | 治标不治本——枪剑重叠问题仍在；剑仍硬切出现/消失 |
| D. 相机抖动增强打击感 | 加 camera shake | 解决"分量感"但不解决"枪剑重叠+硬切"问题；可作未来独立增强 |

## 影响

### 时序契约（取代 ADR 006 后续决策中的旧契约）

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
   - 枪 Container：`position.y` 0 → `GUN_DROP_Y`（-1.0，下沉出屏底部）
   - 剑 viewmodel：从屏外起点（`WINDUP_POS + INTRO_POS_OFFSET`、`WINDUP_ROT + INTRO_ROT_OFFSET`）滑入到 windup 终点（`start + WINDUP_POS`、`start + WINDUP_ROT`）
   - 同时剑 `visible = true` 在段首瞬设
2. **活跃帧段（0.2→0.4s，0.2s 时长）** —— 顺序：
   - 剑 viewmodel：从 windup 终点下劈到 `start - WINDUP_POS * 2` / `start - WINDUP_ROT * 2`（沿用原下劈偏移）
   - 枪 Container 保持下沉位不动
3. **后摇段（0.4→0.6s，0.2s 时长）** —— 并行：
   - 剑 viewmodel：从下劈终点滑出到屏外起点（与 intro 起点对称）
   - 枪 Container：`position.y` `GUN_DROP_Y` → 0（回升复位）
4. **收尾回调**：`tween_callback` 设 `melee_viewmodel_instance.visible = false` + 剑变换重置 + `_melee_active = false`

### 命中区 monitoring 时序

跟随新 `ACTIVE_START` / `ACTIVE_END`，仍用 `get_tree().create_timer()` 解耦（不嵌入 Tween）：

- `create_timer(0.2).timeout` → `melee_hitbox.monitoring = true`
- `create_timer(0.4).timeout` → `melee_hitbox.monitoring = false`

理由不变（见 CONTEXT.md「Active Frames」）：挥砍 Tween 被 `kill()` 时 monitoring 切换仍按时执行，避免滞留。

### 防漂移保障

- 剑 viewmodel 的 `start_position` / `start_rotation` 在 `_ready()` 中缓存为 `_melee_sword_init_pos` / `_melee_sword_init_rot`
- `action_melee()` 入口先 `kill()` 旧 Tween，再**强制重置**剑变换与枪 Container 位置到初始值，然后启动新 Tween
- 这是与旧实现的关键差异（旧实现无过渡，kill 后立即重建无残留问题）

### DPS 影响

- 旧 DPS：40 / 0.5s = 80
- 新 DPS：40 / 0.7s ≈ 57（-29%）
- 评估：近战定位为"短射程高单发"副攻击，DPS 下降由"过渡动画带来的可读性提升"补偿。若实战发现近战过弱，可单独调 `melee_damage`（不在本 ADR 范围）。

## 与 ADR 006 的关系

ADR 006 的核心架构决策（独立近战入口、与武器/弹药体系解耦、Area3D 命中区、Melee Viewmodel Lifecycle、近战-换弹并发、冷却实现、挥砍音效跳过）**全部保留不变**。本 ADR 仅修改 ADR 006「后续决策」表中的两个子决策（挥砍时序、挥砍动画样式）并新增过渡语义。

## 超出范围

- 挥砍音效（whoosh 素材）—— 仍跳过，需新增音频素材后单独接入
- AnimationPlayer 替代 Tween —— 已决策保留 Tween
- 左右交替挥砍变体 —— v2 增强
- 视角/相机程序的微小晃动（camera shake）—— 独立增强，可单独做
- 命中区几何调整 —— 不变（`BoxShape3D(1.5, 1.5, 2.0)`、中心 `(0, 0.5, -1.0)`）
- `melee_damage` 数值调整 —— 保持 40 不变
