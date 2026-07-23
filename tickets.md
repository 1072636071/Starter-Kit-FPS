# 工单：城市地图管线修复

修复 ADR-002 实现审查中发现的两处偏差：trimesh 碰撞缺失和 JSON 桥接未实现。来源：`docs/adr/002-city-map-from-gridmap.md`「实现审查」章节。

按**前沿**推进：任何阻塞者全部完成的工单。两个工单互相独立，可并行。

## 修复 MeshLibrary trimesh 碰撞生成

**构建内容：** 重新运行转换管线后，MeshLibrary 中每个网格项都包含 trimesh 碰撞体，玩家能在建筑和路面上行走、利用掩体。

**阻塞于：** 无——可立即开始。

- [x] 转换脚本生成的 MeshLibrary 中，15 个网格项的 shapes 均包含 ConcavePolygonShape3D
- [x] 重新运行转换管线后，city-level.tscn 中 GridMap 的 MeshLibrary 包含碰撞体
- [ ] 游戏运行时，玩家角色能站在建筑/路面上，不穿过地面

## 转换管线改用 JSON 数据源

**构建内容：** 转换管线从项目内的 JSON 文件读取地图布局，FPS 项目不再依赖 City Builder 的任何脚本或自定义资源类，实现真正的零耦合。

**阻塞于：** 无——可立即开始。

- [x] City Builder 侧有导出功能，将地图布局输出为 JSON 文件（含坐标、朝向、结构索引）——已集成到 city-builder/ 子项目
- [x] FPS 侧转换脚本从 `resources/city-map-data.json` 读取数据，不再引用 DataMap/DataStructure
- [x] 删除或不加载 City Builder 脚本后，转换管线仍能正常运行并生成正确的 GridMap 场景
- [x] JSON 格式与 CONTEXT.md 中「Map JSON」术语定义一致
