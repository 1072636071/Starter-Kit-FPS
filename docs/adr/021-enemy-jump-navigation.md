# ADR 021：敌人跳跃导航系统

## 背景

玩家有二段跳能力（`jump_strength=8`，`number_of_jumps=2`），可以跳上 4m 高的 GridMap 建筑顶部。但敌人 AI 仅依赖 NavMesh 寻路，而 NavMesh 烘焙参数 `agent_max_climb = 0.3m`（`StepConstants.STEP_HEIGHT`）无法连接地面与建筑顶部（4m 落差）。结果是：玩家跳上建筑后，敌人站在地面无法追踪，表现"呆滞"。

## 决策

### 1. 使用 NavigationLink3D 实现智能寻路

Godot 4 的 `NavigationLink3D` 节点可以连接 NavMesh 上两个断开的多边形区域。当 `NavigationAgent3D` 到达链接起点时，触发 `link_reached` 信号，由游戏代码处理链接穿越（跳跃）。

**被否决的替代方案：**
- **简单反应式跳跃**（追到建筑脚下发现玩家在上方就原地跳）：不参与路径规划，可能跳不到正确位置，且无法处理"玩家在建筑中心、敌人在建筑另一侧"的场景。
- **调高 `agent_max_climb`**：会使 NavMesh 在 ≤4m 落差处全部连通，导致建筑侧面被视为"斜坡"，怪物会沿建筑侧面滑行而非跳跃，视觉诡异且破坏台阶/墙的语义区分。

### 2. 按怪物类型区分跳跃能力

| 类型 | `jump_height` | 能力含义 |
|------|--------------|---------|
| `monster_melee` | 5.0m | 能跳上一层建筑（4m）+ 余量，与玩家二段跳对等 |
| `monster_ranged` | 2.0m | 仅能跳上矮平台，保持距离型战斗风格 |

`jump_velocity` 由 `jump_height` 反推：
```
jump_velocity = sqrt(2 * gravity * jump_height)
```
其中 `gravity = 20.0`（与 `monster_base.gd` 重力加速度一致）。

### 3. 跳跃链接自动生成：GridMap 遍历 + NavMesh 分析兜底

**主策略（GridMap 遍历）：**
- 遍历 GridMap 所有已用 cell
- 对每个有建筑项的 cell，若上方 cell 为空 → 建筑顶部
- 对建筑顶部的 4 个水平邻居，若该邻居 cell 为空（可通行地面）→ 在边缘创建 `NavigationLink3D`
- 链接从地面边缘（`start`）指向建筑顶部边缘（`end`），双向

**兜底策略（NavMesh 分析）：**
- 烘焙后获取 NavMesh 多边形边缘
- 找垂直相邻（落差 ≤ `max_jump_height`）但水平距离 ≤ 0.5m 的断开边缘对
- 为这些边缘对创建 `NavigationLink3D`

兜底处理非 GridMap 地形（平台、矮墙等）。

### 4. 新增 JUMP 状态

FSM 状态枚举新增 `JUMP`：

```
IDLE → CHASE → JUMP  ──(落地)──→ CHASE
              → ATTACK → CHASE / IDLE
              → RETREAT → CHASE / LOST
              → LOST → IDLE / CHASE
```

- **进入**：`NavigationAgent3D.link_reached` 信号触发
- **行为**：水平朝链接终点移动 + 垂直 `jump_velocity` 升空；不可攻击
- **退出**：`is_on_floor()` 且空中时间 ≥ 0.1s（防首帧误判），切回 CHASE
- **动画**：尝试播放 `jump` 动画（若 GLB 有）；无则保持当前姿态

### 5. 仅导航跳跃，不用于战斗

跳跃仅用于追踪上了平台的玩家。不添加战斗闪避跳跃（侧跳躲子弹），保持 v1 范围最小。战斗闪避留作未来迭代。

### 6. 掉落自然处理

敌人从建筑上掉落时由物理自然处理（重力 + `move_and_slide`），落地后继续 CHASE 追踪。不施加掉落伤害。

## 实现拆分

1. `scripts/nav_jump_links.gd`（新建）— 静态工具类，GridMap 遍历 + `NavigationLink3D` 生成
2. `monster_base.gd` — 新增 JUMP 状态 + `link_reached` 信号处理 + `jump_height`/`jump_velocity`
3. `monster_melee.gd` — `jump_height = 5.0`
4. `monster_ranged.gd` — `jump_height = 2.0`
5. `nav_region.gd` — 烘焙后调用 `NavJumpLinks.generate()`

## 风险

- **NavMesh 分析兜底复杂度高**：低层 NavigationServer3D API 文档不完善，可能需降级为纯 GridMap 方案
- **跳跃动画**：怪物 GLB 动画列表未确认是否含 `jump`，需运行时检测
- **链接密度**：建筑边缘每个 cell 创建一个链接，密度可能过高，但 `NavigationAgent3D` 会自动选择最优路径