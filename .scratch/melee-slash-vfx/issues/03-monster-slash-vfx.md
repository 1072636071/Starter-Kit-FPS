Status: completed
Blocked by: T1

# T3 — 怪物近战接入剑弧粒子特效

## 构建内容

在近战怪物（`monster_melee`）攻击的活跃帧期间触发剑弧粒子特效。

**修改点：**

1. **变量声明**：新增 `var melee_slash: GPUParticles3D`

2. **初始化**（`_ready()`）：在武器模型挂载之后，调用 `MeleeVFX.create_slash()` 创建剑弧粒子节点
   - 父节点：`self`（怪物自身节点）
   - 颜色：`MeleeVFX.COLOR_ENEMY`
   - 渲染层：`4`（layer 3 bitmask，主相机可见）
   - 发射盒：`MeleeVFX.ENEMY_BOX_EXTENTS`
   - 本地位置：`Vector3(0, 0.5, -1.5)`（敌人前方 1.5m、腰部高度，命中判定中心区域）

3. **触发**（`_start_attack()`）：在 `active_frame_time` 的 `create_timer` 回调中，同时触发 `_deal_damage()` 和 `MeleeVFX.trigger(melee_slash)`

## 关键注意

- 怪物使用距离判定（`to_player.length() <= attack_range + 0.8`），无 Area3D 命中区，因此剑弧位置是手动估算的命中判定中心
- 怪物死亡后不再攻击（FSM 状态机保证），但 `melee_slash` 节点仍存在于场景树中——`trigger()` 中的 `is_instance_valid` 守卫防止死节点触发
- 剑弧的 `ENEMY_BOX_EXTENTS = (1.0, 1.0, 1.4)` 比玩家大，匹配怪物更大的攻击范围（`attack_range + 0.8 ≈ 2.8m`）

## 验收标准

- [x] 每只近战怪物在 `_ready()` 后 `melee_slash` 非空
- [x] 剑弧节点的 `layers = 4`（layer 3，主相机可见）
- [x] 剑弧节点挂载在怪物自身下，位置为 `(0, 0.5, -1.5)`
- [x] 怪物攻击时，在 `active_frame_time` 后 `melee_slash.emitting == true`
- [x] 怪物死亡后不再触发剑弧（攻击已停止，FSM 不进入 ATTACK 状态）
- [x] 多只怪物同时攻击时，各自独立触发剑弧，互不干扰

## 完成备注

- 剑弧触发与 `_deal_damage()` 在独立的 `create_timer` 回调中，两者并行不互相阻塞
- 触发时用 `if melee_slash and is_instance_valid(melee_slash):` 双重守卫
- 怪物死亡后 `melee_slash` 节点随怪物 `queue_free()` 自然销毁