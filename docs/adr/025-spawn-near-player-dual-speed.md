# ADR 025 — 敌人刷新位置与双速移动模型

**状态**：Accepted
**日期**：2026-07-25

## 背景

当前敌人刷怪使用固定出生点（`SpawnPoints`），怪物从竞技场边缘出现，与玩家的初始距离不可控。此外，所有怪物在 `CHASE`/`LOST`/`JUMP` 状态下使用相同的 `move_speed`，`IDLE` 状态下完全静止——缺乏"逐渐逼近"的压迫感和节奏层次。

用户需求：
1. 刷怪时敌人优先降落在玩家周围的空旷地带
2. 敌人始终缓慢向玩家移动（未警觉时也逼近）
3. 追击触发后切换到最大速度战斗

## 决策

### 1. 刷怪位置：从固定出生点改为玩家周围 NavMesh 选点

保留波次制不变（ADR 009 / 018），仅修改 `run_director._spawn_all()` 的选点逻辑。

**选点策略**：

1. **近圈**（玩家水平距离 15–30m）：优先在 NavMesh 可达区域随机选点
2. **远圈**（30–60m）：近圈位置不足时退而求其次
3. **空旷地带判定**：
   - NavMesh 可达（`NavigationServer3D.map_get_closest_point()` 返回有效点）
   - 向下 RayCast（2m）命中地面——确认不是悬空/建筑内部
   - 向上 RayCast（5m）不命中——确认上方无天花板遮挡（排除室内）
4. **间距要求**：同波怪物出生点之间水平距离 ≥ 3m，避免堆叠
5. **空中降落的"着陆"效果**：仍复用现有 `DROP_HEIGHT=8m` 缓降机制（`_dropping` / `DROP_SPEED=3.5`），怪物在选定的地面位置上方 8m 生成然后缓降落地

**兜底**：NavMesh 选点全部失败时，退回原固定 `SpawnPoints` 逻辑。

**实现位置**：`run_director.gd` 新增 `_find_spawn_positions(count, player_pos) -> Array[Vector3]` 方法，替换 `_spawn_all()` 中的 `pts` 数组构建逻辑。

### 2. 双速移动模型

在 `monster_base.gd` 中新增 `drift_speed`（缓行速度），与现有 `move_speed`（追击/最大速度）分离。

**速度表**：

| 怪物类型 | move_speed（追击） | drift_speed（缓行） |
|---------|-------------------|-------------------|
| monster_melee | 3.5 | 1.2 |
| monster_ranged | 2.5 | 0.9 |
| enemy（飞行） | 4.0 | 1.5 |
| 各角色化敌人 | 按各自 `move_speed` | `move_speed × 0.35` |

`drift_speed` 由基类自动计算（`@export var drift_speed: float = 0.0`，=0 时 `_ready()` 中自动设为 `move_speed * 0.35`），子类也可显式覆盖。

**状态行为变更**：

| FSM 状态 | 旧行为 | 新行为 |
|---------|--------|--------|
| IDLE | 静止（`velocity = 0`） | 以 `drift_speed` 缓慢朝玩家移动 |
| CHASE | `move_speed` 追击 | 不变（仍用 `move_speed`） |
| LOST | `move_speed` 移向最后已知位置 | 不变 |
| JUMP | `move_speed` | 不变 |
| ATTACK | 静止 | 不变 |
| RETREAT | 后退（子类覆盖） | 不变 |

**动画适配**：`_select_animation()` 的速度阈值从单一的 `move_speed * 0.8` 改为动态判断——当前实际速度 > `(drift_speed + move_speed) / 2` 时播 `run`，否则播 `walk`。

### 3. 追击触发不变

CHASE 状态的触发条件完全不变：`awareness_range` 内视线检测 + Chain Aggro（`AlertSystem.emit_alert` / `has_alert_nearby`）。双速模型只改变 IDLE 和 CHASE 各自使用的速度值，不改变状态转换逻辑。

`enemy.gd`（飞行敌人）同样采用双速：默认以 `drift_speed` 追踪，进入 CHASE 以 `fly_speed`（原 `move_speed` 映射）全速追击。

## 替代方案

### 方案 B：新增 APPROACH 中间状态

在 IDLE 和 CHASE 之间插入独立的 `APPROACH` 状态（"缓行接近"）。

**被否决理由**：增加状态机复杂度（6→7 状态），但语义收益不大。IDLE 本身改为缓行移动即可表达"未警觉但逐渐逼近"的压迫感，且 IDLE ↔ CHASE 的转换逻辑无需改动。

### 方案 C：固定出生点 + 大范围随机偏移

在现有 `SpawnPoints` 基础上扩大随机偏移（±10m 甚至更大）。

**被否决理由**：出生点仍在竞技场边缘/固定位置，无法满足"降落在玩家周围"的核心需求——地图中央的玩家仍要等怪物从边缘走过来，开局几十秒无交互。

### 方案 D：完全移除固定出生点

彻底删除 `SpawnPoints` 节点和兜底逻辑。

**被否决理由**：兜底是防御性编程的基本实践——NavMesh 烘焙失败、玩家卡在天花板下等极端情况下，固定出生点保证游戏不崩溃。
