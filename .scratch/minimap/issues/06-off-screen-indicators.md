Status: resolved
Blocked by: 05

# T6 — 屏外威胁指示（圆形边缘方向箭头）

## 构建内容

在 05 的玩家中心跟随基础上，超出 80m（view_radius）的敌人不再沉默消失，而是在小地图圆形边缘绘制小三角形箭头，指向敌人所在方向。箭头按敌种着色（近战=红、远程=黄）。完成"随时知道敌人在哪"的最后一块拼图。

## 验收标准

- [ ] 每个图外敌人（距玩家 > view_radius）在圆形边缘对应方向画三角形箭头
- [ ] 近战敌人箭头=红色、远程敌人箭头=黄色（与图内圆点着色一致）
- [ ] 箭头指向离圆心方向（即"敌人在那边"）
- [ ] 多个图外敌人同一方向时箭头自然叠加（无需合并/计数逻辑）
- [ ] 图内敌人（≤ view_radius）仍画圆点，行为不变
- [ ] 无图外敌人时无多余箭头（零敌人 = 零箭头）
- [ ] 现有 `test_minimap_t3` 测试仍通过（05 的投影不变）
- [ ] 新增 `test_minimap_t4`：验证屏外箭头方向正确、颜色正确、图内/图外混合场景

## 评论

- 设计见 [ADR 026](../../docs/adr/026-minimap-player-centered-follow.md) Q5 与 [spec 04](04-player-centered-follow.md)。
- 箭头绘制复用现有 `_draw_arrow` 方法或新写小三角，放在圆形边缘 `radius - ENEMY_RADIUS` 处。
- v1 不合并分组、不显示距离数字、不显示数量——只给方向 + 颜色。

### 实现摘要 (2026-07-26)

**改动文件：**
- `scripts/minimap.gd` — 仅改动 `_draw()` 敌人循环 + 新增 `_draw_edge_indicator()` 方法

**关键变更：**
1. `_draw()` 敌人循环中：`pixel.distance_to(center) > clip_r` 不再沉默 `continue`，改为计算方向角 `atan2(pixel.y - center.y, pixel.x - center.x)`，在圆形边缘 `radius - ENEMY_RADIUS - 1` 处调用 `_draw_edge_indicator(edge_pos, angle, color)` 画方向箭头
2. 新增 `_draw_edge_indicator(edge_pos: Vector2, angle: float, color: Color)` — 用 `draw_colored_polygon` 绘制 6px 外接半径的小三角形箭头，尖端指向外侧（敌人在那边），颜色按敌种着色（melee=红 / ranged=黄）
3. 未修改 `_world_to_pixel`、玩家箭头、边框、计数、camera follow 等 T5 逻辑

**测试结果：**
- `test_minimap_t1` — PASS（16 项全部通过）
- `test_minimap_t3` — PASS（26 项全部通过）
