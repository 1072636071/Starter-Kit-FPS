Status: ready-for-agent
Blocked by: 03

# T4 — 玩家中心局部跟随 + 屏外威胁指示

## 问题陈述

地图已扩展且未来尺寸不确定、可能继续增长。当前小地图硬编码 `WORLD_HALF=80`（覆盖 ±80 / 160×160m），俯视相机固定在原点上方不动。地图超出 ±80 后：地形不在正交视锥内被裁掉、实体 blip 被圆形裁剪跳过——小地图**无法完整展示当前地图**。

## 解决方案

将小地图从"全图固定俯视"改为**玩家中心局部跟随（player-centered follow）**：

- 俯视相机每帧跟随玩家 x/z 位置（不再固定原点），仍北朝上、仍正交投影、仍 80m 半覆盖半径（view radius）
- 图内敌人用现有圆点绘制（不变）
- 图外敌人（距玩家 > view radius）不在图内画，改用**屏外威胁指示**——圆形边缘画方向箭头按敌种着色，使"随时知道敌人在哪"的核心价值继续成立

## 用户故事

1. 作为玩家，当我在一个很大的地图中移动时，小地图始终以我为中心显示周围地形，以便我导航身边环境而不受地图总尺寸影响
2. 作为玩家，我希望看到所有在我周围的敌人（距我 ≤ 80m），用红色圆点表示近战敌人、黄色圆点表示远程敌人，以便快速判断威胁类型
3. 作为玩家，超出我身边 80m 的敌人不在图内出现，但以小三角形箭头出现在圆形边缘对应方向，以便我知道"那个方向有威胁"并提前应对
4. 作为玩家，屏外威胁的箭头按敌种着色（近战=红、远程=黄），与图内圆点一致，以便我一目了然"那边是近战还是远程"
5. 作为玩家，小地图仍保持北朝上——地面永远不转、我只看自己的三角形箭头朝向就知道面对的是哪个方向，以便稳定阅读、不眩晕
6. 作为玩家，小地图的覆盖范围（80m）在地图未来进一步扩大时不需要任何改动，以便游戏内容扩展时小地图零成本适配
7. 作为玩家，小地图在右上角的圆形 UI 位置保持不变，以免打乱我已经习惯的 HUD 布局

## 实现决策

- **架构反转**：全图固定 → 玩家中心跟随，见 ADR 026。ADR 007「缩放」行的全图覆盖被取代。
- **View Radius**：可配置初值 80m（`view_radius = 80.0`），取代硬编码 `WORLD_HALF`。与地图总尺寸解耦。
- **相机跟随**：`MinimapCamera` 每帧 `global_position.x/z = player.global_position.x/z`（y 仍 80m 高处朝下），由 `minimap.gd` 驱动。
- **投影变更**：`_world_to_pixel(world_x, world_z)` 从绝对映射 `(world ± 80)/160` 改为相对玩家映射 `(world - player + view_radius) / (2 × view_radius)`。
- **屏外箭头**：每个图外敌人（距玩家 > view_radius）在圆形边缘绘制一个小三角形箭头，指离圆心方向，按脚本路径区分着色（`MELEE_COLOR` / `RANGED_COLOR`，与现有 blip 常量一致）。不合并分组、不显示距离数字、不显示数量。
- **图内圆点不变**：`pixel.distance_to(center) ≤ clip_r` 的敌人仍画圆点，逻辑不变。
- **朝向不变**：仍 north-up（北朝上），相机朝向固定、玩家箭头随 yaw 旋转。无迁移成本。
- **v1 不做 zoom**：无滚轮缩放交互，view radius 固定 80m。留待未来收集手感数据后评估。
- **不动其他系统**：怪物 mesh layer（layer 3）、武器 viewmodel layer（layer 2）、主相机 cull_mask、SubViewport + 圆形遮罩 shader + HUD 结构均不修改。

## 测试决策

- **好测试标准**：验证玩家中心映射正确性（player 在圆心、周围 enemy 位置与相对坐标一致），验证屏外箭头在正确方向出现且颜色正确，验证图内圆点行为不退化。
- **测试模块**：`tests/test_minimap_t3`（投影映射——从绝对坐标测试转为相对坐标测试），新增 `tests/test_minimap_t4`（屏外箭头 + 图内/图外混合场景）。
- **测试先例**：`tests/test_minimap_t3.gd` 已有投影映射测试（验证 `_world_to_pixel` 在 ±80 四角的输出），本次在其基础上改为相对玩家映射测试；`tests/test_minimap_t1.gd` 的相机配置测试（orthogonal、size=160、cull_mask=1）仍应通过。

## 超出范围

- 滚轮缩放交互（v1 不做）
- 屏外指示显示距离或数量（v1 不做）
- heading-up 朝向方案
- 全图缩略图 + 局部详情混合方案
- 修改怪物/武器等非 minimap 子系统

## 补充说明

- 设计来自 grill-with-docs 会话（2026-07-26），完整决策过程见 [ADR 026](../../docs/adr/026-minimap-player-centered-follow.md)。
- 术语定义见 CONTEXT.md「小地图系统（Minimap）」下的 View Radius / Minimap Follow / Off-Map Enemy / Off-Screen Indicator。
- 单一 seam：`scripts/minimap.gd`，无新建模块或节点。
