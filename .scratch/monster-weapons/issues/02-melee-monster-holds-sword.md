Status: done

Blocked by: 无

# T2 — 近战怪物持剑/空手，播骨骼攻击动画

## 构建内容

让近战怪物（`monster_melee`）**握住一把与玩家不同的剑模型**（默认一把 `SwordXXX.glb`，`@export` 可换；可留空），剑作为 `arm-right` 节点的子节点挂载；攻击从整体 lunge Tween 改为**播放模型自带 `attack-melee-right` 骨骼攻击剪辑**（剑随手臂劈下），伤害结算时机对齐挥砍**活跃帧**（距离判定逻辑不变）。**空手变体**（`melee_weapon_model = null`）不挂武器、同样播 `attack-melee-right`（拳击），满足"敌人也可以有空手的，只能使用手臂近战"。玩家能看到"怪物举臂→劈下/出拳→命中"的完整骨骼动作。

## 验收标准

- [x] `monster_melee` 新增 `@export var melee_weapon_model: PackedScene`（**可空**）；默认一把与玩家 `Sword6.glb` **不同**的 `SwordXXX.glb`
- [x] `_ready()` 中 `character_model = $Model/CharacterModel`，缓存 `AnimationPlayer` 与 `arm-right`（`find_child(..., true, false)`）；若 `melee_weapon_model != null`，把剑 `instance` 为 `arm-right` 子节点（本地偏移调到"握在手里"、缩放适配怪物网格），其 `MeshInstance3D` `layers = 4`（layer 3）；若 `null` 则不挂武器（空手）
- [x] `_start_attack()` 以 `AnimationPlayer.play("attack-melee-right")` **取代整体 lunge Tween**（持剑=挥剑，空手=拳击；攻击剪辑含手臂挥动，无需手动前冲 Tween）
- [x] `_deal_damage()` 调用时机对齐 `attack-melee-right` **活跃帧**（约剪辑 0.2s 处，按实际时长微调），由 `SceneTree.create_timer(active_frame_time)` 触发；距离判定逻辑与 `attack_range` 不变
- [x] 剑模型 `MeshInstance3D` 的 `layers` 设为 `4`（layer 3，进主相机、不进小地图）；空手变体无需此步
- [x] （可选）删除 `monster_melee.tscn` 中死代码 `HitArea` 节点

## 评论

- **核心前提已修正（v2）**：怪物 GLB 是带真实攻击动画的节点式刚体绑定，`attack-melee-right` 等剪辑确实存在；初版"无骨骼、只能程序化 Tween 挥武器"的设计已废弃，改为播骨骼剪辑、武器挂 `arm-right` 随手臂跟随。见 ADR 008 顶部修订记录。
- 近战命中判定**保持距离判定**（沿用 `_deal_damage` 现有距离逻辑），**不**引入 `Area3D` 命中区：怪物侧无先例（`HitArea` 是死代码）。见 ADR 008 与 CONTEXT.md「Active Frame（活跃帧，怪物近战）」。
- 具体剑型号由 `@export` 配置（留空即空手），避免硬编码，便于无代码替换。
- 挥砍动作（播 `attack-melee-right` 骨骼剪辑）、近战武器选型（换一把不同的剑）、空手=拳击，来自 grill 会话。
