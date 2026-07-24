# ADR 008: 人形怪物持武器模型并播放骨骼攻击动画

> **修订记录（v2）**：初版基于"怪物 GLB 是静态网格、无骨骼、只能程序化 Tween"的前提，已证伪。经解析 GLB 确认两个怪物模型是**带 30 条命名动画的节点式刚体绑定**，攻击动画（`attack-melee-right` 等）与持枪姿态（`holding-right-shoot` 等）均真实存在。本版据此重写：武器挂到 `arm-right` 节点、攻击改用 `AnimationPlayer` 播真实剪辑，空手怪直接播拳击剪辑、不挂武器。

## 决策

人形怪物（`monster_ranged`、`monster_melee`）改为**装备并展示可见的武器模型**，攻击时播放**模型自带的骨骼攻击动画**，而不是"凭空生成弹体 / 做整体身体前冲 / 程序化挥武器网格"。

- **远程怪物（monster_ranged）**：手握一把枪模型（复用 `models/weapons/blaster.glb`），作为 `arm-right` 节点的子节点挂载（手臂挥动时枪自然跟随）；弹体仍由 `projectile.tscn` 承载（保留真实伤害，ADR 002），但从枪管前端 `Muzzle` `Marker3D` 射出；开火时保持持枪姿态（`holding-right`）+ 枪口闪光 + 音效 + 枪模型后坐回弹。
- **近战怪物（monster_melee）**：手握一把剑模型（默认一把与玩家不同的 `SwordXXX.glb`，可 `@export` 替换），作为 `arm-right` 子节点挂载；攻击播放模型自带 `attack-melee-right` 骨骼剪辑（剑随手臂劈下）；伤害结算时机对齐挥砍"活跃帧"。
- **空手怪（monster_melee 的 `melee_weapon_model = null` 变体）**：**不挂任何武器**，攻击同样播放 `attack-melee-right`（拳击），靠手臂骨骼动作完成"手臂近战"，伤害同样在活跃帧结算。

**核心约束（已核查，v2 修正）**：两个怪物 GLB（`monster-ranged.glb`、`monster-melee.glb`）**并非静态网格**——它们是完整绑定的模型，`animation/import = true`，导入后 GLB 实例内自带 `AnimationPlayer` 与全部动画剪辑。`import_as_skeleton_bones = false` **只表示骨骼不暴露成可编辑的 `BoneAttachment` 节点**，并不等于"无骨骼 / 无动画"。进一步解析 GLB 发现 `skins` 为空数组，说明这是**节点式刚体绑定**：`character-f → root → (leg-left, leg-right, torso) → torso → (arm-left, arm-right, head)`，每条肢体是独立网格，动画直接驱动这些节点变换旋转肢体（无顶点蒙皮）。`arm-right` / `arm-left` 即手臂远端节点（**无独立 hand 节点**），武器作为 `arm-right` 的子节点、用本地偏移调到手掌位置即可随手臂挥动。

## 背景

当前两个怪物都"不持武器、攻击无骨骼动画"：

- `monster_ranged.gd` 的 `_start_attack()` 仅做一个整体身体后仰 Tween（`model.rotation:x` + `position:y`），`_fire_projectile()` 直接 `instantiate(projectile.tscn)` 于身体上的 `ShootPoint` —— 没有枪模型、没有开火姿态，子弹像是从怪物身体里凭空冒出。
- `monster_melee.gd` 的 `_start_attack()` 是整体身体 `rotation.x` + 前冲 `position` 的 lunge Tween，**没有武器模型、没有挥砍动画**；其 `HitArea` 节点是死代码，伤害靠距离判定。

用户希望人形怪物"使用枪械或近战武器，不要直接发射子弹"（即视觉上要看得见武器与攻击动作），且"近战要有近战动画"，并补充"敌人也可以有空手的，只能使用手臂近战"。这与玩家侧已落地的武器/近战体系（ADR 006）形成对照，而怪物侧仍停留在"无模型直接生成"的原始阶段。

v1 的关键修正：初版设计误判怪物无骨骼、只能程序化 Tween；实际模型自带骨骼攻击动画，故攻击表现应直接播这些剪辑，武器挂在手臂节点上随之运动。

## 替代方案

| 方案 | 描述 | 选定 / 否决 |
|------|------|-------------|
| A. 持枪模型 + 枪口出弹 + 真实持枪姿态（**选中**） | 远程怪物手握 `blaster.glb`（挂 `arm-right`），弹体从枪口 `Muzzle` 射出，保持 `holding-right` 持枪姿态 + 后坐 + 枪口闪光 + 音效 | 保留 ADR 002 弹体真实伤害体系，仅改变"子弹从哪来"与外观；姿态用模型自带 `holding-right` / `holding-right-shoot` 剪辑，最贴合"用枪打" |
| B. 远程怪物改 hitscan 射线 | 删掉弹体，开火改为即时 `RayCast` 命中 | 否决：需重写命中判定、失去发光弹体视觉与飞行过程，偏离 ADR 002 |
| C. 远程怪物也改近战 | 取消远程弹体，全部近战冲锋 | 否决：违背"远程保持距离"的 AI 设计 |
| D. 近战用 GLB 烘焙攻击动画（**选中**） | 武器挂 `arm-right`，`_start_attack()` 播 `attack-melee-right` 骨骼剪辑；空手则同剪辑不挂武器（拳击） | 模型自带该剪辑、武器随手臂自动跟随，表现最自然、开发量最低 |
| E. 近战程序化 Tween 挥武器网格（初版原方案） | 无 AnimationPlayer，用 Tween 手动转武器网格做挥砍弧线 | 否决：仅在"无骨骼"误判下成立；真实骨骼攻击动画存在后，该方案既多余又不如骨骼动画自然 |

## 影响

### monster_ranged（远程怪物）

- `monster_ranged.tscn` / `monster_ranged.gd` 变更：
  - 新增 `@export var gun_model: PackedScene`（默认 `models/weapons/blaster.glb`）、`@export var muzzle_flash_frames: SpriteFrames`（默认 `sprites/burst_animation.tres`，复用 `enemy.tscn` 的闪光素材）。
  - `_ready()` 中：定位 `arm-right` 节点（`character_model.find_child("arm-right", true, false)`，其中 `character_model = $Model/CharacterModel`），把枪模型 `instance` 为其子节点，调本地 `position`/`rotation`/`scale` 偏移使枪落在右手、枪管朝怪物 forward（=-z，怪物 `look_at` 朝向玩家即 -z 向前）；枪模型下挂 `Muzzle` `Marker3D`（枪管前端），作为弹体生成点，**取代**身体 `ShootPoint`；缓存 `AnimationPlayer` 引用（`character_model.find_child("AnimationPlayer", true, false)`），并 `play("holding-right")` 作为常驻持枪姿态。
  - 枪模型与枪口闪光的 `MeshInstance3D` / `AnimatedSprite3D` 的 `layers` 设为 `4`（layer 3），与怪物身体（已移到 layer 3）一致、进主相机、**不进小地图**（俯视相机 `cull_mask = layer 1`，见 ADR 007）。
  - `_fire_projectile()` 改为在 `Muzzle` 的全局变换处生成 `projectile.tscn`（保留 `enemy_spread` 距离衰减、紫色弹体、`shooter = self`）；`_start_attack()` 的开火反馈：移除整体后仰 Tween，改为 (1) 枪模型沿局部 +z 的**后坐 Tween**（弹出后回位，与 `holding-right` 骨骼姿态叠加，不冲突；枪口在 -z 前方，后坐沿 +z 后方推，物理正确）；(2) `Muzzle` 处 `AnimatedSprite3D` 枪口闪光一次性播放；(3) 复用场景已有的 `enemy_attack.ogg`。
  - **注意**：T4（移动/待机接 `walk`/`run`/`idle` 骨骼剪辑、替掉程序化 bob）与 T5（死亡接 `die` 骨骼剪辑、替掉程序化缩小）**已实施**，见 `issues/04-monster-locomotion-animation.md` 与 `issues/05-monster-death-animation.md`。两怪共享逻辑已抽取到基类 `objects/monster_base.gd`。详见 `models/monsters/ANIMATIONS.md` §6。
- 不改动 `Weapon` 资源、弹药/换弹体系（怪物本就不参与弹药）。

### monster_melee（近战怪物，含空手变体）

- `monster_melee.tscn` / `monster_melee.gd` 变更：
  - 新增 `@export var melee_weapon_model: PackedScene`（**可空**；默认一把与玩家 `Sword6.glb` **不同**的 `SwordXXX.glb`；玩家近战用 `Sword6.glb`，怪物用另一把以区分辨识度）。空值 = 空手变体。
  - `_ready()` 中：定位 `arm-right` 与 `AnimationPlayer`（同远程）；若 `melee_weapon_model != null`，把剑模型 `instance` 为 `arm-right` 子节点（本地偏移调到"握在手里"、缩放适配怪物网格），其 `MeshInstance3D` `layers = 4`；若 `null` 则不挂武器（空手）。
  - `_start_attack()` 以 `AnimationPlayer.play("attack-melee-right")` **取代整体 lunge Tween**；持剑时剑随手臂劈下，空手时即为拳击。攻击剪辑本身含手臂挥动（及可能的轻微前冲位移），无需手动补前冲 Tween。
  - 伤害时机：`_deal_damage()` 的调用时机对齐 `attack-melee-right` 的**活跃帧**（剪辑前摇结束、挥到位的时刻），用 `SceneTree.create_timer(active_frame_time)` 触发（约 0.2s，按剪辑实际时长微调）；**保持距离判定**（`_deal_damage` 现有 `attack_range` 逻辑不变），不引入 `Area3D` 命中区。
  - `HitArea` 节点（死代码）可一并删除，不在本次强制范围。
- 不改动 `damage(amount)` / `HitFeedback.flash`（ADR 005）链路。

### 复用与一致性

- 枪口闪光素材复用 `enemy.tscn` 的 `sprites/burst_animation.tres`（`SpriteFrames`），不新增素材。
- 开火音效复用 `enemy_attack.ogg`（场景已有 `AudioStreamPlayer`）。
- 武器挂载到 `arm-right` 节点（而非 `Model` 固定变换），使其随手臂骨骼动画自然跟随——这是相对初版方案的核心修正。
- 空手怪不引入任何新逻辑分支，仅是 `melee_weapon_model` 为空的配置态，攻击共用 `attack-melee-right` 剪辑。

## 后续决策（grill 会话补充）

下列子决策在 grill 会话中逐一确定，详见 CONTEXT.md「怪物武器与动画（Monster Weapons & Animation）」对应术语条目。

| 子决策 | 选定方案 | 关键理由 |
|--------|----------|----------|
| **"不要直接发射子弹"含义** | 保留弹体，但怪物持枪、子弹从枪口 `Marker3D` 射出 | 保留 ADR 002 弹体真实伤害体系；仅改变子弹来源与外观，最贴合"用枪打" |
| **远程枪模型** | 复用 `models/weapons/blaster.glb` | 开发量最小；玩家一眼认出是"枪" |
| **近战动作样式** | 播模型自带 `attack-melee-right` 骨骼攻击剪辑（剑随手臂；不再手动前冲 Tween） | 模型自带真实攻击动画，表现自然、武器自动跟随手臂；初版"程序化 Tween 挥武器"仅在误判无骨骼时成立 |
| **近战武器模型** | 换一把与玩家不同的剑（`SwordXXX.glb`，`@export` 可换，可留空） | 怪物武器与玩家区分、更具辨识度；留空即空手变体 |
| **远程开火反馈** | 持枪姿态 `holding-right` + 后坐 Tween + 枪口闪光 + `enemy_attack.ogg` | 打击感完整；素材/音效复用现有 |
| **近战命中判定** | 距离判定（沿用 `_deal_damage`）+ 活跃帧对齐 | 与现有怪物逻辑一致；不做 `Area3D` 命中区 |
| **空手攻击** | 仅拳击（`attack-melee-right` / `attack-melee-left`，不挂武器） | 用户明确"空手只能手臂近战"；拳击最贴合字面语义，实现最简单 |
| **（修正）骨骼前提** | 怪物 GLB 实为带 30 条命名动画的节点式刚体绑定，`import_as_skeleton_bones=false` 仅不暴露骨骼节点 | 初版误判为静态网格，已通过解析 GLB 纠正；详见本 ADR 顶部"修订记录" |
