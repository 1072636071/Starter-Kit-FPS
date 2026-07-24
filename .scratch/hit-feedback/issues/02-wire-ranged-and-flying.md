Status: ready-for-agent
Blocked by: T1 — 命中变色核心模块 hit_feedback.gd

# T2 — 接入远程怪物与飞行敌人

## 构建内容

在 `monster_ranged.gd` 与 `enemy.gd` 的 `damage()` 各加一行 `HitFeedback.flash(self)`，使三种怪物统一拥有命中变色。重点验证飞行敌人 `enemy`（Node3D、无 `Model` 子节点）走 `flash()` 的回退路径，对其自身 `MeshInstance3D` 正常染色。

## 验收标准

- [ ] `monster_ranged.gd` 的 `damage()` 调用 `HitFeedback.flash(self)`，远程怪物受击泛红
- [ ] `enemy.gd` 的 `damage()` 调用 `HitFeedback.flash(self)`，飞行敌人受击泛红（验证无 `Model` 节点的回退路径）
- [ ] 三种怪物受击反馈外观一致（同为红色、~0.12s 淡出）
- [ ] 现有音效与各怪物既有行为不受影响

## 评论
