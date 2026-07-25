Status: completed
Blocked by: T1

# T2 — 玩家近战接入剑弧粒子特效

## 构建内容

在玩家近战挥砍的活跃帧期间触发剑弧粒子特效。

**修改点：**

1. **变量声明**：新增 `var melee_slash: GPUParticles3D`

2. **初始化**（`_ready()`）：在 MeleeViewmodel 初始化之后，调用 `MeleeVFX.create_slash()` 创建剑弧粒子节点
   - 父节点：`camera_item`（与 MeleeViewmodel 同级，不在 Container 内）
   - 颜色：`MeleeVFX.COLOR_PLAYER`
   - 渲染层：`2`（layer 2，仅武器相机可见）
   - 发射盒：`MeleeVFX.PLAYER_BOX_EXTENTS`
   - 本地位置：`Vector3(0, -0.5, -1.0)`（映射自 MeleeHitbox 在 Player 根下的 `(0, 0.5, -1.0)`，减去 Head 偏移 `(0, 1, 0)`，即玩家前方 1m 腰部高度）

3. **触发**（`action_melee()`）：在活跃帧开始的 `create_timer(ACTIVE_START)` 回调中，同时触发 `melee_hitbox.monitoring = true` 和 `MeleeVFX.trigger(melee_slash)`

## 位置映射

```
MeleeHitbox 在 Player 本地 = (0, 0.5, -1.0)
CameraItem 在 Head 本地 = (0, 0, 0)，Head 在 Player 本地 = (0, 1, 0)
→ CameraItem 世界 = Player 世界 + (0, 1, 0)
→ 剑弧在 CameraItem 本地 = (0, 0.5, -1.0) - (0, 1, 0) = (0, -0.5, -1.0)
```

## 验收标准

- [x] `player.melee_slash` 在 `_ready()` 后非空，为 GPUParticles3D 节点
- [x] 剑弧节点的 `layers = 2`（仅武器相机可见）
- [x] 剑弧节点挂载在 `CameraItem` 下，位置为 `(0, -0.5, -1.0)`
- [x] 按下 V 键挥砍后，活跃帧（0.2s）时 `melee_slash.emitting == true`
- [x] 挥砍结束后剑弧自动消失（粒子生命周期 0.2s，无需手动停止）
- [x] 连续挥砍时剑弧每次都正确触发（`restart()` 重置粒子状态）
- [x] 近战冷却期间按 V 键不触发剑弧（`action_melee()` 顶部 `melee_cooldown_remaining > 0` 提前返回）

## 完成备注

- 剑弧触发与 `melee_hitbox.monitoring = true` 在同一个 `create_timer` 回调中，保证时序同步
- 剑弧节点在 `melee_viewmodel` 为 null 时不创建（`if melee_viewmodel:` 块内），与 MeleeViewmodel 生命周期一致
- 触发时用 `if melee_slash:` 守卫，防止 null 引用