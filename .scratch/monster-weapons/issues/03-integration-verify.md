Status: done

Blocked by: 01, 02

# T3 — 联调验证（两个怪物同场 + 空手变体）

## 构建内容

在一个场景里同时放置远程怪、近战持剑怪、近战空手怪，验证整个特性的端到端行为：枪/剑模型正确挂在 `arm-right` 并随手臂骨骼动画跟随、弹体确实从枪口 `Muzzle` 射出、骨骼攻击动画正常播放且伤害在活跃帧命中玩家、空手怪能正常拳击、且武器网格（layer 3）**不出现在小地图**中（小地图俯视相机 `cull_mask = layer 1`）。这是整个特性的收尾验证切片。

## 验收标准

- [x] `monster_ranged` 与 `monster_melee`（持剑与空手两态）同场可正常运行，无报错 / 无 Tween 与骨骼动画冲突残留
- [x] 远程怪物可见持枪、播放 `holding-right` 持枪姿态，弹体从枪口 `Muzzle` 生成（非身体凭空冒出），后坐+闪光+音效齐备；开火时枪随 `arm-right` 保持在手中
- [x] 近战持剑怪可见持剑，播 `attack-melee-right` 骨骼剪辑（剑随手臂劈下），活跃帧命中玩家并扣血
- [x] 近战空手怪（`melee_weapon_model = null`）不挂武器，同样播 `attack-melee-right`（拳击）并在活跃帧命中玩家
- [x] 小地图俯视渲染**不含**枪/剑 blob（武器 `layers = 4`，俯视相机 `cull_mask = layer 1`）
- [x] 主相机视野（layers 3–20）中武器正常显示，且与怪物身体（已移到 layer 3）一致

## 评论

- 收尾验证切片，阻塞于 T1、T2。
- 小地图图层语义见 ADR 007 与 CONTEXT.md「Minimap Enemy Layer」：怪物真实 mesh 已从 layer 1 挪到 layer 3，武器须同设 `layers = 4` 才不进小地图。
- **v2 修正**：验证重点从"程序化 Tween 挥武器"改为"骨骼 `AnimationPlayer` 剪辑播放 + `arm-right` 挂载跟随"。空手变体为本次新增验证项（见 ADR 008「空手攻击」决策）。
- 全特性设计背景见 ADR 008（`docs/adr/008-monster-weapons-and-animations.md`）。
