# 04 - 近战怪物接入 NavigationAgent3D

Status: resolved
Type: task

## 构建内容

`monster_melee` 不再朝玩家位置直冲（抹掉 Y 分量），改用 `NavigationAgent3D` 进行路径规划，朝下一路径点施加水平速度。能绕过墙、跨过 ≤0.3m 台阶追击玩家，不再卡在台阶或墙角前。

参见 [ADR 003](../../../docs/adr/003-step-and-monster-navigation.md) 与 [CONTEXT.md "NavigationAgent3D"](../../../CONTEXT.md)。

## 验收标准

- [ ] `monster_melee.tscn` 包含 `NavigationAgent3D` 子节点
- [ ] `_physics_process` 中通过 `NavigationAgent3D.get_next_path_position()` 获取下一路径点
- [ ] 朝下一路径点（而非玩家位置）施加水平速度，`velocity.y = -gravity`，`move_and_slide()`
- [ ] 怪物能跨过 platform.tscn 的 0.2m 段追玩家，不卡顿
- [ ] 怪物遇到 wall_low.tscn 时绕路，而非卡死贴墙
- [ ] 攻击距离/追击范围参数（`attack_range = 2.0`，`chase_range = 25.0`，`move_speed = 3.5`）行为不变
- [ ] 跳跃/重力处理保持原状（怪物仍受重力，落地清零）

## 阻塞于

- 03 - NavMesh 基础设施与运行时烘焙
