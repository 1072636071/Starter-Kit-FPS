Status: resolved
Blocked by: 02

# T3 — 2D blip 叠加（scripts/minimap.gd）

## 构建内容

新建 `scripts/minimap.gd`，挂在 T2 的 `Minimap` 节点下，负责每帧把玩家与敌人**世界 (x,z) 线性投影**为小地图 UV（因全图固定正交相机，无需透视除法；见 CONTEXT「Minimap Projection」），并在圆形 `TextureRect` 之上用 2D `Control` 绘制：

- **玩家朝向箭头**：随玩家 yaw 旋转指示 facing（北朝上方案下相机不转，箭头表示朝向；见 CONTEXT「Player Blip」）
- **敌人圆点**：两种敌人都显示、不按视线/距离过滤，用形状或深浅区分 `monster_melee` 与 `monster_ranged`（见 CONTEXT「Enemy Blip」）

blip 为 2D 叠加（非 3D 图层标记），避免泄漏进真实 3D 视野（见 ADR 007「图层过滤」）。

设计来源：[ADR 007](../../docs/adr/007-minimap-subviewport-camera.md) 及 CONTEXT.md「小地图系统（Minimap）」。

## 验收标准

- [ ] 玩家箭头随玩家移动/转向实时更新位置与朝向
- [ ] 两种敌人各显示圆点，且近战/远程可区分（形状或深浅）
- [ ] 投影为线性映射，实体位置与小地图地理一致（北朝上，无旋转）
- [ ] 全部实体显示、不按视线/距离过滤
- [ ] 不改动主/武器相机 `cull_mask`、不改动 `weapon.gd`、不改动怪物场景

## 评论

- 脚本需取得玩家与敌人节点引用（玩家经 `../Player`；敌人经 `Monsters` 下实例或对应 group），每帧更新 blip 位置。
- 敌人引用建议基于现有 `monster_melee` / `monster_ranged` 场景实例，不引入新节点。

## 答案

实现完成于 `scripts/minimap.gd` + `scenes/main.tscn`（HUD/Minimap/Blips 节点）。

**结构：**
- `HUD/Minimap/Blips`（Control）：挂 `scripts/minimap.gd`，每帧 `queue_redraw()` 重绘。应用独立的径向 alpha 裁剪 shader（`COLOR.a *= mask`，不覆盖 rgb）使 blip 与底图圆边对齐。
- 玩家经 `get_tree().get_first_node_in_group("player")` 查找；怪物优先从 `/root/Main/Monsters` 查找，兜底全树扫描按脚本路径过滤 melee/ranged。
- 投影：`_world_to_pixel(x, z) = ((x+80)/160 * size.x, (z+80)/160 * size.y)`，线性映射，北朝上、东朝右。
- 玩家箭头：`horizontal_forward(player)` 取水平前向（-basis.z, y 清零归一化），`arrow_yaw_from_forward(fwd)` = `atan2(fwd.x, -fwd.z)` 换算旋转，`_draw_arrow` 用 `Vector2.rotated()` 绘制三角形。
- 敌人圆点：melee=红 `(1, 0.32, 0.28)`、ranged=黄 `(1, 0.78, 0.25)`，按脚本资源路径区分。两种敌人全显示，不按视线/距离过滤。

**测试：** `tests/test_minimap_t3.gd` 验证 Blips 节点结构、shader 裁剪逻辑、_player/_monsters 绑定、_world_to_pixel 四方向投影、arrow_yaw_from_forward 四朝向、enemy_color 区分、horizontal_forward、cull_mask 未改。全部 PASS。
