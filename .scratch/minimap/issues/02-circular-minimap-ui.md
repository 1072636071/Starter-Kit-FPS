Status: resolved
Blocked by: 01

# T2 — 圆形小地图 UI 容器（HUD）

## 构建内容

在 `HUD`（`CanvasLayer`）下新建一个 `Minimap` `Control` 容器，定位在**右上角**（避开左下血条、右下弹药列表）。容器内放一个圆形 `TextureRect`，其 `texture` 绑定 T1 产出的 `ViewportTexture`（俯视地形渲染）；并用一个 `ShaderMaterial`（径向 alpha）把方形渲染裁成**圆形**，隐藏俯视渲染四角的畸变（见 CONTEXT「Minimap Shape & Position」）。

此工单只搭建 UI 容器与底图，**不含**玩家/敌人 blip（blip 由 T3 叠加）。

设计来源：[ADR 007](../../docs/adr/007-minimap-subviewport-camera.md) 及 CONTEXT.md「小地图系统（Minimap）」。

## 验收标准

- [ ] `HUD` 下新增 `Minimap` `Control` 节点，锚定右上角布局
- [ ] `Minimap` 内 `TextureRect.texture` = T1 的 `ViewportTexture`
- [ ] 圆形 `ShaderMaterial` 遮罩生效，方形渲染四角被裁成圆
- [ ] 运行时右上角可见俯视地形的圆形小地图
- [ ] 不改动主/武器相机 `cull_mask`、不改动 `weapon.gd`、不改动怪物场景

## 评论

- 圆形遮罩 shader 为径向 alpha：圆心不透明、边缘渐隐至透明，把方视口"抠"成圆。
- blip 叠加层（玩家箭头 + 敌人圆点）由 T3 加在 `Minimap` 容器之上。

## 答案

实现完成于 `scenes/main.tscn`（HUD/Minimap 节点 + sub_resource）。

**结构：**
- `HUD/Minimap`（Control）：锚定右上角（anchor_left=1, anchor_top=0），180×180px，距屏边 20px。
- `HUD/Minimap/Background`（TextureRect）：`texture = ViewportTexture_minimap`（绑定 T1 的 MinimapViewport），`material = ShaderMaterial_minimap_circle`（径向 alpha shader：`smoothstep(0.5, 0.46, dist)` 软过渡隐藏四角畸变）。

**测试：** `tests/test_minimap_t2.gd` 验证 Minimap Control 锚点、Background TextureRect 存在、texture 为 ViewportTexture、material 为 ShaderMaterial、shader 为 canvas_item 类型且含 distance/smoothstep/0.5 径向 alpha 逻辑、主/武器相机 cull_mask 未改。全部 PASS。
