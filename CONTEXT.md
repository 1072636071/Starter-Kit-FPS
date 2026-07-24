# CONTEXT.md — 领域词汇表

## 射击系统

| 术语 | 定义 |
|------|------|
| **Projectile（弹体）** | 从枪口发射的实体对象，承载真实伤害判定。使用 Area3D 检测碰撞，命中第一个物体后造成伤害并销毁。形态为发光拉伸胶囊体（CapsuleMesh + emission 材质），飞行速度 30-50 m/s。玩家和敌人均使用弹体。 |
| **Impact（命中特效）** | 弹体碰撞点处播放的 AnimatedSprite3D 动画，由 `impact.tscn` 定义，播放完毕后自动销毁。 |
| **Weapon（武器）** | `Weapon` 资源类，定义武器的模型、属性（冷却、伤害、散射、弹数、击退等）、弹体配置（颜色、大小、速度）和弹药配置（display_name、magazine_size、max_reserve、reload_time）。 |

## 弹体属性

| 术语 | 定义 |
|------|------|
| **projectile_color** | 弹体发光颜色（Color），在武器资源中配置。 |
| **projectile_size** | 弹体大小（Vector3 scale），在武器资源中配置。 |
| **projectile_speed** | 弹体飞行速度（m/s），推荐范围 30-50。 |
| **projectile_damage** | 弹体命中时造成的伤害值，继承自武器的 damage 属性。 |
| **max_distance** | 弹体最大飞行距离，超出后自动销毁。 |

## 弹药系统

| 术语 | 定义 |
|------|------|
| **Magazine（弹匣）** | 武器当前装入的弹药数。每发射一次减 1，归零后无法射击，必须换弹。每把枪独立维护。 |
| **Reserve（备弹）** | 玩家携带的备用弹药总量。换弹时从备弹中取出弹药填满弹匣。备弹归零则无法换弹。每把枪独立维护。 |
| **Magazine Size（弹匣容量）** | 单次装填能容纳的最大弹数，在 Weapon 资源中配置。不同武器可有不同弹匣容量。 |
| **Max Reserve（最大备弹）** | 每把枪能携带的备弹上限，在 Weapon 资源中配置。 |
| **Reload（换弹）** | 将备弹转移至弹匣的动作。触发方式：手动按 R 键；或弹匣归零后继续扣扳机时自动触发。需一定时间完成（换弹时间），期间不能射击。若备弹不足，只装填可用数量。换弹时同时播放武器模型动画（Tween，武器移出视野再回来）与右下角 HUD 进度条。 |
| **Reload Time（换弹时间）** | 完成换弹动作所需的秒数，在 Weapon 资源中配置。 |
| **Reload Animation（换弹动画）** | 换弹期间复用武器 Container 的 Tween 动画，使武器模型移出视野再归位，营造"装填"视觉。与切枪动画（initiate_change_weapon）共享 Tween 机制，但换弹期间不切换武器模型。 |
| **Reload Progress Bar（换弹进度条）** | 右下角弹药 HUD 上的换弹进度指示（直线或环形），随 reload_time 实时填充，完成后消失。 |
| **reload 输入动作** | 换弹的手动触发按键，绑定到 project.godot 的 `reload` 动作，默认 R 键。 |

## 后坐力与精度

| 术语 | 定义 |
|------|------|
| **Knockback（后坐力）** | 武器开火时施加给玩家的反冲力，包含三个分量：相机垂直旋转（knockback.x，枪口上跳）、相机水平旋转（knockback.y，随机左右偏转）、以及武器模型位置回弹和玩家移动速度反冲。值越大后坐力越强。Blaster=20, Blaster-Repeater=5。 |
| **Spread（散布）** | 弹体发射方向相对准星中心的随机偏转角，以武器资源的 `spread` 属性配置。散布角度 = randf_range(-spread, spread) * 0.02，作用在相机基向量上。值越大精度越低。 |
| **ADS（瞄准）** | Aim Down Sights，右键瞄准状态。进入 ADS 时：FOV 从默认 75° 缩小至 60°（视觉变焦）、武器散布减半（精度翻倍）、玩家移动速度减慢 30%。持续按住右键维持 ADS，松开退出。 |
| **Enemy Spread（敌人散布）** | 敌人射击时的弹道偏转。两个敌人类（Enemy、MonsterRanged）均有 `export var enemy_spread: float` 可配置属性，默认值 0.08。实际散布随目标距离线性增大：`effective_spread = enemy_spread * distance_factor`，模拟远距离精度下降。 |

## 地图系统

| 术语 | 定义 |
|------|------|
| **GridMap（网格地图）** | Godot 的瓦片式 3D 地图节点，通过 MeshLibrary 定义可放置的网格项，按 cell_size 划分空间。当前项目 cell_size = Vector3(4, 4, 4)，即每格 4 米。 |
| **MeshLibrary（网格库）** | Godot 的 GridMap 资源依赖，定义每个网格项的 Mesh、碰撞形状（可选导航网格）。当前项目以独立 `.tres` 文件存储（`resources/city-mesh-library.tres`），多地图共享。**重要规格：** 模型原始尺寸为 1 单位，必须通过 `set_item_mesh_transform(i, Transform3D().scaled(CELL_SIZE))` 放大至与 cell_size 匹配，否则瓦片间会产生缝隙。**注：** 当前 MeshLibrary 项**未设置 navmesh 数据**——怪物导航使用运行时从 GridMap 自动烘焙的整体 navmesh（见下方"角色导航 / NavMesh"）。 |
| **Map JSON（地图数据）** | City Builder 项目导出的 JSON 格式地图布局文件，包含每个格子的坐标（Vector2i）、朝向（orientation）和结构索引（structure index）。是跨项目数据桥接的中间格式。 |
| **转换管线（Conversion Pipeline）** | 将 Map JSON 转换为 FPS 项目可用 `.tscn` 场景的 EditorScript 工具链。流程：City Builder 导出 JSON → FPS EditorScript 读取 → 构建 MeshLibrary（含 trimesh 碰撞）→ 生成 GridMap 场景。 |
| **Structure（结构）** | City Builder 中可放置的地图元素，包括道路（直道、弯道、十字路口、分岔）、人行道、建筑（4种小建筑+车库）、草地（3种）。共 15 种，对应 15 个 `.glb` 模型。 |

## 角色移动 / 地形分类

| 术语 | 定义 |
|------|------|
| **Step（台阶）** | 垂直高度差 **< 0.3m** 的小高差。玩家和怪物均可不跳跃直接通过（自动登高）。来源示例：人行道边缘（curb，典型 0.1-0.2m）、[platform.tscn](file:///e:/work/sp/Starter-Kit-FPS/objects/platform.tscn) 的 0.2m 段。 |
| **Wall（墙）** | 垂直高度差 **≥ 0.3m** 的高差。阻挡玩家（须跳跃，玩家有二段跳可越过）和怪物（不可达）。来源示例：[wall_low.tscn](file:///e:/work/sp/Starter-Kit-FPS/objects/wall_low.tscn) 顶部 ~1m、[platform.tscn](file:///e:/work/sp/Starter-Kit-FPS/objects/platform.tscn) 的 0.3m 段（0.2→0.5m 之间）。 |
| **step_height（台阶高度阈值）** | 全局浮点参数，默认 `0.3`。区分 Step 与 Wall 的唯一依据。玩家和怪物共用此参数（与"统一可通行"设计决定一致）。**实现位置：** autoload `StepConstants`，定义在 [scripts/step_constants.gd](file:///e:/work/sp/Starter-Kit-FPS/scripts/step_constants.gd) 的 `STEP_HEIGHT` 常量。引用方式：`StepConstants.STEP_HEIGHT`。 |
| **Auto-Step（自动登高）** | 角色在水平移动中遇到 ≤ step_height 的高差时，自动抬升到该高度而无需跳跃的机制。Godot 4 默认 `floor_snap_length=0.3` 仅处理"下坡吸附"，不处理"上坡登高"，需要自定义实现。 |

## 角色导航 / NavMesh

参见 [ADR 003](file:///e:/work/sp/Starter-Kit-FPS/docs/adr/003-step-and-monster-navigation.md)。

| 术语 | 定义 |
|------|------|
| **NavigationAgent3D（导航代理）** | Godot 4 的导航节点，附加在 `CharacterBody3D` 上提供路径规划。怪物通过 `get_next_path_position()` 获取下一路径点，朝该点（而非玩家位置）施加水平速度。仅 `monster_melee` 和 `monster_ranged` 使用；飞行敌人 `enemy` 是 `Area3D` 不需要。 |
| **NavigationRegion3D（导航区域）** | Godot 4 的导航网格容器节点，包裹 GridMap。运行时通过 `NavigationServer3D` 自动烘焙 navmesh，烘焙源是 GridMap 的碰撞几何。 |
| **Runtime NavMesh Baking（运行时烘焙）** | 在场景加载时调用 `NavigationServer3D` 烘焙整体 navmesh，而非为 MeshLibrary 每个项手工制作。烘焙开销典型几百 ms，路径质量中等但足够。 |
| **Agent Max Climb（代理最大攀登高度）** | NavMesh 烘焙参数，设为 `step_height = 0.3`。烘焙出的 navmesh 在 ≤0.3m 高差处表现为连通区域——怪物自然能走上去，无需特殊代码。 |
| **Player Auto-Step（玩家自动登高）** | 玩家侧（非怪物）的登高实现。WASD 输入驱动，无法用 NavMesh，需自定义 step-up 检测（前向 ShapeCast/RayCast + 高度判定 + 抬升）。与怪物 NavMesh 共用 `step_height` 参数保证语义一致。 |

## 受击反馈（Hit Feedback）

| 术语 | 定义 |
|------|------|
| **Hit Flash（命中变色）** | 怪物受到伤害瞬间的视觉反馈：受击时模型材质临时染**红**并在 ~0.12s 内淡出，让玩家清晰感知"打中了"。作为本次新增的唯一反馈通道，统一接入三种怪物（`monster_melee`、`monster_ranged`、`enemy`）。实现见独立模块 `scripts/hit_feedback.gd` 的静态方法 `HitFeedback.flash(target)`（参见 [ADR 005](file:///e:/work/sp/Starter-Kit-FPS/docs/adr/005-hit-feedback-module.md)）。 |
| **hit_feedback.gd** | 独立的受击反馈静态类脚本（`scripts/hit_feedback.gd`），提供 `HitFeedback.flash(target)`。`target` 为怪物节点；内部自动定位其可视模型（优先 `Model` 子节点，否则取节点自身的 MeshInstance3D），对其下所有材质临时染色后淡出。与 `combat_utils.gd` 平级、互不依赖。 |
| **Hit Feedback（受击反馈）** | 怪物被击中时给玩家的可感知信号总称。当前项目仅含 Hit Flash（视觉变色）+ 既有音效 `enemy_hurt.ogg` + melee/ranged 既有微弱 scale 形变；已明确**不**包含击退（Knockback）与受击硬直（Hitstun），二者会改变 AI 物理/行为，留作未来可选进阶。 |

## 近战系统（Melee）

| 术语 | 定义 |
|------|------|
| **Melee（近战）** | 玩家对怪物发动的近身攻击，**与远程武器（`Weapon`/弹体）完全解耦**：由独立的输入动作触发，不占用 `weapons` 数组槽位、不参与弹药/换弹体系。参见 [ADR 006](file:///e:/work/sp/Starter-Kit-FPS/docs/adr/006-melee-as-independent-system.md)。命中检测复用三种怪物已有的 `damage(amount)` 接口（先例：`monster_melee` 的 `HitArea`）。 |
| **Melee Viewmodel（近战视图模型）** | 近战剑的视图模型（viewmodel），采用**瞬态**方式：平时隐藏，仅在按下近战键的挥砍动画期间显示并随手臂摆动，动画结束自动收回隐藏。与常驻的枪械视图模型（`CameraItem/Container` 内）互不干扰。模型来源为 `quaternius_swords.glb`（需导入项目，建议置于 `models/`）。 |
| **Melee Hitbox（近战命中区）** | 玩家正前方的 `Area3D` 命中区，仅在挥砍动画的"活跃帧"开启 `monitoring`，通过 `get_overlapping_bodies()` 收集命中怪物，每个敌人**每次挥砍只结算一次伤害**（用 `Set` 去重）。复用 `monster_melee` 的 `HitArea` 先例；命中后调用怪物的 `damage(melee_damage)` 接口。 |
| **Melee Tuning（近战调参）** | 初版手感参数（均为 `@export`，可随时调）：`melee_damage = 40`（高于枪械单发，补偿短射程）、`melee_cooldown = 0.5s`（一次挥砍节奏）、`melee_reach = 2.0m`（命中区前向深度，与 `monster_melee.attack_range` 一致）、命中区宽度/高度约 `1.5m`（覆盖身前一小片，非全向）。 |
| **Melee Action（近战输入）** | 新增的独立输入动作，动作名 `melee`，默认绑定 **V 键**（已核查 `project.godot`：W/A/S/D、Space、E、R 已占用，V 空闲无冲突）。与 `shoot`/`aim`/`reload`/`weapon_toggle` 完全解耦，单独触发近战挥砍。 |


