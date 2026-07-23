# ADR-002: 使用 City Builder 项目的 GridMap 城市地图替换原有浮岛关卡

## 状态

已接受

## 背景

当前 FPS 项目的关卡是由 platform、wall、grass 等独立场景手动摆放的浮岛平台。
City Builder 项目（`G:\work\Starter-Kit-City-Builder`）拥有一套基于 GridMap 的城市地图系统，
包含 15 种低多边形结构（道路、建筑、草地等），与 FPS 项目共享同一套 colormap 美术风格。
希望将 City Builder 的城市地图引入 FPS 项目作为游戏关卡。

## 决策

通过 JSON 数据桥接 + EditorScript 转换管线，将 City Builder 的地图布局转换为 FPS 项目可直接使用的 GridMap 场景。

具体方案：
- City Builder 侧新增"导出 JSON"功能，输出地图布局（坐标、朝向、结构索引）
- FPS 侧的 EditorScript（`tools/convert_map.gd`）读取 JSON，构建含 trimesh 碰撞的 MeshLibrary，生成 `.tscn` 场景
- MeshLibrary 独立存储为 `resources/city-mesh-library.tres`，多地图共享
- GridMap 的 `cell_size = Vector3(4, 4, 4)`（4 倍放大，使建筑/街道比例适合 FPS 视角）
- 城市地图直接替换原有浮岛关卡
- 地图边界使用隐形墙
- 模型文件（15 个 `.glb` + `colormap.png`）手动复制到 `models/city/`

## 理由

- **美术风格一致**：两个项目共享 colormap 贴图和低多边形风格，视觉无缝衔接。
- **零耦合**：JSON 作为中间格式，FPS 项目不依赖 City Builder 的任何脚本或自定义资源类。
- **可复用管线**：转换脚本支持多次运行，City Builder 更新地图后重新导出即可。
- **精确碰撞**：trimesh 碰撞让玩家能走上建筑、利用掩体，丰富 FPS 玩法。
- **比例自然**：4 倍放大后街道宽 4m、建筑高 4-8m，FPS 视角下接近真实城市比例。

## 替代方案

- **直接加载 map.res**：需要复制 DataMap/DataStructure 脚本到 FPS 项目，引入不必要的耦合。被否决。
- **只复用 .glb 模型手动摆放**：失去 GridMap 的模块化优势，每次改地图都要手动重摆。被否决。
- **把 GridMap 系统搬到 FPS 项目中（含建造逻辑）**：过度引入 City Builder 的游戏逻辑。被否决。
- **节点 scale 放大而非改 cell_size**：scale 会影响碰撞/物理计算，cell_size 更干净。被否决。
- **保留浮岛关卡共存**：增加维护负担，当前阶段只需一张地图。被否决。

## 实现审查（2026-07-23）

对已落地的实现进行核查，发现两处偏差：

### 偏差 1：trimesh 碰撞缺失

`tools/convert_map.gd` 中有 `mesh.create_trimesh_shape()` 代码，但生成的 `city-mesh-library.tres` 和 `city-level.tscn` 中所有 15 个 item 的 `shapes = []`，碰撞体未实际写入。

**修复决策：** 调试并修复 `set_item_shapes` 的调用逻辑，确保 trimesh 碰撞体正确序列化到 MeshLibrary。这是 ADR 核心价值（"精确碰撞"），不可省略。

### 偏差 2：JSON 桥接未实现

`convert_map.gd` 直接加载 City Builder 的 `map.res`（类型化为 `DataMap`），未走 JSON 中间格式。这违反了零耦合目标——FPS 项目隐式依赖了 City Builder 的自定义资源类。

**修复决策：**
- City Builder 侧实现 JSON 导出功能，输出地图布局到文件
- FPS 侧的 `convert_map.gd` 改为读取 JSON 文件（`resources/city-map-data.json`），解析坐标、朝向、结构索引
- 移除对 `DataMap`/`DataStructure` 的依赖，FPS 项目不再加载 City Builder 的任何资源
- JSON 文件存放于 FPS 项目内（`resources/city-map-data.json`），项目完全自包含
