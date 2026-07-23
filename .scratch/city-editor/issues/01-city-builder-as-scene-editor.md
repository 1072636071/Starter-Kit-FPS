# 将 City Builder 集成为内置场景编辑器

**标签：** `ready-for-human`

## 背景

City Builder 已作为独立子项目存放在 `city-builder/` 目录，具备完整的城市建造玩法和 JSON 导出功能（F4 键导出地图布局到 `map-data.json`）。FPS 项目通过转换管线（`tools/convert_map.gd`）读取 JSON 生成 GridMap 关卡。

当前两个项目是分离的：City Builder 编辑地图 → 导出 JSON → FPS 转换管线生成场景。

## 目标

将 City Builder 集成为 FPS 项目的一个游戏模式/内置场景编辑器，实现：

- 玩家可在 FPS 模式和城市编辑模式之间切换
- 编辑后的地图直接更新 FPS 关卡，无需手动导出/转换

## 需要决策的架构问题

- **模式切换机制**：场景切换 vs 节点显隐 vs 独立 SceneTree
- **GridMap/MeshLibrary 共享**：编辑器和 FPS 关卡共用同一份 MeshLibrary（`resources/city-mesh-library.tres`）还是各自维护
- **输入映射隔离**：FPS 的 WASD/鼠标射击 与 City Builder 的 WASD/鼠标放置 存在冲突，需要输入上下文切换
- **相机控制**：FPS 第一人称相机 vs City Builder 俯视/等距相机
- **UI 切换**：FPS HUD（准星、血量）vs City Builder UI（结构选择、资金显示）

## 当前状态

- `city-builder/` 子项目可直接在 Godot 中独立打开运行
- JSON 导出功能已实现（F4），输出格式与 FPS 转换管线兼容
- FPS 侧转换管线已改为从 `resources/city-map-data.json` 读取，零耦合

## 优先级

低。优先保证 FPS 射击游戏的核心开发。此工单仅记录后续方向，待核心玩法稳定后再规划实施。
