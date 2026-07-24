# 02 - 玩家 Auto-Step（自动登高）

Status: resolved
Type: task

## 构建内容

玩家走到 ≤0.3m 的台阶前无需跳跃，自动登高到台阶顶。从此走 [platform.tscn](../../../objects/platform.tscn) 的 0.2m 段或人行道边缘时不再卡顿；遇到 ≥0.3m 高差仍视为墙，不抬升。

参见 [ADR 003](../../../docs/adr/003-step-and-monster-navigation.md) 与 [CONTEXT.md "Player Auto-Step"](../../../CONTEXT.md)。

## 验收标准

- [ ] 玩家在水平移动中检测前方 step_height 范围内的可登高面（前向 ShapeCast3D 或 RayCast3D）
- [ ] 若前方高差 < step_height 且头顶有净空，自动抬升角色到该高度
- [ ] 若前方高差 ≥ step_height，不抬升（保留须跳跃的行为）
- [ ] 不影响跳跃本身（二段跳、is_on_floor 逻辑保持原状）
- [ ] 走过 platform.tscn 的 0.2m 段时不卡顿，无需按空格
- [ ] 走向 wall_low.tscn 时不会被自动抬上去（仍须跳）

## 阻塞于

- 01 - 建立 step_height 共享常量
