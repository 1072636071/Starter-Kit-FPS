# 06 - 敌人 AI 系统全面重构

Status: ready-for-agent
Type: feature

## 问题陈述

作为玩家，我在竞技场中遇到的敌人表现愚蠢且破坏沉浸感：多只怪物重叠在同一位置像"纸片人堆"；隔着一堵墙怪物依然精准追踪我；飞行敌人只会在出生点原地浮动毫无威胁；所有近战怪从同一方向冲来毫无战术感。这些问题让战斗体验从"紧张刺激"降级为"打固定靶"。

## 解决方案

全面重构敌人 AI 系统：引入有限状态机（FSM）架构使行为可扩展；启用 RVO 动态避障消除堆叠；加入视线检测使怪物不再隔墙追踪；重写飞行敌人使其主动追踪环绕；优化 NavMesh 参数和路径更新策略提升性能与路径质量；加入战术散开使多怪战斗有层次感。

## 用户故事

1. 作为玩家，我想要看到多只怪物彼此保持间距而非重叠，以便战斗场景看起来自然真实
2. 作为玩家，我想要怪物在我躲到墙后时失去我的踪迹并搜索，以便我能利用地形进行战术规避
3. 作为玩家，我想要怪物在搜索未果后放弃追踪回到待机，以便"躲藏"策略有实际意义
4. 作为玩家，我想要飞行敌人主动追踪我并环绕射击，以便它有真正的威胁性而非固定靶
5. 作为玩家，我想要多只近战怪从不同方向包围我，以便战斗有层次感和紧迫感
6. 作为玩家，我想要远程怪物的横移方向不可预测，以便我不能简单预判它的走位
7. 作为玩家，我想要怪物绕过墙壁和障碍物来追我而非卡在墙角，以便追逐体验流畅
8. 作为玩家，我想要在 16+ 只怪同屏时游戏依然流畅，以便后期波次不卡顿
9. 作为玩家，我想要怪物能跨上小台阶（≤0.3m）继续追我，以便地形不成为我的"安全岛"
10. 作为玩家，我想要穿过怪群时不被物理阻挡，以便我永远不会被怪物围住导致软锁
11. 作为玩家，我想要怪物被弹体命中时正常受伤，以便碰撞层重构不影响射击手感
12. 作为玩家，我想要近战攻击能正常命中怪物，以便碰撞层重构不影响近战手感
13. 作为开发者，我想要新增怪物类型时只需覆盖状态行为方法，以便扩展 AI 无需改动框架
14. 作为开发者，我想要状态转换逻辑集中在基类管理，以便调试 AI 行为有统一入口
15. 作为开发者，我想要路径计算分散到不同帧，以便峰值性能可控
16. 作为开发者，我想要碰撞层有清晰的规划文档，以便后续新增实体时不破坏碰撞关系

## 实现决策

### AI 架构

- 采用手写有限状态机（FSM）：`enum AIState { IDLE, CHASE, ATTACK, RETREAT, LOST }`
- 基类（monster_base）定义状态机框架：`_change_state(new_state)` 管理转换、`_tick_state(delta)` 分发到当前状态处理
- 子类通过覆盖虚方法实现各状态行为：`_tick_idle(delta)`、`_tick_chase(delta)`、`_tick_attack(delta)`、`_tick_retreat(delta)`、`_tick_lost(delta)`
- 状态转换条件在基类的 `_evaluate_transitions()` 中统一评估（距离、视线、攻击冷却）
- 取代原 `_physics_process` 中的 if/elif 链

### RVO 避障

- 所有地面怪物（monster_melee、monster_ranged）启用 `avoidance_enabled = true`
- 移动模式改为信号回调：`_physics_process` 计算 desired_velocity → 设给 `nav_agent.velocity` → `velocity_computed(safe_velocity)` 回调中执行 `move_and_slide()`
- 参数：`radius=0.5`、`neighbor_distance=5.0`、`max_neighbors=8`、`max_speed=move_speed`
- `avoidance_layers=1`、`avoidance_mask=1`（所有地面怪物互相避让）
- 飞行敌人（enemy）不参与 RVO（Node3D，无 CharacterBody3D）

### 怪物碰撞隔离

- 怪物 CharacterBody3D 的 `collision_layer = 2`（layer 2 = 怪物层）
- 怪物 `collision_mask = 1`（只与地形碰撞，不与其他怪物碰撞）
- 怪物间距完全由 RVO 管理
- 玩家 `collision_mask` 不含 layer 2 → 玩家可穿过怪群（防软锁设计）
- 弹体 Area3D 的 `collision_mask` 含 layer 2（命中怪物）+ layer 3（命中玩家）+ layer 1（撞墙消失）

### 碰撞层总规划

- Layer 1：地形/环境（GridMap、墙壁、平台）
- Layer 2：怪物身体
- Layer 3：玩家身体 + 玩家攻击区（近战 Hitbox）
- Layer 4：弹体（玩家和怪物的 Projectile）

### 视线检测

- 每只地面怪物持有一个 RayCast3D（运行时创建或场景预置）
- 从怪物眼部（`global_position + Vector3(0, 1.2, 0)`）向玩家胸部（`player.global_position + Vector3(0, 0.8, 0)`）射线
- 检测频率：每 0.2s 一次（`_los_timer`），非每帧
- 射线命中非玩家物体 → 视线被挡 → 记录 `_last_known_player_pos` → 进入 LOST 状态
- 射线命中玩家或无命中 → 视线通畅 → 更新 `_last_known_player_pos` → 维持/进入 CHASE

### LOST 状态行为

- 移动到 `_last_known_player_pos`（通过 NavMesh 寻路）
- 到达后环顾 2s（`_look_timer`，缓慢左右转向扫描）
- 环顾期间每 0.2s 检测视线，若恢复 → CHASE
- 环顾结束仍未恢复 → IDLE
- LOST 状态路径更新频率降至 0.6s（节省性能）

### 路径节流与错帧

- `path_update_interval = 0.3s`（CHASE），LOST 状态 0.6s
- 每只怪在 `_ready()` 中按出生序号计算 `_path_timer_offset = (spawn_index % 6) * 0.05`
- 路径计时器初始值 = offset，之后每 interval 重置
- 16 只怪分 6 帧处理，每帧最多 3 只请求路径

### 飞行敌人 AI 重写

- 保持悬停高度：`hover_height = 4.0m`（相对地面，用 RayCast3D 向下检测地面高度）
- 水平追踪：朝玩家方向以 `fly_speed = 4.0` 移动，使用 `lerp` 平滑
- 保持距离：`preferred_distance = 8.0m`，太近后退、太远靠近、理想距离环绕 strafing
- 环绕 strafing：以玩家为圆心、preferred_distance 为半径做圆周运动（方向随机）
- 被墙挡时（前向 RayCast 检测）：升高 2m 越过或绕行
- 射击逻辑保留（定时弹幕），但散布参数随距离衰减（已有）
- 不使用 NavMesh（飞行无视地形），纯向量计算

### NavMesh 参数优化

- `agent_radius = 0.5`（与怪物碰撞体 CapsuleShape3D radius=0.4 匹配 + 缓冲）
- `agent_height = 1.5`（怪物模型高度）
- `cell_size = 0.25`（从默认 0.3 提升精度，路径更贴合墙壁）
- `agent_max_climb = StepConstants.STEP_HEIGHT`（不变，0.3）
- `agent_max_slope = 45.0`（默认）

### 战术散开

- 近战怪物：每只按出生序号分配环绕偏移角 `_approach_angle = spawn_index * (TAU / alive_count)`
- 实际追踪目标 = 玩家位置 + `Vector3(cos(angle), 0, sin(angle)) * 1.5`（半径 1.5m 圆上）
- 远程怪物：strafe 方向随机化（`_strafe_dir = [-1, 1].pick_random()`），每 2-3s 随机切换
- 飞行敌人：环绕方向随机（顺时针/逆时针）

### 缓降兼容

- 缓降阶段（`_dropping = true`）FSM 不运行，状态保持 IDLE
- 落地后 FSM 启动，初始状态 IDLE → 检测到玩家在 chase_range 内 → CHASE

### 死亡兼容

- `_dead = true` 后 FSM 停止 tick（`_tick_state` 顶部守卫）
- `died` 信号发射逻辑不变（destroy() 内、queue_free() 前）
- RVO agent 在 destroy() 中设为 `avoidance_enabled = false`（避免死亡后仍参与避障计算）

## 测试决策

### 什么是好测试

- 仅测试外部可观测行为（状态转换、位置变化、信号发射、配置值），不测内部实现细节
- 测试"怪物做了什么"而非"怪物怎么做的"
- 每个测试用例独立，不依赖其他测试的副作用

### 测试 seam

- 复用现有模式：实例化怪物场景 → 提供 dummy player（"player" 组 Node3D）→ 跑物理帧 → 断言公共属性/信号
- 无需新建 seam

### 被测试的模块

- `monster_base.gd`：FSM 状态转换、RVO 配置、视线检测触发 LOST、路径节流配置
- `monster_melee.gd`：CHASE 行为（朝玩家移动）、ATTACK 触发（距离内）、战术散开偏移
- `monster_ranged.gd`：RETREAT 行为（太近后退）、strafe 方向随机化
- `enemy.gd`：追踪行为（position 朝玩家变化）、悬停高度维持、环绕 strafing
- `nav_region.gd`：NavMesh 参数验证（agent_radius、cell_size 等）
- 碰撞层：验证所有怪物/玩家/弹体的 collision_layer/mask 值

### 测试先例

- `tests/test_monster_died_signal.gd`：实例化三种怪物 + dummy player + 断言信号
- `tests/test_monster_fall_death.gd`：物理帧驱动 + 位置操作 + 信号断言 + RunDirector 集成

### 测试用例概要

1. FSM 初始状态为 IDLE，缓降落地后检测到玩家 → 转为 CHASE
2. CHASE 状态下怪物 position 逐帧靠近玩家
3. 进入 attack_range → 转为 ATTACK，发射攻击
4. 视线被挡（中间放 StaticBody3D）→ 转为 LOST
5. LOST 状态到达最后已知位置 + 环顾超时 → 转为 IDLE
6. RVO 配置验证：`nav_agent.avoidance_enabled == true`
7. 碰撞层验证：怪物 `collision_layer == 2`，`collision_mask == 1`
8. 飞行敌人追踪：多帧后 position.xz 靠近 player.xz
9. 飞行敌人悬停：position.y 维持在 hover_height 附近
10. NavMesh 参数：`navigation_mesh.agent_radius == 0.5`、`cell_size == 0.25`
11. 两只怪物同帧不重叠（RVO 生效后 position 间距 > 0.8）
12. 远程怪太近时后退（position 远离玩家）

## 超出范围

- **Boss AI**：多阶段 Boss 行为设计留待未来，FSM 框架为其预留扩展点但本次不实现
- **怪物间协作/编队**：本次只有"散开"，不做真正的编队/掩护/协同攻击
- **动态障碍物（NavigationObstacle3D）**：可破坏物/移动平台的实时 navmesh 更新不在本次范围
- **难度自适应 AI**：根据玩家水平调整怪物行为参数不在本次范围
- **怪物跳跃**：怪物仍不跳跃（NavMesh 已处理 ≤0.3m 台阶，更高障碍绕路）
- **玩家碰撞层变更的连锁影响**：本次只确保现有功能（弹体、近战、怪物伤害）不因碰撞层重构而断裂，不做新的玩家交互

## 补充说明

- 参见 [ADR 017](../../docs/adr/017-enemy-ai-overhaul.md) 了解完整决策背景与被否决方案
- 参见 [CONTEXT.md「敌人 AI 系统」章节](../../CONTEXT.md) 了解所有新增术语定义
- 碰撞层重构需同步检查：`objects/projectile.tscn`（弹体 Area3D mask）、`objects/player.tscn`（玩家 CollisionShape3D layer）、`objects/melee_viewmodel.tscn`（近战 Hitbox Area3D mask）、`objects/enemy.tscn`（飞行敌人 Area3D）
- 现有测试（`test_monster_died_signal`、`test_monster_fall_death`）必须在重构后继续通过——它们是回归基线
- NavMesh cell_size 缩小到 0.25 会使烘焙时间从几百 ms 增到约 1s，仍为场景加载时一次性开销，可接受
- 怪物不挡玩家是刻意设计：Roguelike 竞技场中玩家被怪围住无法移动 = 软锁。伤害通过攻击判定（距离/弹体），不通过物理碰撞
