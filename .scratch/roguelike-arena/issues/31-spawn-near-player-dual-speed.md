# 31 — 敌人刷新位置与双速移动模型

Status: ready-for-agent
Type: task
Refs: ADR 025, CONTEXT.md「Enemy Spawn Zone / Dual Speed Model / Drift Speed / Spawn Point」

## 问题陈述

当前敌人刷怪使用固定出生点（`SpawnPoints`），怪物从竞技场边缘出现，与玩家的初始距离不可控——开局几十秒无交互，节奏拖沓。此外，所有怪物在 IDLE 状态下完全静止，缺乏"敌人逐渐逼近"的压迫感和节奏层次。

玩家期望：
1. 刷怪时敌人优先降落在玩家周围的空旷地带
2. 敌人始终缓慢向玩家移动（即使未警觉）
3. 追击触发后才切换到最大速度战斗

## 解决方案

保留波次制不变，仅修改 **刷怪位置选点逻辑** 和 **IDLE 状态移动行为**：

### A. 刷怪位置：玩家周围 NavMesh 选点

每波刷怪时，RunDirector 不再使用固定 `SpawnPoints`，而是以玩家位置为中心，在 NavMesh 可达区域随机选点：

- **近圈**（15–30m）：优先在此范围的 NavMesh 可达区域随机选点
- **远圈**（30–60m）：近圈位置不足时退而求其次
- **空旷地带判定**：NavMesh 可达 + 向下 RayCast 命中地面 + 向上 5m 无遮挡（排除室内）
- **间距要求**：同波怪物出生点水平距离 ≥ 3m，避免堆叠
- **空中降落**：复用现有 `DROP_HEIGHT=8m` 缓降机制，怪物在选定地面位置上方 8m 生成后缓降落地
- **兜底**：NavMesh 选点全部失败时，退回原固定 `SpawnPoints` 逻辑

### B. 双速移动模型

新增 `drift_speed`（缓行速度），与现有 `move_speed`（追击最大速度）分离：

| 怪物类型 | move_speed（追击） | drift_speed（缓行） |
|---------|-------------------|-------------------|
| monster_melee | 3.5 | 1.2 |
| monster_ranged | 2.5 | 0.9 |
| enemy（飞行） | 4.0 | 1.5 |
| 各角色化敌人 | 按各自 `move_speed` | `move_speed × 0.35` |

`drift_speed` 由基类自动计算（`@export var drift_speed: float = 0.0`，=0 时自动设为 `move_speed × 0.35`），子类可显式覆盖。

状态行为变更：
- **IDLE**：从静止改为 `drift_speed` 缓慢朝玩家移动
- **CHASE / LOST / JUMP**：不变，仍用 `move_speed` 全速
- **ATTACK / RETREAT**：不变

动画选择器：阈值从单一 `move_speed * 0.8` 改为动态 `(drift_speed + move_speed) / 2`，确保缓行播 `walk`，追击播 `run`。

## 用户故事

1. 作为玩家，我希望每波敌人从我周围的空旷地带出现，以便游戏节奏紧凑、开局不无聊
2. 作为玩家，我希望敌人在未被惊动时也缓慢向我移动，以便感受到逐渐逼近的压迫感
3. 作为玩家，我希望敌人追击后以全速冲向我来战斗，以便战斗反馈明确——缓行 vs 追击有明显速度区分
4. 作为玩家，我希望敌人在脱离追击（LOST）时仍以全速移向最后已知位置，以便它们不会莫名其妙减速
5. 作为玩家，我希望空中敌人（enemy）也有缓行和全速两档，以便飞行怪的行为节奏与地面怪一致
6. 作为玩家，我希望怪物出生后有缓降落地过程，以便我看到它们从空中落下时有反应时间
7. 作为玩家，我希望怪物不会在天花板下或建筑物内部出生，以便它们不会卡住或从难以置信的位置出现
8. 作为玩家，我希望多只怪物不会堆叠在同一位置出生，以便场面看起来自然合理
9. 作为玩家，我希望即使 NavMesh 选点失败（极端情况），游戏仍能回退到固定出生点继续运行，以便不会崩溃

## 实现决策

### 1. RunDirector 刷怪选点重构

- 保留波次制不动（`compute_wave_composition` / 预算公式 / 类型分阶段解锁不变）
- 在 `_spawn_all()` 中新增 `_find_spawn_positions(count, player_pos) -> Array[Vector3]` 方法
- 选点逻辑：
  1. 获取玩家位置（`_player.global_position`）
  2. 遍历 count 次，每次尝试在 NavMesh 上选点：
     - 以玩家位置为中心，`randf_range()` 在近圈（15–30m）内选水平距离和角度 → 候选点
     - 调用 `NavigationServer3D.map_get_closest_point()` 验证 NavMesh 可达
     - 向下 RayCast（2m）验证命中地面
     - 向上 RayCast（5m）验证无天花板遮挡
     - 与已选点水平距离 ≥ 3m
  3. 近圈尝试失败（如未找到足够位置）→ 扩大到远圈（30–60m）重试
  4. 全部失败 → 退回原固定 `SpawnPoints` 兜底逻辑
- `_spawn_monster()` 中，怪物 `global_position` 设在地面位置 + `DROP_HEIGHT`（8m）高度，复用现有缓降

### 2. monster_base 双速模型

- 新增 `@export var drift_speed: float = 0.0`
- `_ready()` 中：`if drift_speed <= 0.0: drift_speed = move_speed * 0.35`
- `_tick_idle()` 改为朝玩家方向以 `drift_speed` 移动：
  - 设置 `nav_agent.target_position = player.global_position`（缓行也走 NavMesh）
  - `_desired_velocity = dir * drift_speed`（替代原来的 `Vector3.ZERO`）
- `_tick_chase()` / `_tick_lost()` / `_tick_jump()` 不变，仍使用 `move_speed`
- `_select_animation()` 阈值改为动态：
  - `_animation_threshold() -> float: return (drift_speed + move_speed) / 2.0`
  - 实际水平速度 > threshold → "run"，否则 "walk"

### 3. enemy.gd（飞行敌人）双速适配

- enemy 不使用 NavMesh，不调用 `_tick_idle()`，其 IDLE 行为由 `_process()` 控制
- 新增 `drift_speed`（默认 `fly_speed * 0.35 ≈ 1.5`），`_ready()` 中自动计算
- 缓行阶段（未进入追逐）以 `drift_speed` 朝玩家移动
- 进入追逐后以 `fly_speed` 追击（不变）

### 4. RVO 避障适配

- IDLE 状态下缓行移动后，`_desired_velocity` 不再为零，RVO 避障需正常参与
- `nav_agent.max_speed` 应在 `_ready()` 设到 `move_speed`（上限），不影响 `drift_speed` 生效
- 缓降阶段（`_dropping`）仍不参与 RVO 避障（不变）

### 5. 出生点兜底保留

- 固定 `SpawnPoints` 节点保留在 `main.tscn` 中不动
- 仅在 `_find_spawn_positions()` 返回空数组时，才执行原固定出生点逻辑
- 兜底发生时记录 `push_warning("RunDirector: NavMesh选点失败，回退固定出生点")`

## 测试决策

### 测试原则

- 仅测试外部行为，不测内部实现细节（不直接访问 private 变量）
- 使用与 `test_run_director.gd` 和 `test_monster_died_signal.gd` 一致的测试模式：
  - 头文件 `extends` + `failures` 计数器 + `_check()` 断言
  - 通过 `_ready()` → `call_deferred("_run_tests")` 启动
  - 最后 `failures == 0` 打印 `[TEST] PASS`，否则 `[TEST] FAIL`

### 测试内容

**测试 1：drift_speed 自动计算**
- 实例化 monster_melee / monster_ranged，检查 `drift_speed` 是否 = `move_speed × 0.35`
- 手动设定 `drift_speed = 2.0` 后，检查未被覆盖

**测试 2：IDLE 缓行移动**
- 设置怪物为 IDLE 状态，玩家在远处
- 检查怪物 `_desired_velocity` 非零（朝玩家方向）
- 检查水平速度量级 ≈ `drift_speed`

**测试 3：CHASE 全速不变**
- 设置怪物为 CHASE 状态
- 检查移动速度为 `move_speed`（未被 `drift_speed` 拖慢）

**测试 4：动画选择阈值**
- 水平速度 < `(drift_speed + move_speed) / 2` → 播 "walk"
- 水平速度 > 阈值 → 播 "run"

**测试 5：刷怪位置选点（近圈）**
- 向 RunDirector 注入玩家位置（如 Vector3(0, 0, 0)）
- 调用 `_find_spawn_positions(count, player_pos)`
- 检查返回的每个点：水平距离在 15–60m 范围内
- 检查相邻点水平距离 ≥ 3m

**测试 6：刷怪位置兜底**
- 模拟 NavMesh 不可用（如没有 NavigationServer3D 注册地图）
- 调用刷怪后检查仍能产出位置（不退化为零，不崩溃）

### 测试先例

- `tests/test_run_director.gd`：RunDirector 波次/状态/奖励/清场测试（38 项断言）
- `tests/test_monster_died_signal.gd`：怪物 died 信号 + `_dead` 守卫测试

## 超出范围

- 不引入新的刷怪模式（如持续刷新/生存模式），波次制完整保留
- 不新增 FSM 状态（不引入独立的 APPROACH 状态），IDLE 改为缓行即可
- 不修改追击触发逻辑（awareness_range + Chain Aggro 不变）
- 不修改卡怪兜底、血包掉落、宝箱生成等其他 RunDirector 功能
- 不移除固定 `SpawnPoints` 节点（兜底保留）

## 补充说明

- 此规格基于 ADR 025 的 Grill 会话决策综合而成。ADR 025 记录了替代方案及其否决理由（详见 `docs/adr/025-spawn-near-player-dual-speed.md`）
- 实施时注意：缓降阶段的怪物（`_dropping = true`）不参与 IDLE 缓行（`_physics_process` 中提前 return），落地后 `_dropping = false` 才进入正常 AI tick
- RVO 避障的 `max_speed` 应始终设为 `move_speed`（上限值），不要设为 `drift_speed`——RVO 使用 `max_speed` 计算避障修正，不代表实际移动速度
