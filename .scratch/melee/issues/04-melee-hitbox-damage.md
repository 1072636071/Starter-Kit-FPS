Status: ready-for-agent
Blocked by: 03

# T4 — Melee Hitbox 命中区与伤害结算

## 构建内容

在 `player.gd` 中加入**前方 `Area3D` 命中区（Melee Hitbox）**，尺寸按 `melee_reach=2.0m` 前向深度、宽高约 `1.5m`，覆盖身前一小片（非全向）。仅在挥砍动画的"活跃帧"开启 `monitoring`，用 `get_overlapping_bodies()` 收集命中的怪物；以 `Set` 去重，保证**每次挥砍每个敌人只结算一次伤害**；对每个命中敌人调用其既有 `damage(melee_damage)` 接口（怪物 `damage()` 已接入 ADR 005 的 `HitFeedback.flash`，命中变色反馈自动生效）。短距离下基本不穿墙。

## 验收标准

- [ ] 玩家身前新增 `Area3D`（Melee Hitbox），`monitoring` 默认关闭
- [ ] 命中区几何尺寸与 `melee_reach`/宽高一致，朝玩家前方（基于相机/角色朝向）
- [ ] 仅在挥砍活跃帧开启 `monitoring`，动画其余时间关闭
- [ ] 收集到重叠怪物后用 `Set` 去重，单次挥砍对同一敌人只调用一次 `damage(melee_damage)`
- [ ] 命中后怪物按 `melee_damage=40` 扣血，并自动触发 Hit Flash 泛红
- [ ] 挥砍未命中任何物体时安静结束，无报错
- [ ] 与现有 `Weapon`/弹体/弹药体系无耦合、无副作用

## 评论
