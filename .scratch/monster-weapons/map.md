# map.md — monster-weapons

## 已做决策（来自 grill 会话 + ADR 008）

- **整体目标**：人形怪物（`monster_ranged` / `monster_melee`）装备并展示可见武器模型、播放模型自带的**骨骼攻击动画**，而非"凭空生成弹体 / 整体 lunge / 程序化挥武器"。
- **核心约束（v2 修正）**：两个怪物 GLB 实为**带 30 条命名动画的节点式刚体绑定**（`attack-melee-right` 等），`import_as_skeleton_bones=false` 仅不暴露骨骼节点、不等于无动画。武器挂 `arm-right` 子节点、随手臂动画跟随；攻击用 `AnimationPlayer` 播真实剪辑。
- **远程（T1）**：复用 `blaster.glb`，挂 `arm-right`；弹体从枪口 `Muzzle` `Marker3D` 射出；常驻 `holding-right` 持枪姿态 + 开火反馈（后坐 Tween + 枪口闪光 `burst_animation.tres` + `enemy_attack.ogg`）。
- **近战（T2）**：默认一把与玩家 `Sword6.glb` 不同的 `SwordXXX.glb`（`@export` 可换、**可留空**）；播 `attack-melee-right` 骨骼剪辑（剑随手臂），伤害时机对齐活跃帧，距离判定不变；`melee_weapon_model = null` 即空手变体（同剪辑拳击）。
- **图层**：武器 `layers = 4`（layer 3），进主相机、不进小地图（小地图 `cull_mask = layer 1`）。
- **"不要直接发射子弹"含义**：保留弹体，但怪物持枪、子弹从枪口出（非 hitscan、非取消远程）。

## 工单前沿

- `issues/01-ranged-monster-holds-gun.md` — done，无阻塞
- `issues/02-melee-monster-holds-sword.md` — done，无阻塞
- `issues/03-integration-verify.md` — done，阻塞于 01, 02
- `issues/04-monster-locomotion-animation.md` — done，阻塞于 01, 02（补强：移动/待机接骨骼剪辑，替掉程序化 bob）
- `issues/05-monster-death-animation.md` — done，阻塞于 01, 02（补强：死亡接 `die` 剪辑，替掉程序化缩小）

## 参考

- ADR 008：`docs/adr/008-monster-weapons-and-animations.md`
- CONTEXT.md：「怪物武器与动画（Monster Weapons & Animation）」术语表
- 相关 ADR：002（弹体真实伤害）、005（HitFeedback）、006（玩家近战独立系统）、007（小地图图层）
