Status: ready-for-agent
Blocked by: 03

# T5 — 玩家中心跟随（相机跟随 + 相对投影 + view_radius）

## 构建内容

小地图从全图固定俯视改为玩家中心局部跟随。玩家移动时俯视相机同步跟随，小地图始终以玩家为圆心显示周围 80m 地形与敌人。图内敌人画圆点（红色近战/黄色远程，与现有一致）。图外敌人暂不处理（见 06）。

## 验收标准

- [ ] 玩家移动时，小地图地形跟随平移，玩家始终在圆心
- [ ] 玩家周围 ≤ 80m 的敌人以圆点显示（近战=红、远程=黄），位置相对玩家正确
- [ ] 玩家周围 > 80m 的敌人不在图内出现（v1 无指示，06 补）
- [ ] 玩家朝向箭头仍在圆心随 yaw 旋转（north-up 不变）
- [ ] 圆形边框、敌人计数文字功能不退化
- [ ] `view_radius` 为可配置变量（非硬编码 WORLD_HALF 常量），初值 80
- [ ] 现有测试 `test_minimap_t1`（相机配置）仍通过
- [ ] `test_minimap_t3`（投影映射）更新为相对玩家测试并通过
- [ ] 不改动怪物 mesh layer（layer 3）、武器 viewmodel layer（layer 2）、主相机 cull_mask

## 评论

- 设计见 [ADR 026](../../docs/adr/026-minimap-player-centered-follow.md) 与 [spec 04](04-player-centered-follow.md)。
- 投影从 `(world ± 80)/160` 改为 `(world - player + view_radius) / (2 × view_radius)`。
- 相机在 `minimap.gd._process()` 中直接拿 `/root/Main/MinimapViewport/MinimapCamera` 设 `global_position.x/z`。
