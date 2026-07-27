# ADR 003 — Step 处理与怪物导航重构

**状态**：Accepted
**日期**：2026-07-24

## 背景

游戏中存在大量"低矮台阶"（垂直高度差 0.2-0.3m，如 [platform.tscn](file:///e:/work/sp/Starter-Kit-FPS/objects/platform.tscn) 的 0.2m 段、城市人行道边缘 curb）。用户报告：

1. 玩家走不上去，必须跳一下才能上去（虽然玩家有二段跳，性质是摩擦感而非阻塞）
2. **怪物完全上不去**——直接卡死在台阶前

根因调查（见下方"现状"）：

- 全部角色（玩家、`monster_melee`、`monster_ranged`）使用 `CharacterBody3D`，**未配置任何 floor_* 参数**，全走 Godot 4 默认值
- Godot 4 默认 `floor_snap_length = 0.3` **仅处理下坡吸附**，不处理上坡登高——这是社区常见误解
- 玩家：`jump_strength = 8 m/s`，默认开启二段跳，可跳过任何 ≤1m 障碍
- 怪物：[monster_melee.gd](file:///e:/work/sp/Starter-Kit-FPS/objects/monster_melee.gd) 和 [monster_ranged.gd](file:///e:/work/sp/Starter-Kit-FPS/objects/monster_ranged.gd) **没有任何 NavigationAgent3D**，纯水平朝玩家方向施加速度（抹掉 Y 分量），遇到任何 >0.3m 高度差直接卡死
- 飞行敌人 [enemy.gd](file:///e:/work/sp/Starter-Kit-FPS/objects/enemy.gd) 是 `Area3D`，不受此问题影响

## 决策

采用**分层方案**——玩家和怪物用不同的机制，但共用 `step_height = 0.3` 这个全局阈值：

### 1. 玩家：自定义 Auto-Step

在玩家移动循环中，`move_and_slide()` 之前插入一个 step-up 检测：

- 用 `ShapeCast3D` 或前向 `RayCast3D` 检测角色脚下 step_height 范围内的可登高面
- 若前方有 < step_height 的高差，且头顶有足够净空，将角色抬升到该高度
- 超过 step_height 的高差视为 Wall，不抬升（玩家须跳）

### 2. 怪物：NavigationAgent3D + 运行时自动烘焙 NavMesh

为 `monster_melee` 和 `monster_ranged` 添加 `NavigationAgent3D` 子节点，重写 `_physics_process` 的移动逻辑：

- 用 `NavigationServer3D` 在场景加载时从 GridMap 自动烘焙 navmesh（包装在 `NavigationRegion3D` 中）
- NavMesh 的 `Agent Max Climb` 设为 `step_height = 0.3`——这样 ≤0.3m 的高差在 navmesh 中表现为连通区域，怪物自动会走上去
- 怪物从 `NavigationAgent3D.get_next_path_position()` 获取下一路径点，朝该点（而非玩家位置）施加水平速度，然后 `move_and_slide()`
- 飞行敌人 `enemy.gd` 不变

### 3. 共享阈值参数

`step_height` 作为单一全局浮点参数（默认 `0.3`），玩家 Auto-Step 与怪物 NavMesh Agent Max Climb 共用——确保"统一可通行"的语义在两套实现中一致。

## 替代方案（被否决）

| 方案 | 否决理由 |
|---|---|
| **共享自定义 Auto-Step（玩家+怪物）** | 怪物仍会在墙角、凹形几何、>0.3m 障碍物处卡死。只解决 step 不解决路径规划。 |
| **怪物"撞墙即跳"** | 不是真正的 Auto-Step：0.2m 小台会跳动；0.4m 墙也会跳（破坏 step/wall 边界）；视觉混乱。 |
| **MeshLibrary 手动制作 navmesh** | 需为 15 个 `.glb` 结构手工绘制 navmesh，新增结构时需同步维护，工作量与可维护性差。 |
| **转换管线烘焙 navmesh** | 烘焙结果保存到 `.tscn`，启动零开销。但每次地图 JSON 变动必须重跑转换脚本，违背"运行时灵活"诉求。 |
| **单纯调大 `floor_snap_length`** | 误解：该参数仅处理下坡吸附，不处理上坡登高。技术上无效。 |

## 后果

**正面**：
- 玩家在小台阶前不再有摩擦感
- 怪物能正确寻路绕过障碍、跨过小台阶、追击玩家——`monster_melee` 和 `monster_ranged` 的 AI 行为整体升级
- step_height 作为单一参数，未来调整阈值时一处修改、两处生效

**负面 / 成本**：
- 怪物移动代码需重写（从"朝玩家方向施加速度"改为"朝下一路径点施加速度"）
- 场景加载时增加 navmesh 烘焙开销（典型几百 ms，可接受）
- `monster_melee.tscn` 和 `monster_ranged.tscn` 需添加 `NavigationAgent3D` 子节点
- 主场景需添加 `NavigationRegion3D` 包裹 GridMap

## 未在本次范围内

以下问题与 step 处理相关但**不属于本 ADR 决策范围**，留待后续：

- 怪物之间是否启用 `avoidance_enabled`（避免互相堆叠）——可选增强，单 flag 切换
- `player.gd` 在 `_process()` 而非 `_physics_process()` 调用 `move_and_slide()` 的现存问题——独立技术债
- 玩家是否也应使用 NavMesh——否，玩家是 WASD 输入驱动，NavMesh 不适用
