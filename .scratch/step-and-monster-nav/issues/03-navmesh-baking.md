# 03 - NavMesh 基础设施与运行时烘焙

Status: resolved
Type: task

## 构建内容

场景启动时自动从 GridMap 烘焙 navmesh，包裹在 `NavigationRegion3D` 中，`agent_max_climb` 设为 `step_height = 0.3`。烘焙结果可在调试视图中可视化。完成后地图拥有连通的导航网格基础设施，可供后续工单挂载 NavigationAgent。

参见 [ADR 003](../../../docs/adr/003-step-and-monster-navigation.md) 与 [CONTEXT.md "角色导航 / NavMesh"](../../../CONTEXT.md)。

## 验收标准

- [ ] 主场景中存在 `NavigationRegion3D` 节点，包裹现有 GridMap
- [ ] 场景加载时调用 `NavigationServer3D` 自动烘焙 navmesh，源几何来自 GridMap 碰撞
- [ ] 烘焙参数 `agent_max_climb = step_height`（引用工单 01 的常量）
- [ ] 启用导航调试可视化时可见 navmesh 覆盖可行走区域
- [ ] navmesh 在 ≤0.3m 高差处表现为连通区域；≥0.3m 高差处表现为断开
- [ ] 烘焙开销可接受（启动多几百 ms）
- [ ] 不破坏现有玩家/怪物行为（怪物此时还不使用 navmesh，行为不变）

## 阻塞于

- 01 - 建立 step_height 共享常量
