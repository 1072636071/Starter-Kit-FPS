# PRD：敌人跳跃导航系统

**Status:** ready-for-agent

## 问题陈述

玩家有二段跳能力，可以跳上 4m 高的 GridMap 建筑顶部。但敌人 AI 仅依赖 NavMesh 寻路，NavMesh 烘焙参数 `agent_max_climb = 0.3m` 无法连接地面与建筑顶部（4m 落差）。结果是：玩家跳上建筑后，敌人站在地面无法追踪，表现"呆滞"——近战怪被风筝致死，远程怪也无法追到射击位置。

## 解决方案

为地面怪物（`monster_melee`、`monster_ranged`）添加跳跃导航能力：在 NavMesh 烘焙后自动生成 `NavigationLink3D` 跳跃链接，连接地面与建筑顶部两个断开的 NavMesh 区域。当敌人的 `NavigationAgent3D` 路径经过跳跃链接时，触发 `link_reached` 信号，敌人进入 JUMP 状态，施加垂直速度跳上建筑顶部，落地后继续追踪玩家。

跳跃能力按怪物类型区分：近战怪 5m（能上一层楼+余量），远程怪 2m（仅能上矮平台，保持距离型战斗风格）。跳跃仅用于导航（追平台），不用于战斗闪避。

## 用户故事

1. 作为玩家，当我跳上建筑顶部时，近战怪物应该能跳上来继续追击我，而不是站在地面发呆
2. 作为玩家，当我跳上建筑顶部时，远程怪物应该能跳上矮平台找到射击位置，而不是被地形阻挡
3. 作为玩家，近战怪物（5m 跳跃）应该比远程怪物（2m 跳跃）能到达更多高处，体现类型差异
4. 作为玩家，怪物跳跃时应该播放骨骼 jump 动画（如果 GLB 有），增强生物感
5. 作为玩家，怪物跳跃过程中不应该攻击我（空中不可攻击），落地后才恢复攻击
6. 作为玩家，怪物从建筑上掉落时应该自然落地继续追，不应因掉落受伤或卡住
7. 作为玩家，怪物不应该在平地上无故跳跃——跳跃只发生在需要跨越垂直落差追上我的时候
8. 作为玩家，多只怪物同时追我上建筑时，它们应该通过 RVO 避障互不碰撞，不会堆叠在跳跃点
9. 作为玩家，怪物寻路时应该能规划包含跳跃的路径（智能寻路），而不是追到建筑脚下才原地起跳
10. 作为玩家，飞行敌人（enemy）不受此功能影响——它们本就可以飞到任何高度

## 实现决策

### 架构

- **新增模块：`NavJumpLinks` 静态工具类** — 负责在 NavMesh 烘焙后自动生成跳跃链接
- **修改模块：`monster_base` FSM** — 新增 JUMP 状态，处理 `NavigationAgent3D.link_reached` 信号
- **修改模块：`monster_melee` / `monster_ranged`** — 配置各自的 `jump_height`
- **修改模块：`nav_region`** — 烘焙后调用 `NavJumpLinks.generate()`

### 跳跃链接生成策略

**主策略（GridMap 遍历）：**
- 遍历 GridMap 所有已用 cell
- 对每个有建筑项的 cell，若上方 cell 为空 → 建筑顶部
- 对建筑顶部的 4 个水平邻居，若该邻居 cell 为空（可通行地面）→ 在边缘创建 `NavigationLink3D`
- 链接从地面边缘指向建筑顶部边缘，双向

**兜底策略（NavMesh 分析）：**
- 烘焙后获取 NavMesh 多边形边缘
- 找垂直相邻（落差 ≤ 最大跳跃高度）但水平距离 ≤ 0.5m 的断开边缘对
- 为这些边缘对创建 `NavigationLink3D`

兜底处理非 GridMap 地形（平台、矮墙等）。

### FSM 变更

新增 JUMP 状态：

```
IDLE → CHASE → JUMP  ──(落地)──→ CHASE
              → ATTACK → CHASE / IDLE
              → RETREAT → CHASE / LOST
              → LOST → IDLE / CHASE
```

- **进入条件**：`NavigationAgent3D.link_reached` 信号触发
- **行为**：水平朝链接终点移动 + 垂直 `jump_velocity` 升空；不可攻击
- **退出条件**：`is_on_floor()` 且空中时间 ≥ 0.1s（防首帧误判），切回 CHASE
- **动画**：尝试播放 `jump` 动画（若 AnimationPlayer 有）；无则保持当前姿态

### 跳跃物理

- `jump_velocity = sqrt(2 × gravity × jump_height)`，其中 `gravity = 20.0`
- 近战 `jump_height = 5.0` → `jump_velocity ≈ 14.14`
- 远程 `jump_height = 2.0` → `jump_velocity ≈ 8.94`
- 空中水平速度保持 `move_speed`（沿链接方向）
- 重力累积与现有 `_physics_process` 一致

### 模型属性

- `monster_base` 新增 `jump_height: float`（`@export`，子类覆盖）
- `monster_base` 新增 `jump_velocity: float`（由 `jump_height` 计算）
- `monster_melee.jump_height = 5.0`
- `monster_ranged.jump_height = 2.0`

## 测试决策

### 好的测试

- 只测试外部可观察行为，不测试内部实现细节
- 用最小场景复现核心路径，不依赖完整竞技场

### 测试 Seam

**Seam 1：`NavJumpLinks.generate()` — 跳跃链接生成正确性**

- 创建最小 GridMap（一个建筑 cell + 相邻空地）
- 调用 `generate()` 后验证 `nav_region` 下有正确数量和位置的 `NavigationLink3D` 子节点
- 验证链接的 `start_position` 和 `end_position` 在正确高度（地面 vs 建筑顶部）

**Seam 2：Monster FSM JUMP 状态转换**

- 实例化怪物，手动放置 `NavigationLink3D` 连接两点
- 设 `nav_agent.target_position` 穿过链接
- 验证：(1) `link_reached` 信号触发，(2) FSM 进入 JUMP，(3) `velocity.y` 为负（向上），(4) 落地后切回 CHASE

### 测试先例

- [test_enemy_ai.gd](file:///g:/work/Starter-Kit-FPS/tests/test_enemy_ai.gd) — 怪物实例化 + 属性验证 + FSM 状态检查模式
- 测试场景命名：`btest` + 功能名 + 编号，如 `btestjumpnav01links`

## 超出范围

- **战斗闪避跳跃**：敌人不会在战斗中侧跳躲子弹。跳跃仅用于导航（追平台）
- **飞行敌人跳跃**：`enemy`（飞行敌人）本就可以飞到任何高度，不在此功能范围
- **玩家跳跃加强**：不修改玩家跳跃能力
- **掉落伤害**：敌人从建筑上掉落不受伤害
- **跳跃音效**：v1 不添加跳跃音效（与近战挥砍音效同理，无合适素材）
- **NavMesh 分析兜底**：若实现复杂度过高，兜底策略可降级为纯 GridMap 方案

## 补充说明

- 设计依据：ADR 021（[docs/adr/021-enemy-jump-navigation.md](file:///g:/work/Starter-Kit-FPS/docs/adr/021-enemy-jump-navigation.md)）
- 领域词汇表：CONTEXT.md「敌人跳跃导航系统」节
- 链接密度：建筑边缘每个 cell 创建一个链接，密度可能较高，但 `NavigationAgent3D` 会自动选择最优路径
- 跳跃动画：怪物 GLB 动画列表未确认是否含 `jump`，需运行时用 `has_animation("jump")` 检测