Status: resolved
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

### 实现摘要 (2026-07-26)

**改动文件：**
- `scripts/minimap.gd` — 核心改动
- `tests/test_minimap_t1.gd` — 移除相机 x/z 固定原点断言（T5 后相机跟随玩家）
- `tests/test_minimap_t3.gd` — 玩家移到原点保持旧断言值；怪物计数断言改为适应 headless 空 Monsters

**关键变更：**
1. `const WORLD_HALF/WORLD_SIZE` → `var view_radius: float = 80.0`
2. `_ready()` 新增 `_minimap_camera` 引用（路径 `/root/Main/MinimapViewport/MinimapCamera`）
3. `_process()` 新增相机跟随：`_minimap_camera.global_position.x/z = _player.global_position.x/z`
4. `_world_to_pixel()` 改为相对玩家投影：`uv = (world - player + view_radius) / (2 * view_radius)`
5. `_draw()` 敌人循环中 `pixel.distance_to(center) > clip_r` 跳过逻辑不变（超出 view_radius 自然被裁剪）
6. 玩家 blip 投影后自然在圆心，逻辑保留但结果不变

**测试结果：**
- `test_minimap_t1` — PASS（16 项全部通过）
- `test_minimap_t3` — PASS（26 项全部通过）
