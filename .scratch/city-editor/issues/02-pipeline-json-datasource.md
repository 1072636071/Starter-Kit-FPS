Status: ready-for-agent
Blocked by: 无

# 转换管线改用 JSON 数据源

## 构建内容

转换管线从项目内的 JSON 文件读取地图布局，FPS 项目不再依赖 City Builder 的任何脚本或自定义资源类，实现真正的零耦合。

## 验收标准

- [x] City Builder 侧有导出功能，将地图布局输出为 JSON 文件（含坐标、朝向、结构索引）——已集成到 city-builder/ 子项目
- [x] FPS 侧转换脚本从 `resources/city-map-data.json` 读取数据，不再引用 DataMap/DataStructure
- [x] 删除或不加载 City Builder 脚本后，转换管线仍能正常运行并生成正确的 GridMap 场景
- [x] JSON 格式与 CONTEXT.md 中「Map JSON」术语定义一致

## 评论
