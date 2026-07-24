Status: ready-for-agent
Blocked by: 无

# T1 — 命中变色核心模块 hit_feedback.gd

## 构建内容

新建独立的静态类脚本 `scripts/hit_feedback.gd`，对外暴露 `HitFeedback.flash(target)`。怪物受击时把其可视模型临时染红、~0.12s 内淡出回原色，让玩家清晰感知"打中了"。该模块兼容两种模型结构（有 `Model` 子节点 / 无 `Model` 节点），并对 GLB 共享材质做去共享处理防止串色。随即在 `monster_melee.gd` 的 `damage()` 接入一行调用，作为端到端验证。

## 验收标准

- [ ] `scripts/hit_feedback.gd` 新增，含 `static func flash(target: Node3D) -> void`
- [ ] 定位可视模型：优先 `target.get_node_or_null("Model")`，否则回退到 `target` 自身（遍历其下 `MeshInstance3D`）
- [ ] 遍历每个 `MeshInstance3D` 的 surface 材质，先 `.duplicate()` 保证实例独有，再记录原 `albedo_color`
- [ ] 染红并以 `Tween` 在 ~0.12s 内从红色淡出回原色；连续快速受击可重新触发（不卡在红色）
- [ ] GLB 共享材质场景下，同类其他怪物不会被误染
- [ ] 染色颜色与时长以模块顶部常量定义，便于调参
- [ ] `monster_melee.gd` 的 `damage()` 在既有音效之后调用 `HitFeedback.flash(self)`，实战可见近战怪物受击泛红
- [ ] 既有的微弱 `scale` 形变与音效 `enemy_hurt.ogg` 保留不动

## 评论
