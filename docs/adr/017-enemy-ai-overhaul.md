# ADR 017 — 敌人 AI 系统全面重构

**状态**：Accepted
**日期**：2026-07-25

## 背景

当前敌人 AI 存在多个已知问题和隐患：

1. **怪物互相堆叠**：`avoidance_enabled` 未开启，多只怪重叠在同一位置
2. **飞行敌人无真正 AI**：`enemy.gd` 只在出生点做正弦浮动 + 定时射击，不追踪玩家
3. **无视线检测**：怪物隔墙也能"感知"玩家（纯距离判定），破坏沉浸感
4. **无行为状态机**：逻辑全在 `_physics_process` 的 if/elif 链中，难以扩展
5. **无路径更新节流**：每帧都设 `nav_agent.target_position`，16 只怪时性能浪费
6. **无战术行为**：所有近战怪冲向同一点，堆成一团
7. **NavMesh 参数粗糙**：未设 `agent_radius`、`agent_height`、`cell_size`，路径质量低
8. **隐藏问题**：怪物间物理碰撞与未来 RVO 冲突、远程怪 strafe 方向固定（不随机）

## 决策

### 1. AI 架构：手写 FSM（enum + match）

在 `monster_base.gd` 中定义状态枚举和状态机框架：

```gdscript
enum AIState { IDLE, CHASE, ATTACK, RETREAT, LOST }
var _ai_state: AIState = AIState.IDLE
```

- 基类管理状态转换框架（`_change_state()`、`_tick_state(delta)`）
- 子类覆盖各状态的具体行为（虚方法）
- 取代原 `_physics_process` 中的 if/elif 链

**选择理由**：项目是 Roguelike 竞技场，怪物行为模式有限（3 种怪 + 未来 Boss），不需要行为树的复杂编排。零依赖 = 零版本兼容风险（Godot 4.6 较新）。

### 2. RVO 避障 + 怪物碰撞隔离

- 所有地面怪物启用 `avoidance_enabled = true`
- 通过 `velocity_computed(safe_velocity)` 信号回调获取安全速度
- 怪物间**关闭物理碰撞**（collision layer 隔离），间距完全由 RVO 管理
- 参数：`radius=0.5`、`neighbor_distance=5.0`、`max_neighbors=8`

### 3. 视线检测（Line of Sight）

- 从怪物眼部（`+1.2m`）向玩家胸部（`+0.8m`）发射 RayCast3D
- 被挡时进入 LOST 状态：移动到最后已知位置 → 环顾 2s → 回 IDLE 或重新 CHASE
- 视线检测频率：每 0.2s 一次（非每帧）

### 4. 路径节流 + 错帧更新

- 路径目标每 0.3s 更新一次（CHASE），LOST 状态 0.6s
- 每只怪按出生序号错开更新帧（`index * 0.05s` 偏移）
- 16 只怪分 6 帧处理，每帧最多 3 只请求路径

### 5. 飞行敌人 AI 重写

- 追踪玩家 + 保持悬停高度（4m）+ 环绕 strafing
- 纯向量计算（不用 NavMesh），`lerp` 平滑移动
- 被墙挡时升高越过

### 6. NavMesh 参数优化

- `agent_radius = 0.5`、`agent_height = 1.5`、`cell_size = 0.25`
- 更小的 cell_size 使路径更贴合墙壁

### 7. 战术散开

- 近战怪按序号分配环绕偏移角，从不同方向包围玩家
- 远程怪 strafe 方向随机化（不再固定 cross 方向）

## 替代方案（被否决）

| 方案 | 否决理由 |
|------|----------|
| **LimboAI 行为树插件** | 引入 GDExtension 外部依赖；Godot 4.6 兼容风险；项目怪物行为有限，杀鸡用牛刀 |
| **Beehave 行为树** | 功能弱于 LimboAI，无可视化调试器；仍是外部依赖 |
| **怪物间保留物理碰撞 + RVO** | 物理碰撞与 RVO 互相打架导致抖动；二选一时 RVO 更平滑可控 |
| **每帧更新路径** | 16 只怪 × 60fps = 960 次/秒路径请求，浪费；0.3s 间隔足够（玩家速度有限） |
| **飞行敌人用 NavMesh** | 飞行无视地形，NavMesh 是地面系统；纯向量更简单正确 |

## 后果

**正面**：
- 怪物不再堆叠，视觉自然
- 隔墙不再追踪，沉浸感提升
- 飞行敌人有威胁性（会追踪、环绕）
- 状态机框架使未来新增怪物类型/Boss 只需覆盖状态行为
- 路径节流 + 错帧使 16+ 只怪时性能可控
- 战术散开使战斗更有层次感

**负面 / 成本**：
- `monster_base.gd` 大幅重写（状态机 + RVO 回调模式）
- 两个子类（melee/ranged）的 `_physics_process` 全部重构
- `enemy.gd` 完全重写
- 碰撞层重新规划（需同步检查弹体、近战命中区的 layer/mask）
- NavMesh cell_size 缩小 → 烘焙时间略增（从几百 ms 到 ~1s，仍为一次性开销）

## 碰撞层规划

| Layer | 用途 |
|-------|------|
| 1 | 地形/环境（GridMap、墙壁、平台） |
| 2 | 怪物身体（怪物 CharacterBody3D） |
| 3 | 玩家身体 + 玩家攻击区（近战 Hitbox） |
| 4 | 弹体（玩家和怪物的 Projectile） |

- 怪物 mask：layer 1（地形碰撞）+ layer 4（被弹体命中）
- 玩家 mask：layer 1（地形）+ layer 2（被怪物身体阻挡？否——怪物碰撞隔离后不挡玩家）→ layer 1 only
- 弹体 mask：layer 1（撞墙消失）+ layer 2（命中怪物）+ layer 3（命中玩家）

**注**：怪物不挡玩家是设计选择——Roguelike 竞技场中玩家应能穿过怪群（否则被怪围住无法移动 = 软锁）。怪物对玩家的伤害通过攻击判定（距离/弹体），不通过物理碰撞。
