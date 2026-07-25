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
| **Melee（近战）** | 玩家对怪物发动的近身攻击，**与远程武器（`Weapon`/弹体）完全解耦**：由独立的输入动作触发，不占用 `weapons` 数组槽位、不参与弹药/换弹体系。参见 [ADR 006](file:///e:/work/sp/Starter-Kit-FPS/docs/adr/006-melee-as-independent-system.md)。命中检测复用三种怪物已有的 `damage(amount)` 接口；**注：** `monster_melee.tscn` 原 `HitArea` Area3D 节点已在 T2 中删除（`monster_melee.gd::_deal_damage()` 实际用距离判定而非 Area3D 监听，该节点曾是"声明而未使用"的死代码）。玩家近战的 Area3D + `get_overlapping_bodies()` 是项目内的**首次**实现。 |
| **Melee Viewmodel（近战视图模型）** | 近战剑的视图模型（viewmodel），采用**瞬态**方式：平时隐藏，仅在按下近战键的挥砍动画期间显示并随手臂摆动，动画结束自动收回隐藏。与常驻的枪械视图模型（`CameraItem/Container` 内）互不干扰。模型来源为 `quaternius_swords.glb`（需导入项目，建议置于 `models/`）。 |
| **Melee Hitbox（近战命中区）** | 玩家正前方的 `Area3D` 命中区，仅在挥砍动画的"活跃帧"开启 `monitoring`，通过 `get_overlapping_bodies()` 收集命中怪物，每个敌人**每次挥砍只结算一次伤害**（用 `Set` 去重）。命中后调用怪物的 `damage(melee_damage)` 接口。**注：** 与 `monster_melee` 原 `HitArea` 节点同名但实现模式不同——`monster_melee` 的 HitArea 是死代码（已于 T2 删除），玩家近战才是项目内 Area3D 命中区模式的首个真实用例。 |
| **Melee Hitbox Orientation（命中区朝向）** | Melee Hitbox 挂在 **Player 根节点**下（不是 Camera），故**只跟随玩家 yaw（水平转向），不跟随相机 pitch（俯仰）**——命中区始终保持水平 slab 形态。定位：中心 `Vector3(0, 0.5, -1.0)`（前方 1m、腰部高度），`BoxShape3D(1.5, 1.5, 2.0)`（宽×高×深），世界坐标覆盖 y∈[0.25, 1.75]。**理由：** 近战短射程+0.5s 冷却下可预测性优于技巧表达；与射击系统（用相机方向+散布做瞄准技巧）差异化才有辨识度；飞行敌人高度本就常超出 1.5m 盒子，pitch 跟踪也未必够得着。被否决的替代：挂在 Camera 下随 pitch 倾斜（盒子会穿地板、多怪叠层误砍），或 pitch-clamped 折中（实现复杂阈值难调）。 |
| **Melee Tuning（近战调参）** | 初版手感参数（均为 `@export`，可随时调）：`melee_damage = 40`（高于枪械单发，补偿短射程）、`melee_cooldown = 0.7s`（一次挥砍节奏，见 ADR 019）、`melee_reach = 2.0m`（命中区前向深度，与 `monster_melee.attack_range` 一致）、命中区宽度/高度约 `1.5m`（覆盖身前一小片，非全向）。 |
| **Melee Action（近战输入）** | 新增的独立输入动作，动作名 `melee`，默认绑定 **V 键**（已核查 `project.godot`：W/A/S/D、Space、E、R 已占用，V 空闲无冲突）。与 `shoot`/`aim`/`reload`/`weapon_toggle` 完全解耦，单独触发近战挥砍。 |
| **Swing Duration（挥砍总时长）** | 一次挥砍动画从开始到结束的总时长，**0.6s**（ADR 019 从 0.4s 拉长）。必须 ≤ `melee_cooldown`（0.7s），留 0.1s 缓冲避免挥砍未结束冷却已就绪导致的节奏冲突。 |
| **Active Frames（活跃帧）** | 挥砍动画中**Melee Hitbox 的 `monitoring` 开启、可造成伤害的时间窗**，从挥砍启动后 **0.2s** 到 **0.4s**（共 0.2s，ADR 019 时序）。0–0.2s 为"举剑蓄力+剑滑入"前摇（无伤害），0.4–0.6s 为"剑滑出+收剑"后摇（伤害窗口已过）。monitoring 切换由 `SceneTree.create_timer()` 在 0.2s 开启、0.4s 关闭，**与挥砍 Tween 解耦**——这样挥砍 Tween 被 `kill()`（连续挥砍）时 monitoring 切换仍按时执行，避免 `tween_callback` 因 Tween 被杀而不触发、导致 monitoring 滞留。viewmodel 隐藏仍由 Tween 的 `tween_callback` 在 0.6s 收尾。 |
| **Melee Viewmodel Transition（近战视图模型过渡）** | 挥砍期间枪与剑的协同过渡动画（ADR 019）：前摇段并行——枪械 Container `position.y` 下沉 `GUN_DROP_Y=-1.0` 出屏底部、剑 viewmodel 从屏外起点（`WINDUP_POS+INTRO_POS_OFFSET` / `WINDUP_ROT+INTRO_ROT_OFFSET`）滑入到 windup 终点；活跃帧段——剑下劈、枪保持下沉位；后摇段并行——剑滑出屏外、枪 `position.y` 回升复位。过渡期间 `_melee_active=true`，`_process` 中跳过 container lerp 让 Tween 完全控制。剑初始变换在 `_ready()` 缓存为 `_melee_sword_init_pos` / `_melee_sword_init_rot`，`action_melee()` 入口强制重置到该基准防连续挥砍残留与漂移。 |
| **Swing Animation Style（挥砍动画样式）** | 采用**下劈（Downward Slash）**：剑从右上向左下划过屏幕。前摇 0.2s 把剑举到右上（同时从屏外滑入）→ 活跃帧 0.2s 划到左下 → 后摇 0.2s 收回隐藏（同时滑出屏外）。用单个 Tween 同时 tween `rotation_degrees` 和 `position` 实现，无 AnimationPlayer 依赖。**选此方案的理由：** 第一人称视角下下劈视觉冲击最强（剑尖从视野上方划到下方）；与"挥砍"语义最贴合（横扫视觉弱、突刺像长矛）；与 Q1 时间窗天然契合。被否决的替代：横扫（FP 下视觉弱）、突刺（不像剑）、左右交替变体（v1 不必要）。过渡动画时序详见 ADR 019。 |
| **Melee-Reload Independence（近战换弹并发）** | 近战挥砍与换弹**互不阻塞**：换弹中按 V 可触发挥砍，挥砍中按 R 可触发换弹。理由：ADR 006 的核心就是近战与 `Weapon`/弹药体系解耦——若近战被换弹阻塞就破坏解耦语义。换弹是枪的事，近战是手的事，两套独立状态机并行运行。冷却（`melee_cooldown`）只约束近战自身，不查 `is_reloading`；换弹逻辑（`action_reload`/`_step_reload`）不查近战状态。 |
| **Melee Hitbox Wall Piercing（近战命中区穿墙语义）** | v1 命中结算用 `has_method("damage")` 过滤重叠物体——`get_overlapping_bodies()` 返回的 StaticBody3D（墙体、平台）因无 `damage()` 方法自然被跳过，无需 layer/mask 配置。**已知边缘情况**：薄墙后的敌人可能被穿墙砍中（盒子几何上重叠但视线被挡）。v1 不加 RayCast 视线检查（过度工程），记录为未来增强。墙体不会被错误伤害，但也不会阻挡对墙后敌人的伤害。 |
| **Melee Viewmodel Lifecycle（近战视图模型生命周期）** | Melee Viewmodel 在玩家 `_ready()` 中**实例化一次**，作为 `CameraItem` 的子节点（与 `Container` 平级，不在 Container 内——否则会被 `change_weapon()` 的 `remove_child()` 清掉）。初始 `visible = false`，每次挥砍复用同一实例：show → Tween 挥砍 → hide。**不**每次挥砍重新 instantiate。所有 `MeshInstance3D` 的 `layers = 2`（仅武器相机渲染），与 `change_weapon()` 中枪械模型设置方式一致。 |
| **Melee Swing Sound（挥砍音效）** | v1 **跳过**——`sounds/` 下无合适素材（只有枪声 `blaster*.ogg`、敌人声 `enemy_*.ogg`、移动声 `jump_*.ogg`/`land.ogg`/`walking.ogg`、切枪 `weapon_change.ogg`，无 whoosh/挥砍声）。T3 中的"可选音效"明确为 v1 不做，留待未来增加 `sword_swing.ogg` 类素材后接入。**不**复用现有音效（语义不符，反而破坏手感）。 |
| **Melee Cooldown Implementation（近战冷却实现）** | 冷却用**浮点累加器**（`melee_cooldown_remaining: float`，在 `_process(delta)` 中递减），**不**新增 Timer 节点。与现有 `_step_reload(delta)` 的 `reload_time_remaining` 同模式。触发挥砍时设 `melee_cooldown_remaining = melee_cooldown`，每帧 `-= delta`，归零方可再次挥砍。避免向 `player.tscn` 添加 Timer 节点，与 `blaster_cooldown` Timer（射击冷却用）解耦。 |
| **Melee Slash VFX（近战剑弧特效）** | 近战攻击活跃帧期间的**剑弧拖尾粒子特效**（GPUParticles3D 一次性爆发），直观展示攻击范围。参见 [ADR 020](file:///g:/work/Starter-Kit-FPS/docs/adr/020-melee-slash-vfx.md)。玩家：青白色、挂在 `CameraItem` 下（layer 2，仅第一人称可见）；敌人：红橙色、挂在怪物自身节点下（layer 3，主相机可见）。30 粒子、0.2s 生命周期、additive 发光。由 `MeleeVFX` 静态类（[scripts/melee_vfx.gd](file:///g:/work/Starter-Kit-FPS/scripts/melee_vfx.gd)）统一管理创建与触发。 |
| **MeleeVFX（近战特效工具类）** | 静态工具类 `MeleeVFX`（[scripts/melee_vfx.gd](file:///g:/work/Starter-Kit-FPS/scripts/melee_vfx.gd)），提供 `create_slash(parent, color, layer, box_extents, local_pos) -> GPUParticles3D` 和 `trigger(particles)` 两个静态方法。统一玩家和敌人的剑弧粒子创建与触发逻辑，避免重复配置代码。 |
| **Swing Easing（挥砍缓动曲线）** | 挥砍 Tween 三段各自独立的缓动配置，取代默认线性插值。前摇：`TRANS_SINE + EASE_IN`（缓慢蓄力，模拟举剑重量感）；活跃帧：`TRANS_QUART + EASE_OUT`（快速劈下末尾减速，利落打击感）；后摇：`TRANS_QUAD + EASE_IN`（收刀逐渐加速离场）。线性插值是游戏手感的敌人——缺乏缓动的匀速运动看起来像机器人。 |
| **Hit-Stop（命中顿帧）** | 近战命中敌人瞬间，`Engine.time_scale` 短暂降至 0.05（约 3 帧的停顿），模拟"砍中实体"的阻滞感。使用 `ignore_time_scale` 计时器在真实时间 ~0.06s 后恢复到 1.0。仅命中时触发，挥空不触发。是动作游戏打击感最核心的单因子之一，给大脑处理反馈的窗口。 |
| **Melee Hit Shake（近战命中震屏）** | 近战命中时相机短暂随机抖动（峰值 0.04 单位，帧率无关 lerp 衰减，decay 系数 25），叠加在落地回弹之上。沿 x/y 轴随机偏移，模拟冲击力传导到视角。 |
| **Melee FOV Pulse（近战 FOV 扩张）** | 挥砍期间（`_melee_active`）FOV 目标值从默认 75° 扩张到 80°（+5°），通过 `move_toward` 平滑过渡，挥砍结束后自动缩回。模拟"发力瞬间视野变窄/加速"的生理感受，增加动作速度感。 |

## 怪物武器与动画（Monster Weapons & Animation）

> **v2 修正**：初版术语基于"怪物 GLB 是静态网格、无骨骼、只能程序化 Tween"的误判，已证伪。两个怪物 GLB 实为**带 30 条命名动画的节点式刚体绑定**（解析 GLB 确认：`attack-melee-right/left`、`attack-kick-right/left`、`holding-right/left/both`、`holding-right-shoot` 等），导入后 GLB 实例自带 `AnimationPlayer`。`import_as_skeleton_bones=false` 仅表示不暴露骨骼节点，不等于无动画。详见 [ADR 008](file:///e:/work/sp/Starter-Kit-FPS/docs/adr/008-monster-weapons-and-animations.md) 顶部修订记录。

| 术语 | 定义 |
|------|------|
| **Monster Weapon（怪物武器）** | 人形怪物（`monster_ranged` / `monster_melee`）装备并展示的**可见武器模型**，挂为 `arm-right` 节点的子节点（非 `Model` 固定变换）。区分于玩家侧：玩家枪械在 `CameraItem/Container`（viewmodel，layer 2），怪物武器是真实世界网格（layer 3）。远程怪物用枪、近战怪物用剑、空手怪无武器。**背景约束（已修正）：** 怪物 GLB 是节点式刚体绑定（`character-f → root → torso → arm-right/arm-left/head`，`skins` 为空即无顶点蒙皮），自带 `AnimationPlayer` 与全部攻击/持械动画；武器挂 `arm-right` 后随手臂骨骼动画自然跟随。 |
| **Arm-Right Mount（手臂挂载点）** | 因 `arm-right` / `arm-left` 是手臂远端节点（**无独立 hand 节点**），武器模型作为 `arm-right` 的子 `Node3D` 挂载，并以**本地偏移**（position，约手臂长度，朝下/朝前）调到"手掌"位置——该偏移是手调常量，靠试玩微调。攻击时 `arm-right` 的骨骼动画驱动手臂，武器随之挥动/随枪口指向。取代了初版"手部固定变换"概念。 |
| **Animation Clips（动画剪辑）** | 怪物 GLB 自带、经 `AnimationPlayer` 播放的命名剪辑。与本次相关的有：`attack-melee-right/left`（手臂挥击/拳击）、`attack-kick-right/left`（踢击）、`holding-right/left/both`（持械静止姿态）、`holding-right-shoot` / `holding-left-shoot` / `holding-both-shoot`（持枪射击姿态）、`walk` / `run` / `sprint` / `idle` / `die` 等。T1–T5 已全部接入：攻击用 `attack-melee-right`、持枪用 `holding-right`、移动用 `walk`/`run`（按速度选取，静止时近战播 `idle`、远程保持 `holding-right`）、死亡用 `die`。已移除程序化 `_animate_walk`/`_animate_idle` bob 与整体缩小 Tween（避免与骨骼动画双重抖动）。 |
| **Gun Model（枪模型）** | 远程怪物（`monster_ranged`）手持的枪模型，复用 `models/weapons/blaster.glb`，作为 `arm-right` 的子节点挂载（本地偏移调到右手、枪管朝怪物 forward=-z）。通过 `@export var gun_model: PackedScene` 配置，默认 `blaster.glb`。 |
| **Muzzle Marker3D（枪口标记）** | 挂在枪模型下的 `Marker3D` 子节点，位于枪管前端，**作为弹体生成点**，取代原身体 `ShootPoint`。`_fire_projectile()` 在该标记的世界变换处 `instantiate(projectile.tscn)`。 |
| **Holding Pose（持枪/持械姿态）** | 远程怪物常驻的持枪姿态：`_ready()` 播放 `holding-right`（或 `holding-right-shoot`）使右臂保持持枪、枪模型停于手中；攻击时叠加枪口闪光/后坐，姿态本身不重置。近战怪物 v1 不强制常驻姿态，攻击时直接播 `attack-melee-right`。 |
| **Recoil Tween（后坐 Tween）** | 远程怪物开火时**枪模型自身的程序化回弹**（沿枪局部 +z 轻弹后回位，单 Tween），叠加在 `holding-right` 骨骼姿态之上、互不冲突，取代原整体身体后仰 Tween。枪口在局部 -z（前方），后坐沿 +z（后方）推——与枪口方向相反，物理正确。与玩家侧 `knockback` 后坐力（相机/移动反冲）概念不同——此处仅武器模型可见回弹，不影响怪物 AI 物理。 |
| **Muzzle Flash（枪口闪光）** | 远程怪物开火时在 `Muzzle` 处播放的一次性 `AnimatedSprite3D` 闪光，素材复用 `sprites/burst_animation.tres`（与 `enemy.tscn` 同款），`layers = 4`（layer 3，进主相机、不进小地图）。与 `enemy_attack.ogg` 音效（场景已有 `AudioStreamPlayer`）共同构成开火反馈。 |
| **Melee Weapon Model（近战武器模型）** | 近战怪物（`monster_melee`）手持的剑模型，通过 `@export var melee_weapon_model: PackedScene` 配置（**可留空**），默认一把与玩家 `Sword6.glb` **不同**的 `SwordXXX.glb`（怪物武器与玩家区分、更具辨识度）；型号做成配置以便无代码替换。作为 `arm-right` 的子节点挂载（本地偏移调到握持、缩放适配怪物网格）。 |
| **Attack Animation（攻击动画，怪物近战）** | 近战怪物攻击由 `AnimationPlayer.play("attack-melee-right")` 驱动（取代原整体 lunge Tween）。持剑时剑随手臂劈下，空手时即为拳击。攻击剪辑本身含手臂挥动（及可能的轻微前冲位移），无需手动补前冲 Tween。对应于玩家近战的"挥砍"，但实现是骨骼剪辑而非 viewmodel Tween。 |
| **Active Frame（活跃帧，怪物近战）** | `attack-melee-right` 剪辑中**伤害结算触发的时刻**，对齐挥砍前摇结束、挥到位的那一帧（约剪辑 0.2s 处，按实际时长微调），用 `SceneTree.create_timer(active_frame_time)` 触发 `_deal_damage`。与玩家近战"活跃帧开启 `monitoring`"机制不同：怪物近战**仍用距离判定**（`_deal_damage` 现有 `attack_range` 逻辑不变），仅把结算时机从前摇后 0.2s 对齐到骨骼剪辑的活跃帧。 |
| **Empty-Hand Melee（空手近战）** | `monster_melee` 在 `melee_weapon_model = null` 时的变体：**不挂任何武器模型**，攻击同样播放 `attack-melee-right`（拳击），靠手臂骨骼动作完成"手臂近战"，伤害在活跃帧按距离判定结算。无独立逻辑分支，仅是配置态——满足"敌人也可以有空手的，只能使用手臂近战"。 |
| **monster_base.gd（怪物基类）** | 人形怪物（`monster_ranged` / `monster_melee`）的共享基类（`objects/monster_base.gd`，`extends CharacterBody3D`）。抽取两怪重复的骨骼动画初始化（`_setup_animation_refs` / `_setup_locomotion_loops` / `_set_model_mesh_layers`）、动画选择器（`_select_animation(idle_anim)`，按 idle_anim 参数区分近战 `idle` / 远程 `holding-right`）、受击（`damage`）、死亡（`destroy` 播 `die` 剪辑）逻辑。子类通过 `super._ready()` 调用基类初始化，仅保留各自特有的武器挂载与攻击/移动逻辑。 |
| **_dead flag（死亡标志）** | `monster_base.gd` 的 `_dead: bool` 状态标志，在 `destroy()` 入口置 `true`。作用：(1) 使 `_physics_process` 提前返回（死亡后不再移动、不再调用动画选择器），避免与 `die` 骨骼剪辑抢动画轨道；(2) 使 `damage()` 顶部 `if _dead: return` 跳过受击（已死亡实体不再结算伤害）；(3) `damage()` 底部 `if health <= 0 and not _dead: destroy()` 防止 `destroy()` 重入。合并了原 `destroyed` 标志（两者始终同时置位、语义等价，故合并为单一 `_dead`）。注：飞行敌人 `enemy.gd` 仍用独立的 `destroyed` 字段（非基类子类，不受影响）。 |

## 小地图系统（Minimap）

| 术语 | 定义 |
|------|------|
| **Minimap（小地图）** | 屏幕角落的小型俯视地图，显示玩家与周围实体位置。渲染方案见 [ADR 007](file:///e:/work/sp/Starter-Kit-FPS/docs/adr/007-minimap-subviewport-camera.md)：采用**动态俯视相机**，而非静态底图或导航网格可视化。 |
| **Minimap Camera（俯视相机）** | 场景中高处垂直朝下的第二台 `Camera3D`，正交投影，渲染进 `SubViewport`。通过 `cull_mask`/图层控制"哪些节点进小地图"。 |
| **Minimap Viewport（小地图视口）** | 承载俯视相机渲染的 `SubViewport` 节点。 |
| **Minimap Texture（小地图纹理）** | `ViewportTexture`，把 `Minimap Viewport` 的渲染结果作为 `TextureRect.texture` 显示到 HUD 角落。 |
| **Minimap Orientation（小地图朝向）** | **北朝上（north-up）**：俯视相机朝向固定、不随玩家旋转，地图永远与真实世界朝向一致。玩家位置用一个小**朝向箭头（Player Blip）**表示其 facing。与 heading-up（相机随玩家转）相反，地面永远稳定好读。 |
| **Player Blip（玩家光点）** | 北朝上方案下，小地图上表示玩家位置的**朝向箭头**。**采用 2D 叠加**：每帧把玩家世界 (x,z) 投影为小地图 UV，在圆形 `TextureRect` 之上用一个 2D `Control` 箭头表示，箭头随玩家 yaw 旋转以指示 facing；相机本身不转。非 3D 图层标记（避免泄漏进真实 3D 视野）。 |
| **Enemy Blip（敌人光点）** | 小地图上表示敌人的标记，**两种敌人都显示**（不按视线/距离过滤），**采用 2D 叠加**：每帧把敌人世界 (x,z) 投影为小地图 UV，在圆形 `TextureRect` 之上用 2D 圆点/图标表示，近战/远程用形状或深浅区分。非 3D 图层标记。 |
| **Minimap Shape & Position（小地图形状与位置）** | **圆形**，位于**右上角**（避开左下血条、右下弹药列表）。方形的 `SubViewport` 渲染经**圆形遮罩**（`ShaderMaterial` 径向 alpha）裁成圆，隐藏俯视渲染四角的畸变。 |
| **Minimap Zoom（小地图缩放/覆盖范围）** | **全图覆盖（~160m）**：俯视正交相机半高约 80m，固定俯视整个 160×160 世界（边界 ±80），相机本身不随玩家移动。玩家/敌人 blip 在图内移动。与"敌人全显示"零冲突。 |
| **Minimap Cull Mask（小地图相机剔除掩码）** | 俯视相机 `cull_mask = layer 1`（仅世界/地形）。**不**含 layer 2（武器 viewmodel，天然不进图）。敌人真实 3D mesh 已从 layer 1 挪到 layer 3（见下），故俯视渲染无敌人 blob——blip 由 2D 叠加独立绘制。 |
| **Minimap Enemy Layer（敌人小地图图层）** | 敌人真实 3D mesh 从默认 **layer 1 挪到 layer 3**，使俯视相机（cull_mask = layer 1）不渲染其顶视 blob；主相机渲染 layers 3–20 故真实 FPS 视野不受影响。实现位置：`monster_melee.gd` / `monster_ranged.gd` 的 `_ready()` 中通过 `model.find_children("*", "MeshInstance3D", true, false)` 遍历并设 `child.layers = 4`（layer 3 的 bitmask 值）。选用运行时设置而非 `.tscn` editable_instance：.glb 实例内 mesh 节点路径不稳定（存在 `character-a` 中间节点），editable_instance 路径易失效；运行时按类型遍历更健壮。 |
| **Minimap Projection（小地图投影）** | 因全图固定正交相机，实体世界 (x,z) → 小地图 UV 为**线性映射**（无需透视除法）：`uv = (world_pos.xz - world_min) / world_size`，再换算到圆形 `TextureRect` 的局部像素坐标放置 2D blip。 |
| **Minimap Integration（小地图集成位置）** | 世界侧：俯视相机 + `SubViewport` 加进 `main.tscn`（`Main` 子节点，**不是** Player 下，因相机固定不跟玩家）；UI 侧：圆形 `TextureRect` + blip 层加进 `HUD`（`CanvasLayer`）下的 `Minimap` `Control` 容器；逻辑由新建 `scripts/minimap.gd` 驱动，负责每帧投影实体 (x,z)→UV 并管理 2D blip。 |

## Roguelike 竞技场系统（Roguelike Arena）

参见 [ADR 009](file:///e:/work/sp/Starter-Kit-FPS/docs/adr/009-arena-run-wave-structure.md)。

| 术语 | 定义 |
|------|------|
| **Arena Run（竞技场一局）** | 玩家在单个固定竞技场中的一次完整游戏会话。以玩家死亡（或主动退出）结束；结束后重置全部本局状态（金币、经验、护盾、弹药等）。一局内怪物按波次刷出。 |
| **Wave（波次）** | 成组刷出的怪物批次。玩家**清空（全灭）**该批后该波结束、进入间歇。波次编号递增，整体难度随编号上升（Escalation）。 |
| **Escalation（难度递增）** | 随波次编号上升而提升挑战，双轴：**分数预算**第 N 波 = `60 × 1.2^(N-1)`（前波 1.2 倍）；**类型分阶段解锁**——1–3 波：普通女/普通黑女/游戏宅；4–6 波：+警察/律师/日本艺妓/研究员-老人；7–9 波：+牛仔/独眼牛仔/猎人/化学人；10–12 波：+健壮男/机器人-男电/机器人-女心；13+ 波：+驯兽师/忍者。参见 [ADR 018](file:///g:/work/Starter-Kit-FPS/docs/adr/018-score-based-wave-composition.md) 与 [ADR 022](file:///g:/work/Starter-Kit-FPS/docs/adr/022-enemy-weapon-expansion.md)。 |
| **Monster Cost（怪物分数/成本）** | 每种怪物类型的刷出代价，决定在波次预算中占多少配额。与击杀奖励值一致。由 `ENEMY_CONFIG` 字典数据驱动：普通女/普通黑女=5、警察=6、游戏宅=8、律师/日本艺妓=10、研究员-老人/牛仔=12、独眼牛仔/猎人=14、化学人=15、健壮男=16、机器人-男电=18、机器人-女心=20、驯兽师=22、忍者=25。参见 [ADR 022](file:///g:/work/Starter-Kit-FPS/docs/adr/022-enemy-weapon-expansion.md)。 |
| **Wave Budget（波次预算）** | 每波可用的总分数，RunDirector 刷怪时从可用类型中随机选取，直到总成本 ≥ 预算。初值 60，每波 ×1.2。纯函数 `wave_budget(wave_number)` 计算。 |
| **Wave Spawn（波次刷怪）** | 每波怪物在**波开始时一次性全刷**入竞技场；玩家**全灭**该批即视为该波清空、进入 Intermission。无 trickle / 分批刷怪。 |
| **Intermission（波次间歇）** | 两波之间的短暂停顿状态：**停止刷怪**，下一波由**玩家手动确认**开始（本会话 Q6 定为手动确认）。它本身**不是**消费窗口——金币消费走物理商店摊位（Shop，随时 walk-in），升级卡走 XP 即时暂停；间歇只负责"清场→下一波"的节奏断点。 |
| **Kill Reward（击杀奖励）** | 怪物死亡时结算的奖励，包含金币（Gold）与经验（XP），并小概率额外掉落血包（Health Pack）。三类资源（金币 / 经验 / 血包）的唯一来源（除每局初始值外）。**分档按怪类型**（初值，可调）：`monster_melee` = 5 金 / 5 XP、`monster_ranged` = 8 金 / 8 XP、`enemy`（飞行）= 10 金 / 10 XP。**血包掉率初值 10%**（可调）。**不随波次缩放**——收益靠每波怪物数量 / 种类递增自然增长，避免通胀。见本会话 Q7。 |
| **Gold（金币）** | 击杀掉落的货币资源。消费出口为**商店**（购买武器/弹药捆/手雷）。弹药按**弹药类型**（非按枪）购买捆包。参见 [ADR 022](file:///g:/work/Starter-Kit-FPS/docs/adr/022-enemy-weapon-expansion.md)。 |
| **gold_cost_per_bullet（单发金价）** | ~~已废弃~~（ADR 022）。`Weapon` 资源中此字段不再使用，弹药改为按类型在商店购买捆包（如"手枪弹捆 24 发 / 1 金"）。|
| **weapon_cost（武器售价）** | `Weapon` 资源新增字段（ADR 022）：该枪在商店的购买价格，范围 30–175 金。定价 = 战斗力 + 弹药经济性调节（弹药便宜的枪可略贵，弹药贵的枪适当压价）。 |
| **ammo_type（弹药类型）** | `Weapon` 资源新增字段（ADR 022）：该枪使用的弹药类型（`&"手枪弹"` / `&"步枪弹"` / `&"霰弹"` / `&"狙击弹"` / `&"能量电池"` / `&"榴弹"`）。|
| **Shop（商店 / 摊位）** | 竞技场中固定位置的物理摊位。玩家走入时暂停并打开三区购买 UI：**武器区**（随机展示 3 把枪）、**弹药区**（随机 3–4 种弹药捆：手枪弹捆 24 发/1 金、步枪弹捆 20/2 金、霰弹捆 8/3 金、狙击弹捆 4/4 金、能量电池捆 12/3 金、榴弹捆 2/5 金）、**手雷区**（随机 1–2 种：EMP 25 金/破片 20 金）。见 [ADR 022](file:///g:/work/Starter-Kit-FPS/docs/adr/022-enemy-weapon-expansion.md)。 |
| **XP / Experience（经验）** | 击杀掉落的成长资源，累积达阈值后触发**升级（Level Up）**。采用三选一升级卡模型，见 [ADR 011](file:///g:/work/Starter-Kit-FPS/docs/adr/011-level-up-three-choice-cards.md)。 |
| **Level Up（升级）** | XP 累积跨越阈值时触发的成长事件。触发时机：**XP 跨阈值即时暂停**弹三选一卡（本会话 Q5 定为即时暂停，非延迟到间歇）。**升级阈值随等级递增**：第 1 级需 20 XP，之后每级 ×1.3（20→26→34→44…）。每次升级从**升级池**随机抽取 3 个不重复增益呈现给玩家、**选 1 个**立即生效（本局内永久）。 |
| **Upgrade Pool（升级池）** | 升级增益的定义集合，每项含 `id` / 描述 / 生效参数（作用于 `health`、`shield`、`damage`、`move_speed`、`reload`、`reserve` 等现有属性）。升级时从中随机抽 3 个不重复项。 |
| **Upgrade Card（升级卡）** | 一次升级中呈现给玩家的单个增益选项（从升级池抽取）。玩家每级选 1 张。 |
| **Health Pack（血包）** | 怪物死亡**小概率**掉落的 consumable，拾取后恢复**血量（Health）**。是血量（非护盾）的唯一恢复手段——护盾靠自动恢复，不靠血包。 |
| **Shield（护盾）** | 玩家前的可再生吸收层，**位于血量之前吸收伤害**：一次伤害先扣护盾，溢出部分才扣血量；护盾在"最后一次受击后 `shield_regen_delay` 秒"开始以 `shield_regen_rate` 自动恢复（战斗中亦可回，不只间歇）。初值：`shield_max = 50`、`shield_regen_delay = 3s`、`shield_regen_rate = 10/s`（均可调）。见 [ADR 010](file:///g:/work/Starter-Kit-FPS/docs/adr/010-shield-absorbs-before-health.md)。 |
| **Health（血量）** | 玩家底层生命值（`player.gd` 已有 `health: int = 100`）。被护盾吸收后的溢出伤害扣减血量；**不自动恢复**，仅由血包恢复；归零即本局结束（护盾归零不致死）。见 [ADR 010](file:///g:/work/Starter-Kit-FPS/docs/adr/010-shield-absorbs-before-health.md)。 |
| **Game Over（游戏结束）** | 玩家 `health <= 0` 时本局结束：冻结游戏 → 显示结算界面（存活波数、击杀数、累计金币、达到等级等）→ 提供"重开一局"。取代原 `reload_current_scene()` 的**裸**重置（即"无界面、无反馈"地直接 reload），改为"先显示界面、玩家点重开后再 reload"。重开即全新本局、状态全重置。**累计金币**=本局总赚取（`gold_earned_total`，花掉的也算），非当前余额。见 [ADR 014](file:///g:/work/Starter-Kit-FPS/docs/adr/014-death-game-over-screen.md)。 |
| **RunDirector（运行编排器）** | 竞技场运行的最高层 seam（新增 `Main` 子节点 + `run_director.gd`）。持有本局状态（`gold` / `xp` / `level` / `wave` / `kills` / `gold_earned_total` / `rng`），负责波次推进、刷怪、清场检测、奖励结算、升级触发、游戏结束。暴露信号：`wave_started` / `wave_cleared(wave_number, cleared_by_timeout)` / `gold_changed` / `xp_changed` / `level_up_offered` / `kills_changed` / `game_over(stats)`。为 `PROCESS_MODE_PAUSABLE`（见 Pause Semantics）。 |
| **Spawn Point（出生点）** | 竞技场四周预定义的 `Marker3D`（≥ 8 个，挂 `Main/SpawnPoints` 下）。RunDirector 刷怪时打乱出生点顺序依次取用，需求 > 出生点数时循环 + ±2m 随机抖动避免重叠。取代现 `main.tscn` 中 `Monsters` 节点下的 4 个手放实例（移除）。 |
| **monster_type（怪物类型标识）** | 每个怪物脚本顶部 `const MONSTER_TYPE: StringName` 硬编码的类型标识（**不**用 `@export`，避免漏配）。取值与脚本/场景基名一致：`&"monster_melee"` / `&"monster_ranged"` / `&"enemy"`。怪物 `destroy()` 中 `died(monster_type)` 信号携带此值，RunDirector 按此查奖励表。 |
| **died（死亡信号）** | 三种怪物新增的 `signal died(monster_type: StringName)`，于 `destroy()` 内、`queue_free()` 前（含延迟 `queue_free()` 分支）发射。RunDirector 监听以结算奖励、递减 `alive_count`、计数 `kills`。**不**用 `get_child_count()` 检测清场（死亡动画期间怪物仍在树上会误判）。 |
| **alive_count（存活计数）** | RunDirector 维护的本波存活怪物计数。每刷一只 `+= 1`，每收一个 `died` 信号 `-= 1`。归零即该波清场、进入 Intermission。 |
| **Wave Timeout（波次超时兜底）** | 防卡怪软锁的安全网：波开始 `wave_timeout`（初值 120s，`@export`）后仍未清场，RunDirector 对剩余存活怪物**强制 `destroy()`**（正常结算奖励与 `died` 信号），`wave_cleared` 信号带 `cleared_by_timeout: bool` 标志。 |
| **Health Pack（血包）** | 怪物死亡 10% 概率掉落的 consumable（新建 `health_pack.tscn` Area3D + `health_pack.gd`）。**heal_amount = 25**（`@export`，恢复血量，不影响护盾）。在怪物死亡位置生成（飞行敌人死亡时 RayCast 投影到地面）。`Area3D.body_entered` 检测 `"player"` 组 → 调用 `player.heal(amount)`。**despawn_time = 15s** 后自动 `queue_free()`（最后 3s 闪烁提示）。`PROCESS_MODE_PAUSABLE`（暂停期间计时冻结）。血量（非护盾）的唯一恢复手段。 |
| **Player.heal(amount)** | `Player` 新增方法：`health = min(health + amount, max_health)`，发 `health_updated` 信号。**不**改护盾、**不**触发 damage 管线。供血包拾取调用。 |
| **max_health（最大血量）** | `Player` 新增 `@export var max_health: int = 100`（现 `health: int = 100` 无上限字段）。`heal` 与升级 `+20 最大血量` 均受此上限约束。 |
| **Pause Semantics（暂停语义）** | 三处暂停源（Shop walk-in / Level Up XP 跨阈值 / Game Over 死亡）统一用 `get_tree().paused = true` + `process_mode` 分层：暂停态 UI（Shop/LevelUp/GameOver）为 `PROCESS_MODE_WHEN_PAUSED`，Player/Monsters/弹体/血包/HUD/RunDirector 为 `PROCESS_MODE_PAUSABLE`（默认）。进入暂停时 `Input.set_mouse_mode(MOUSE_MODE_VISIBLE)`，退出 `MOUSE_MODE_CAPTURED`。护盾 regen 计时器随 Player 暂停冻结（商店里不回盾）。暂停源互斥：RunDirector 触发前检查 `get_tree().paused`，已暂停则不叠加（死亡优先级最高，会接管并隐藏其它暂停 UI）。见 [ADR 015](file:///g:/work/Starter-Kit-FPS/docs/adr/015-pause-semantics.md)。 |
| **Upgrade Stacking（升级叠加语义）** | 升级**可重复选、可叠加**（不同级升级可拿同一项）。**加法类**（`+20 最大血量` / `+5 护盾恢复速率` / `+0.5 移动速度` / `+1 每把枪备弹上限`）线性叠加；**乘法类**（`+15% 伤害` / `-10% 换弹时间`）乘法叠加（×1.15³ / ×0.9³）。`+20 最大血量` 同步回 20 血；`+5 护盾恢复速率` 不立即回盾。"3 个不重复"指本次三张互不相同，不跨级记忆。 |
| **Player Upgrade Bonus Fields（玩家升级 bonus 字段）** | 升级修改的是 **Player 实例的运行时 bonus 字段**，**不修改 `Weapon` 资源**（`.tres` 全局共享引用，直接改会跨局污染且可能写盘）。字段：`max_health` / `bonus_max_reserve`（有效备弹上限 = `weapon.max_reserve + bonus_max_reserve`）/ `damage_multiplier`（实际伤害 = `weapon.damage × damage_multiplier`）/ `reload_time_multiplier` / `move_speed_bonus` / `shield_regen_rate_bonus`。随场景重置自然清零（配合 `reload_current_scene()` 重开机制，无需手动 reset）。 |
| **RNG（可注入种子随机数）** | RunDirector 持有 `@export var rng_seed: int = 0`（0 = 随机）+ `var rng: RandomNumberGenerator`，`_ready()` 初始化。供血包掉率（issue 03）、升级抽卡（issue 05）、宝箱抽卡（issue 08）等概率逻辑使用，测试时可注入固定种子断言分布。 |
| **Chest（清场宝箱）** | 借鉴《元气骑士》清房间掉宝箱：每波 `wave_cleared` 后 RunDirector 在竞技场中央生成 1 个宝箱（`scenes/chest.tscn` Area3D + `scripts/chest.gd`）。玩家走近按 `interact`（E 键）开启 → 暂停 → 弹 3 选 1 奖励（Chest UI `PROCESS_MODE_WHEN_PAUSED`）。**不自动开**（玩家必须按 E）。同一时间场上最多 1 个宝箱（避免堆积）。开箱后宝箱 `queue_free()`。宝箱是清场大奖励，与 issue 03 击杀小概率血包互补。 |
| **Chest Reward（宝箱奖励）** | 宝箱开启后从奖励池抽 3 个不重复项呈现，玩家选 1 即时生效。奖励池 6 项（ADR 022 从 4 项扩展）：**金币大礼包**、**血包 ×3**、**经验大礼包**、**备弹补给**（回满所有弹种 `ammo_reserve`）、**随机武器**（按稀有度加权抽 1 把）、**手雷补给**（EMP +1、破片 +1）。 |
| **start_wave / interact（输入动作）** | RunDirector 新增 `start_wave` 输入动作（建议绑定 Enter 或 F 键）用于手动开下一波；宝箱交互复用现有 `interact` 输入动作（E 键）。两键分离避免冲突——开下一波与开宝箱是两个独立动作，玩家可不开宝箱直接开下一波。 |
| **RunDirector Public Methods（RunDirector public 方法）** | RunDirector 暴露给 issue 04（商店）/ 08（宝箱）/ 03（击杀奖励）调用的 public 方法：`add_gold(amount)`（加金币 + 累计 + 发信号）、`spend_gold(cost) -> bool`（扣金币，不足返回 false）、`add_xp(amount)`（加经验，跨阈值内部级联触发 issue 05 升级）、`add_kills(count=1)`（加击杀计数）。这些方法是金币/经验/击杀状态变更的唯一入口，避免 issue 直接改字段漏发信号。 |

# 卡住与挣扎（Stuck & Struggle）

参见 [ADR 016](file:///g:/work/Starter-Kit-FPS/docs/adr/016-stuck-struggle-punishment.md)。

| 术语 | 定义 |
|------|------|
| **Stuck（卡住）** | 玩家因跳入建筑缝隙等狭窄空间，水平移动被两侧碰撞完全阻挡的状态。判定条件：在地面（`is_on_floor()`）+ 有 WASD 输入（`input.length() > 0.1`）+ 实际水平速度 < 0.3 m/s + 持续 0.5 秒。触发后进入 STUCK 状态。 |
| **Struggle（挣扎）** | 玩家在 STUCK 状态下按 H 键触发的逃脱动作（ADR 022：原 G 键让给手雷投掷）。按 H 后进入 ESCAPING 状态，沿进入方向反向匀速推出。输入动作名 `struggle`，绑定 H 键。 |
| **Stuck State Machine（卡住状态机）** | 玩家卡住处理的三态状态机：`NORMAL`（正常）→ `STUCK`（卡住等待按 H）→ `ESCAPING`（推回中）→ `NORMAL`。STUCK 期间：禁止移动和跳跃，允许视角转动和射击，正常受伤。ESCAPING 期间：同样禁止移动/跳跃，允许视角/射击/受伤，不可取消。 |
| **Stuck UI Prompt（卡住提示）** | STUCK 状态时屏幕中下方显示的文字提示："按 H 尝试挣扎离开"。进入 STUCK 时显示，按 H 进入 ESCAPING 或回到 NORMAL 时隐藏。 |
| **Escape Push（推回）** | ESCAPING 状态下的匀速推出行为。速度 **0.5 m/s**（正常行走的 1/10），方向为卡住前最后有效移动方向的反向（`_last_move_dir`）。终止条件：`test_move` 检测前方无碰撞（脱离夹缝）或推出距离达 8m（安全上限）。推出完毕回到 NORMAL。 |
| **Stuck UI Prompt（卡住提示）** | STUCK 状态时屏幕中下方显示的文字提示："按 G 尝试挣扎离开"。进入 STUCK 时显示，按 G 进入 ESCAPING 或回到 NORMAL 时隐藏。 |
| **_last_move_dir（最后移动方向）** | 玩家正常移动时持续缓存的水平速度归一化方向（`Vector3`，y=0）。卡住触发时冻结该值，作为推回方向的依据（取反）。 |

## 敌人 AI 系统（Enemy AI）

参见 [ADR 017](file:///g:/work/Starter-Kit-FPS/docs/adr/017-enemy-ai-overhaul.md)。

| 术语 | 定义 |
|------|------|
| **Monster FSM（怪物状态机）** | 手写有限状态机（enum + match），定义在 `monster_base.gd`。状态枚举：`IDLE`（待机/缓降后初始）→ `CHASE`（追踪玩家）→ `ATTACK`（攻击中）→ `RETREAT`（远程怪后退/脱离）→ `LOST`（丢失视线，搜索最后已知位置）→ `IDLE`。基类管理状态转换框架，子类覆盖各状态的具体行为。取代原 `_physics_process` 中的 if/elif 链。 |
| **RVO Avoidance（RVO 避障）** | Godot 内置的 Reciprocal Velocity Obstacles 动态避障。所有地面怪物（`monster_melee`、`monster_ranged`）启用 `avoidance_enabled = true`，通过 `velocity_computed(safe_velocity)` 信号回调获取安全速度后执行 `move_and_slide()`。参数：`radius=0.5`、`neighbor_distance=5.0`、`max_neighbors=8`、`max_speed=move_speed`、`avoidance_layers=1`、`avoidance_mask=1`。飞行敌人不参与（Node3D，无物理体）。 |
| **Monster Collision Isolation（怪物碰撞隔离）** | 怪物之间**关闭物理碰撞**：所有怪物的 CollisionShape3D 设在 layer 2（怪物层），mask 只含 layer 1（地形）和 layer 3（玩家攻击区），不含 layer 2。怪物间距完全由 RVO 管理，避免物理碰撞与 RVO 互相打架导致抖动。 |
| **Line of Sight（视线检测）** | 怪物追踪前的可见性判定：从怪物眼部位置（`global_position + Vector3(0, 1.2, 0)`）向玩家胸部（`player.global_position + Vector3(0, 0.8, 0)`）发射 RayCast3D，若命中非玩家物体（墙体等）则视线被挡。视线被挡时进入 LOST 状态。 |
| **LOST State（丢失状态）** | 视线被挡后的搜索行为：怪物移动到**最后已知玩家位置**（`_last_known_player_pos`），到达后环顾 2s（缓慢转向扫描），若期间重新获得视线则回到 CHASE，否则回到 IDLE。LOST 状态下路径更新频率降至 0.6s（正常 0.3s），节省性能。 |
| **Path Throttle（路径节流）** | 非每帧更新 `nav_agent.target_position`，而是每 `path_update_interval = 0.3s` 更新一次。每只怪物按出生序号错开更新帧（`_path_timer_offset = index * 0.05`），避免同帧大量路径计算。CHASE 状态 0.3s，LOST 状态 0.6s。 |
| **Tactical Spread（战术散开）** | 近战怪物追踪时不全部冲向玩家同一点：每只怪根据出生序号分配一个**环绕偏移角**（`_approach_angle = index * (2π / alive_count)`），实际目标点 = 玩家位置 + 偏移（半径 1.5m 的圆上）。使多只近战怪从不同方向包围玩家，而非堆成一团。 |
| **Flying Enemy AI（飞行敌人 AI）** | `enemy.gd` 重写为追踪型：保持悬停高度（`hover_height = 4.0m`，相对地面），水平方向追踪玩家（速度 `fly_speed = 4.0`），保持 `preferred_distance = 8.0m` 距离环绕 strafing。使用 `lerp` 平滑移动而非瞬移。不再使用 NavMesh（飞行无视地形），纯向量计算。被墙挡时（RayCast 检测）升高越过或绕行。 |
| **NavMesh Tuning（导航网格调参）** | `nav_region.gd` 烘焙参数优化：`agent_radius = 0.5`（与碰撞体匹配）、`agent_height = 1.5`（怪物模型高度）、`cell_size = 0.25`（精度提升，默认 0.3 太粗）、`agent_max_climb = StepConstants.STEP_HEIGHT`（不变）、`agent_max_slope = 45.0`（默认）。更小的 cell_size 使路径更贴合墙壁，减少"穿墙感"。 |
| **Staggered Updates（错帧更新）** | 性能优化：多只怪物的路径计算分散到不同物理帧。每只怪在 `_ready()` 中按序号计算 `_update_delay = (index % 6) * 0.05`，路径计时器初始值偏移该量。16 只怪时分 6 帧处理，每帧最多 3 只怪请求路径。 |
| **Chain Aggro（连锁警觉）** | 两级感知模型：**被动感知**（`awareness_range`，默认 8m；近战 8m、远程 12m）+ **警觉传播**（alert 事件驱动，范围 `chase_range`）。alert 由玩家开枪（30m）、怪物开枪（25m）、怪物死亡（20m）触发，穿墙传播。IDLE 怪物被 alert 惊动后转 CHASE；进入 CHASE 后不因安静退回 IDLE（只走 LOST 路线）。实现见 `AlertSystem` autoload（`emit_alert` / `has_alert_nearby`），alert 缓存存活 0.5s。 |

## 敌人跳跃导航系统（Enemy Jump Navigation）

参见 [ADR 021](file:///g:/work/Starter-Kit-FPS/docs/adr/021-enemy-jump-navigation.md)。

| 术语 | 定义 |
|------|------|
| **Jump Link（跳跃链接）** | 连接 NavMesh 两个断开区域（地面→建筑顶）的 `NavigationLink3D` 节点。由 `NavJumpLinks` 工具类在 NavMesh 烘焙后自动生成。敌人通过 `NavigationAgent3D.link_reached` 信号感知到达链接起点，触发跳跃穿越。 |
| **NavJumpLinks（跳跃链接生成器）** | 静态工具类 `scripts/nav_jump_links.gd`，提供 `generate(gridmap, nav_region, jump_heights)` 方法。主策略：遍历 GridMap 找建筑顶部边缘 → 在相邻空地放置 `NavigationLink3D`；兜底策略：分析 NavMesh 找垂直相邻的断开区域。 |
| **JUMP State（跳跃状态）** | FSM 新增状态。仅从 CHASE 通过 `link_reached` 信号进入。行为：沿链接方向施加水平速度 + 垂直 `jump_velocity` 升空 → 落地检测 → 切回 CHASE。跳跃中不可攻击。 |
| **jump_height（跳跃高度）** | 怪物类型属性，定义该类型能跳上的最大垂直落差。`monster_melee` = 5m（能上一层楼+余量），`monster_ranged` = 2m（仅能上矮平台）。决定 `NavJumpLinks` 为该类型生成哪些链接。 |
| **jump_velocity（跳跃初速度）** | 跳跃时施加的垂直速度，由 `jump_height` 反推：`jump_velocity = sqrt(2 × gravity × jump_height)`，其中 `gravity = 20.0`。与玩家 `jump_strength` 同模式。 |

## 角色化敌人系统（Character-Based Enemies）

参见 [ADR 022](file:///g:/work/Starter-Kit-FPS/docs/adr/022-enemy-weapon-expansion.md)。

| 术语 | 定义 |
|------|------|
| **角色化敌人** | 从 Kenney `blocky-characters_20` 系列导入的 16 个具名角色敌人（排除丧尸/狂暴丧尸）。每个角色定位唯一，按近战/远程分组，各有独立 `@export` 参数（血量/移速/伤害/冷却/跳跃高度）。模型 GLB 与现有怪物同骨架/动画（`attack-melee-right`、`holding-right-shoot`、`walk/run/idle/die` 等），复用 `monster_base.gd`。 |
| **ENEMY_CONFIG（敌人配置字典）** | `run_director.gd` 中的 16 条目数据驱动字典，每项含 `cost`（波次预算消耗）/ `reward`（击杀金币与经验）/ `min_wave`（最早出现波次）/ `scene`（`.tscn` 路径）。替代旧 `MONSTER_COST` / `_available_types` / `_reward_for` 硬编码。 |
| **锚点敌人（Anchor Enemies）** | 第一批实现的 3 个敌人：忍者、驯兽师、化学人。目的是验证模块系统架构（Stealth/Dash/SummonPet/PlaceTrap 四类模块），之后 13 个敌人以它们为模板独立工单推进。 |
| **Cube-Pet（方块宠物）** | 驯兽师 SummonPet 模块召唤的跟班，来自 `kenney_cube-pets_1.0` 素材。不是独立敌种，不参与 RunDirector 波次/奖励体系。简单 AI：追玩家 → 近身咬（伤害 5）→ 死亡 `queue_free()`。驯兽师死亡时所有其召唤的 pets 同时销毁。 |

### 敌人花名册（16 角色）

| 角色 | 定位 | 模块 | 成本 | 首次波次 |
|------|------|------|------|---------|
| 普通女 | 基础近战 | 无 | 5 | 1 |
| 普通黑女 | 基础远程 | 无 | 5 | 1 |
| 游戏宅 | 近战骚扰 | DebuffAura | 8 | 1 |
| 警察 | 远程警觉 | 无（参数型） | 6 | 4 |
| 律师 | 远程控制 | DebuffOnHit | 10 | 4 |
| 日本艺妓 | 远程光环 | SpeedAura (10m/+20%) | 10 | 4 |
| 研究员-老人 | 远程支援 | HealAura | 12 | 4 |
| 牛仔 | 远程快枪 | MultiShot | 12 | 7 |
| 独眼牛仔 | 远程狙击 | ChargedShot | 14 | 7 |
| 猎人 | 远程陷阱 | PlaceTrap:Damage | 14 | 7 |
| 化学人 | 远程陷阱 | PlaceTrap:Poison | 15 | 7 |
| 健壮男 | 近战坦克 | BerserkOnDamage | 16 | 10 |
| 机器人-男电 | 近战护盾 | Shield + EMPBurst | 18 | 10 |
| 机器人-女心 | 近战自爆 | SelfDestruct + ExplodeOnDeath | 20 | 10 |
| 驯兽师 | 远程召唤 | SummonPet | 22 | 13 |
| 忍者 | 近战刺客 | Stealth + Dash | 25 | 13 |

## 敌人模块系统（Enemy Module System）

| 术语 | 定义 |
|------|------|
| **EnemyModule（敌人模块）** | 可插拔的特殊机制节点，挂为敌人 `.tscn` 的子节点。实现 `module_setup(enemy)` + 四个生命周期钩子（`on_enter_state` / `on_tick` / `on_damage` / `on_death`）。基类 `_run_module_hook(method, args)` 遍历 `_modules` 数组调用。新敌人 = GLB 模型 + 挂 1–3 个模块，不写新子类。 |
| **模块钩子（Module Hooks）** | `monster_base.gd` 在 FSM 生命周期各时机遍历模块调用：(1) `on_enter_state(state)` — 状态转换时；(2) `on_tick(delta)` — `_tick_state` 末尾每帧；(3) `on_damage(amount)` — `damage()` 减血前；(4) `on_death()` — `destroy()` 中 `_dead=true` 后、`died` 信号前。 |
| **模块清单（12 个）** | Stealth（隐身）、Dash（瞬步）、SummonPet（召唤）、PlaceTrap（放置陷阱，Poison/Damage 变体）、BerserkOnDamage（受击狂暴）、Shield（护盾）、EMPBurst（护盾破碎 EMP）、SelfDestruct（主动自爆）、ExplodeOnDeath（死亡自爆）、DebuffAura（减速光环）、MultiShot（快枪齐射）、ChargedShot（蓄力狙击）、HealAura（治疗光环）、SpeedAura（加速光环）、DebuffOnHit（命中减伤）。 |
| **模块冲突策略** | 模块设计为不互斥：若两个模块修改同一属性（如移速），按 `_modules` 数组顺序后覆盖前。需要互斥的场景由单个模块内部防御（如 Shield 在 `on_damage` 中将 amount 置零，后续模块收 amount=0）。 |

## 弹药类型系统（Ammo Type System）

| 术语 | 定义 |
|------|------|
| **ammo_reserve（弹药池）** | `Player` 的弹药储备，从各枪独立 `Array[int]` 重构为 `Dictionary[StringName, int]`（ADR 022）。按 6 个弹种键值存储：`手枪弹` / `步枪弹` / `霰弹` / `狙击弹` / `能量电池` / `榴弹`。同一弹种的枪共享备弹池。初始仅 `手枪弹`=36，其余为 0。 |
| **弹药捆（Ammo Bundle）** | 商店售卖的弹药单位。6 种弹药各有固定捆量：手枪弹捆 24 发/12 金、步枪弹捆 20/16、霰弹捆 8/16、狙击弹捆 4/16、能量电池捆 12/20、榴弹捆 2/20。每次进店随机展示 3–4 种不重复捆。 |
| **Weapon Slot（武器槽）** | 玩家最多携带 3 把枪（`weapons` 数组最大长度 3）。初始配装：手托手枪-小口径 + 2 空槽。**允许持有重复武器**（3 槽可全装同一把枪）。替换武器时弹药保留（弹药池按弹种维度，不因持枪变化丢失）。 |
| **Weapon Inspect（武器检视）** | 按 **TAB 键**打开的全屏武器属性面板。三张卡片并排展示 3 个武器槽的完整属性：伤害/DPS/射速/精度条/弹匣/备弹/换弹/弹药类型/耐久条/售价/定位/可靠性★。当前装备武器高亮金边。**对比功能：点击一张卡片固定为"参考"**（蓝边），其余卡片自动显示相对差异——绿色 ▲ 表示更优、红色 ▼ 表示更差。再次点击已固定的卡片取消对比。ESC 关闭。弹药状态实时刷新（开火时同步更新弹匣/备弹数字）。被商店/升级等暂停 UI 打断时自动关闭。实现：`scripts/weapon_inspect_ui.gd` + `scenes/weapon_inspect_ui.tscn`，由 HUD（`scripts/hud.gd`）托管并处理 TAB 输入。 |

## 武器扩展（Weapon Expansion）

| 术语 | 定义 |
|------|------|
| **武器库（20 把）** | 从 `kenney_blaster-kit_2.1` 导入的 18 把新枪 + 保留 2 把旧枪（blaster/blaster-repeater）。按 6 种弹药分类：手枪弹 4 把、步枪弹 3 把、霰弹 4 把、狙击弹 2 把、能量电池 6 把、榴弹 1 把。全部参数见 ADR 022 武器参数表。 |
| **weapon_cost（武器售价）** | `Weapon` 资源新增字段，范围 30（手托手枪）–175（榴弹发射器）金。商店武器区按此价格出售，宝箱随机武器按稀有度加权抽样（低档 60%/中档 25%/高档 15%）。 |
| **持续射线枪** | 能量电池弹种的特殊行为武器：开火时持续发射光束（非离散弹体），每 tick 消耗弹药并造成持续伤害。需要新武器行为模式（`weapon_mode = "beam"`），在 P4 工单（issue 15）实现。 |
| **短柄榴弹发射器** | 榴弹弹种的爆炸武器：发射弹体命中后 AOE 爆炸（`explosion_radius` / `explosion_damage`）。扩展现有弹体系统的爆炸行为，在 P4 工单实现。 |

## 耐久度系统（Weapon Durability）

| 术语 | 定义 |
|------|------|
| **durability_max（最大耐久）** | `Weapon` 资源新增字段（ADR 022），定义该枪从全新到损坏的总射击次数（扣扳机计，非弹丸数）。范围 25–280，见 ADR 022 武器参数表。设计原则：高射速枪需要更多总耐久（机枪 280 发但只能连续开火 22s），爆发型武器收紧（重型狙击仅 35 发——每发都珍贵）。
| **Durability（当前耐久）** | 每扣一次扳机减 1。归零后武器**爆掉**：播放粒子特效 → 自动从武器槽移除 → 槽位腾空 → 自动切下一把枪（或空手）。不可修复（v1）。鼓励玩家持多把枪轮换。 |
| **Durability Display（耐久显示）** | HUD 每把武器图标下方显示耐久进度条（百分比或细条），低耐久（≤20%）时变红警告。 |

## 武器丢弃与拾取

| 术语 | 定义 |
|------|------|
| **drop_weapon（丢枪）** | 新增输入动作，默认 **X 键**。丢弃当前手持武器，在脚下生成可拾取的地面物体（小武器模型旋转 + 发光 + `Area3D`）。丢弃后自动切到下一把枪（若还有）。 |
| **Weapon Pickup（武器拾取）** | 地面武器物体为 Area3D，玩家走过时若有**空槽**（<3 把）则自动装填；3 槽全满不触发。拾取时保留该武器当前耐久度（不是重置满——公平性）。商店/宝箱获得的武器均满耐久。**允许持有重复武器**（如 3 槽全装同一把枪），无排重限制。 |
| **Weapon Break（武器爆掉）** | 耐久归零时触发：播放火花/碎片粒子特效 → 从 `weapons` + `weapon_durability` 数组移除 → 槽位自动腾空 → 自动切下一把。无需手动丢弃。 |

## 键位汇总

| 功能 | 键 | 动作名 |
|------|------|------|
| 挣扎 | **H** | `struggle`（ADR 022 从 G 改） |
| 手雷投掷 | **G** | `throw_grenade`（新增） |
| 丢枪 | **X** | `drop_weapon`（新增） |

## 手雷系统（Grenade System）

| 术语 | 定义 |
|------|------|
| **Grenade Slot（手雷槽）** | 独立于武器 3 槽的投掷物槽。`grenades: Dictionary[StringName, int]`，最多携带 5 颗（含 EMP 与破片合计）。初始 EMP=1、破片=0。操作：G 键 `throw_grenade` 蓄力瞄准 → 释放投掷。 |
| **EMP 控制手雷** | 由烟雾手雷 GLB 改制。落地 0.5s 后引爆，半径 6m，范围内敌人移速×0.3 + 禁用 ATTACK 状态，持续 3s。商店 25 金/颗。 |
| **破片手雷** | 由破片手雷 GLB 改制。落地 0.8s 后引爆，半径 5m，伤害 40（AOE）。商店 20 金/颗。 |

## 场景文件约定（Scene File Conventions）

| 约定 | 说明 |
|------|------|
| **语义化 UID** | 手动创建的场景使用可读 UID，格式：`b` + 功能缩写 + issue 编号 + 可选后缀。示例：`bshopstation04`（商店/issue 04）、`blevelup05card`（升级卡/issue 05）、`btesthealthpack01`（血包测试/issue 01）。**禁止**让编辑器随机重新生成已有语义 UID——会导致引用方（如 `main.tscn` 的 `ext_resource`）断裂。 |
| **UID 变更须同步引用** | 若确需变更某场景 UID，必须全项目搜索旧 UID 并同步更新所有 `ext_resource` 引用（`git grep "<旧UID>" -- "*.tscn"`）。 |
| **load_steps 可省略** | `gd_scene` 头的 `load_steps=N` 为可选元数据，Godot 加载时自动计算。省略不影响功能，编辑器重保存时可能自动移除。 |
| **测试场景 UID** | 测试场景（`tests/`）同样使用语义 UID：`btest` + 功能名 + issue 编号，如 `btestshop04station`。 |


