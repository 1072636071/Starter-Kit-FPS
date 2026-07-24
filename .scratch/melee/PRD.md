# PRD：玩家近战系统

为当前只有远程能力的角色补充**玩家近战**能力：用剑发动近身攻击，与现有 `Weapon`/弹体/弹药体系完全解耦。

## 来源

- 架构决策：`docs/adr/006-melee-as-independent-system.md`（含 grill 会话补充的「后续决策」一节）
- 领域词汇：CONTEXT.md「近战系统（Melee）」术语表
- 工单：`.scratch/melee/issues/01`–`05`

## 核心需求

1. 按独立近战键（V）发动一次挥砍，剑视图模型在挥砍期间显示、结束收回
2. 挥砍命中身前小范围内的怪物，按 `melee_damage` 结算，每次挥砍每怪只结算一次
3. 命中后怪物自动泛红（复用 ADR 005 的 `HitFeedback.flash`，经怪物既有 `damage()` 触发）
4. 受独立冷却约束（`melee_cooldown`），不占用武器槽、不影响弹药/HUD

## 关键决策（来自 grill 与 ADR 006）

### 主决策（架构层）

- **接入方式**：独立输入动作，与 `weapons` 数组 / 弹药 / 换弹解耦
- **剑显示**：瞬态视图模型，平时隐藏
- **命中检测**：前方 `Area3D` 命中区（Melee Hitbox），仅活跃帧开启
- **调参初版**：`melee_damage=40`、`melee_cooldown=0.5s`、`melee_reach=2.0m`、宽高≈1.5m（均 `@export`）
- **按键**：新增 `melee` 动作绑 V 键（已核查 `project.godot` 无冲突）
- **模型来源**：`quaternius_swords.glb`（需导入项目到 `models/`）

### 子决策（grill 会话细化）

| 子决策 | 选定方案 | CONTEXT.md 术语 |
|--------|----------|-----------------|
| 挥砍时序 | `swing_duration=0.4s`、Active Frames `0.1s–0.3s` | Swing Duration / Active Frames |
| 命中区朝向 | 挂 Player 根节点，只跟随 yaw 不跟随 pitch | Melee Hitbox Orientation |
| 挥砍动画样式 | 下劈（剑从右上→左下） | Swing Animation Style |
| 近战-换弹并发 | 互不阻塞（解耦语义） | Melee-Reload Independence |
| 穿墙语义 | `has_method("damage")` 过滤；接受薄墙穿墙边缘情况 | Melee Hitbox Wall Piercing |
| Viewmodel 生命周期 | `_ready()` 中实例化一次、挂 `CameraItem` 下、复用 | Melee Viewmodel Lifecycle |
| 冷却实现 | 浮点累加器 `melee_cooldown_remaining`，不新增 Timer 节点 | Melee Cooldown Implementation |
| 挥砍音效 | v1 跳过（无合适素材） | Melee Swing Sound |

### 命中区几何

- Area3D 挂 Player 根下，`monitoring = false` 默认
- `BoxShape3D(1.5, 1.5, 2.0)`（宽×高×深）
- 中心相对 Player：`Vector3(0, 0.5, -1.0)`（前方 1m、腰部高度）
- 世界坐标覆盖 y∈[0.25, 1.75]，罩住 `monster_melee` 1.4m 胶囊

## 工单拆解

| 工单 | 标题 | 依赖 |
|------|------|------|
| T1 | 导入剑模型并建近战视图模型场景 | 无 |
| T2 | 注册 `melee` 输入动作（V 键） | 无 |
| T3 | 近战核心逻辑 + 视图模型挥砍动画 | T1, T2 |
| T4 | Melee Hitbox 命中区与伤害结算 | T3 |
| T5 | 端到端验证与手感调参 | T4 |

## 不在 v1 范围

- 挥砍音效（无合适素材）
- RayCast 视线检查防穿墙（v1 接受薄墙穿墙边缘情况）
- 左右交替挥砍变体
- AnimationPlayer 替代 Tween（v1 用 Tween 足够）
- 手柄按键映射（v1 仅键盘 V 键）
