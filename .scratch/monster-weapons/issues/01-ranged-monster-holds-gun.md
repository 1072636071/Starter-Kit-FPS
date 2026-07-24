Status: done

Blocked by: 无

# T1 — 远程怪物持枪、从枪口开火、播持枪姿态

## 构建内容

让远程怪物（`monster_ranged`）** visibly 握住一把 `blaster.glb` 枪模型**，枪作为 `arm-right` 节点的子节点挂载（手臂挥动时枪随之跟随）；弹体不再从身体 `ShootPoint` 凭空生成，而是从枪管前端 `Muzzle` `Marker3D` 射出；开火时保持模型自带 `holding-right` 持枪姿态 + 播放**枪口闪光（`burst_animation.tres`）+ `enemy_attack.ogg` + 枪模型后坐回弹**。玩家能直观看到"怪物用枪打我"，而非子弹凭空冒出。

## 验收标准

- [x] `monster_ranged` 新增 `@export var gun_model: PackedScene`，默认 `models/weapons/blaster.glb`；`@export var muzzle_flash_frames: SpriteFrames`，默认 `sprites/burst_animation.tres`
- [x] `_ready()` 中通过 `character_model.find_child("arm-right", true, false)`（`character_model = $Model/CharacterModel`）定位手臂节点，把枪模型 `instance` 为 `arm-right` 子节点，调本地 `position`/`rotation`/`scale` 偏移使枪落右手、枪管朝怪物 forward（=-z）；缓存 `AnimationPlayer`（`character_model.find_child("AnimationPlayer", true, false)`）并 `play("holding-right")` 作为常驻持枪姿态
- [x] 枪模型下挂 `Muzzle` `Marker3D` 于枪管前端，作为弹体生成点，取代身体 `ShootPoint`
- [x] `_fire_projectile()` 改为在 `Muzzle` 世界变换生成 `projectile.tscn`（保留 `enemy_spread` 距离衰减、紫色弹体、`shooter = self` 敌人弹体归属）
- [x] 开火反馈：移除整体后仰 Tween，改为 (1) 枪模型沿局部 +z 的**后坐 Tween**（弹出后回位，叠加于 `holding-right` 骨骼姿态，不冲突；**规格澄清**：原 spec 写"-z"是笔误——枪口在局部 -z 前方，后坐应沿 +z 后方推才物理正确，已更正 ADR 008 与 CONTEXT.md）；(2) `Muzzle` 处 `AnimatedSprite3D` **枪口闪光**一次性播放；(3) 复用场景已有 `enemy_attack.ogg`
- [x] 枪模型与枪口闪光的 `MeshInstance3D`/`AnimatedSprite3D` 的 `layers` 设为 `4`（layer 3，进主相机、不进小地图）
- [x] 不改动 `Weapon` 资源、弹药/换弹体系（怪物本就不参与弹药）

## 评论

- **核心前提已修正（v2）**：两个怪物 GLB 是带 30 条命名动画的节点式刚体绑定（解析 GLB 确认），`import_as_skeleton_bones=false` 仅不暴露骨骼节点、并不等于无动画。武器挂 `arm-right` 子节点即可随手臂动画跟随——这是相对初版"固定变换挂载 + 程序化 Tween"的关键修正。见 ADR 008 顶部修订记录。
- 枪口闪光素材复用 `enemy.tscn` 的 `sprites/burst_animation.tres`（`SpriteFrames`），不新增素材。
- 弹体真实伤害体系保持 ADR 002 不变，仅改变子弹来源与外观。
- 现有 `model` 父节点的 `_animate_walk`/`_animate_idle` 程序化摆动层级在骨骼动画之上，可叠加共存；v1 不接入 `walk`/`sprint` 骨骼剪辑（留作未来增强）。
- 远程开火反馈层级（持枪姿态+后坐+闪光+音效）、枪模型选型（blaster.glb）来自 grill 会话，见 CONTEXT.md「怪物武器与动画」。
