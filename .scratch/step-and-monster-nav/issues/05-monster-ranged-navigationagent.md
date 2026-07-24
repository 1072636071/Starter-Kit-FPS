# 05 - 远程怪物接入 NavigationAgent3D

Status: resolved
Type: task

## 构建内容

`monster_ranged` 同样的导航重构——通过 NavigationAgent3D 寻路，能绕墙、跨台阶，在 preferred_distance 范围内 strafe 时也走通路径。不再因地形卡死。

参见 [ADR 003](../../../docs/adr/003-step-and-monster-navigation.md) 与 [CONTEXT.md "NavigationAgent3D"](../../../CONTEXT.md)。

## 验收标准

- [ ] `monster_ranged.tscn` 包含 `NavigationAgent3D` 子节点
- [ ] `_physics_process` 中通过 NavigationAgent3D 获取下一路径点
- [ ] 后退（`distance < too_close_distance`）/靠近（`distance > preferred_distance + 2`）/strafe 三种行为都基于路径点而非直线玩家方向
- [ ] 怪物能跨过 ≤0.3m 台阶
- [ ] 怪物遇到 ≥0.3m 障碍时绕路
- [ ] `move_speed`、`preferred_distance`、`too_close_distance` 参数行为不变
- [ ] 重力/落地处理保持原状

## 阻塞于

- 03 - NavMesh 基础设施与运行时烘焙
