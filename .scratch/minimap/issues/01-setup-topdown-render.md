Status: resolved
Blocked by: 无

# T1 — 俯视渲染基建（main.tscn）

## 构建内容

在 `main.tscn` 的 `Main` 节点下新增一台**正交俯视 `Camera3D`** + 一台 `SubViewport`，把世界从高空垂直朝下渲染进 `ViewportTexture`，作为后续小地图 UI 的纹理来源。相机 `cull_mask = layer 1`（仅世界/地形），固定位于世界中心正上方、半高约 80m，覆盖整个 160×160 世界（边界 ±80），相机本身不随玩家移动（全图固定，见 ADR 007「缩放」）。

同时把 `monster_melee.tscn` / `monster_ranged.tscn` 中怪物的**真实 3D mesh 节点**从默认 **layer 1 挪到 layer 3**，使俯视相机（cull_mask = layer 1）不渲染其顶视 blob；主相机（渲染 layers 3–20）仍看得见敌人，真实 FPS 视野不受影响（见 CONTEXT「Minimap Enemy Layer」）。

设计来源：[ADR 007](../../docs/adr/007-minimap-subviewport-camera.md) 及 CONTEXT.md「小地图系统（Minimap）」。

## 验收标准

- [ ] `main.tscn` 含 `SubViewport` + 正交俯视 `Camera3D`（`cull_mask = layer 1`，覆盖 ±80，固定位于世界中心正上方）
- [ ] 可取得该 `SubViewport` 的 `ViewportTexture`（供 T2 绑定）
- [ ] `monster_melee` / `monster_ranged` 的真实 mesh 节点 `layers` 改为 layer 3
- [ ] 主游戏视野中敌人外观无任何变化（仅小地图渲染不再含敌人 blob）
- [ ] 不改动主相机（`Camera`）与武器相机（`CameraItem`）的 `cull_mask`、不改动 `weapon.gd`

## 评论

- 武器 viewmodel 在 layer 2，俯视相机 cull_mask 不含 layer 2，天然不进图，无需额外处理。
- `SubViewport` 渲染尺寸（如 256×256）由实现决定，圆形遮罩在 T2 处理。

## 答案

实现完成于 `scenes/main.tscn` + `objects/monster_melee.gd` / `monster_ranged.gd`。

**关键决策：**
- `MinimapCamera.size = 160.0`（Godot 4 中 `size` 为视口全高，非半高 → 半高 80m → 覆盖 ±80 世界）。原 spec 文字"正交 size = 80m（半高）"被误解为 Godot 参数，实际 Godot 4 的 `Camera3D.size` 是全高，故参数值为 160。
- 怪物 mesh layers 改在 `monster_melee.gd` / `monster_ranged.gd` 的 `_ready()` 运行时设置（`model.find_children("*", "MeshInstance3D", true, false)` → `child.layers = 4`），而非 `.tscn` editable_instance。原因：.glb 实例内 mesh 节点路径不稳定（存在 `character-a` 中间节点），editable_instance 路径易失效；运行时按类型遍历更健壮。详见 CONTEXT.md「Minimap Enemy Layer」更新。

**测试：** `tests/test_minimap_t1.gd` 验证 SubViewport/Camera3D 配置、cull_mask、ortho size=160、相机朝向、ViewportTexture 可获取、怪物 mesh layers=4、主/武器相机 cull_mask 未改。全部 PASS。
