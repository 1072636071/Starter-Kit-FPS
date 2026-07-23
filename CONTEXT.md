# CONTEXT.md — 领域词汇表

## 射击系统

| 术语 | 定义 |
|------|------|
| **Projectile（弹体）** | 从枪口发射的实体对象，承载真实伤害判定。使用 Area3D 检测碰撞，命中第一个物体后造成伤害并销毁。形态为发光拉伸胶囊体（CapsuleMesh + emission 材质），飞行速度 30-50 m/s。玩家和敌人均使用弹体。 |
| **Impact（命中特效）** | 弹体碰撞点处播放的 AnimatedSprite3D 动画，由 `impact.tscn` 定义，播放完毕后自动销毁。 |
| **Weapon（武器）** | `Weapon` 资源类，定义武器的模型、属性（冷却、伤害、散射、弹数、击退等）和弹体配置（颜色、大小、速度）。 |

## 弹体属性

| 术语 | 定义 |
|------|------|
| **projectile_color** | 弹体发光颜色（Color），在武器资源中配置。 |
| **projectile_size** | 弹体大小（Vector3 scale），在武器资源中配置。 |
| **projectile_speed** | 弹体飞行速度（m/s），推荐范围 30-50。 |
| **projectile_damage** | 弹体命中时造成的伤害值，继承自武器的 damage 属性。 |
| **max_distance** | 弹体最大飞行距离，超出后自动销毁。 |

## 地图系统

| 术语 | 定义 |
|------|------|
| **GridMap（网格地图）** | Godot 的瓦片式 3D 地图节点，通过 MeshLibrary 定义可放置的网格项，按 cell_size 划分空间。当前项目 cell_size = Vector3(4, 4, 4)，即每格 4 米。 |
| **MeshLibrary（网格库）** | GridMap 的资源依赖，定义每个网格项的 Mesh、碰撞形状和导航网格。当前项目以独立 `.tres` 文件存储（`resources/city-mesh-library.tres`），多地图共享。**重要规格：** 模型原始尺寸为 1 单位，必须通过 `set_item_mesh_transform(i, Transform3D().scaled(CELL_SIZE))` 放大至与 cell_size 匹配，否则瓦片间会产生缝隙。 |
| **Map JSON（地图数据）** | City Builder 项目导出的 JSON 格式地图布局文件，包含每个格子的坐标（Vector2i）、朝向（orientation）和结构索引（structure index）。是跨项目数据桥接的中间格式。 |
| **转换管线（Conversion Pipeline）** | 将 Map JSON 转换为 FPS 项目可用 `.tscn` 场景的 EditorScript 工具链。流程：City Builder 导出 JSON → FPS EditorScript 读取 → 构建 MeshLibrary（含 trimesh 碰撞）→ 生成 GridMap 场景。 |
| **Structure（结构）** | City Builder 中可放置的地图元素，包括道路（直道、弯道、十字路口、分岔）、人行道、建筑（4种小建筑+车库）、草地（3种）。共 15 种，对应 15 个 `.glb` 模型。 |
