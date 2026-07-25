# ADR 020: 近战剑弧粒子特效 —— 攻击范围可视化

## 决策

为玩家和近战怪物的近战攻击添加**剑弧拖尾粒子特效**（GPUParticles3D 一次性爆发），在攻击活跃帧期间显示可见的攻击范围：

1. **技术选型**：GPUParticles3D 一次性爆发（`one_shot=true`），用 Box 发射形状 + 扇形扩散 + 下劈方向，形成弧形光效
2. **玩家配色**：青白冷色（`Color(0.3, 0.7, 1.0, 0.85)`），挂在 `CameraItem` 下，layer 2 仅武器相机可见
3. **敌人配色**：红橙暖色（`Color(1.0, 0.25, 0.15, 0.85)`），挂在怪物自身节点下，layer 3 主相机可见
4. **触发时机**：与伤害结算的活跃帧同步——玩家在 `ACTIVE_START`（挥砍开始后 0.2s），怪物在 `active_frame_time`（攻击动画活跃帧）
5. **发射盒尺寸**：玩家匹配 MeleeHitbox 的 BoxShape3D(1.5, 1.5, 2.0) 半尺寸；敌人用更大的盒子（`ENEMY_BOX_EXTENTS = (1.0, 1.0, 1.4)`）匹配其更大的攻击范围（`attack_range + 0.8 ≈ 2.8m`）
6. **粒子行为**：下劈方向（`Vector3(0, -1, 0)`）、25° 扇形扩散、`flatness=0.7` 压扁在 XY 平面形成弧面、快速减速（damping 3-6）、轻微上飘（gravity y=3.0）
7. **视觉材质**：QuadMesh 扁条 + 无光照 additive 混合 + billboard 朝向相机 + 颜色/缩放渐变曲线

## 背景

现有近战系统（ADR 006 / 019）中，命中判定完全不可见：
- 玩家侧：MeleeHitbox 是透明 Area3D，玩家看不到自己的攻击范围
- 怪物侧：纯距离判定（`_deal_damage()` 中的 `to_player.length() <= attack_range + 0.8`），玩家被怪物近战攻击时也看不到范围

这导致玩家无法判断"什么时候该闪避"、"我的攻击够不够得着"，近战缺乏空间感知反馈。

## 替代方案

| 方案 | 描述 | 否决原因 |
|------|------|----------|
| **A. GPUParticles3D 剑弧（选中）** | 一次性爆发粒子形成弧面光效 | 配置简单（无需 shader）、与现有 burst_animation/impact 技术线一致、可复用同一套粒子材质 |
| B. MeshInstance3D + Shader | 动态生成弯曲弧面 mesh + 自定义 shader 渐变 | 需写 shader + 动态 mesh 生成，复杂度高，v1 过度工程 |
| C. AnimatedSprite3D 序列帧 | 预渲染刀光帧（类似 burst_animation） | 灵活性低——每种角度/武器需要不同帧，不支持动态命中区大小 |
| D. 半透明盒子可视化 | 在活跃帧显示半透明 BoxMesh 精确展示命中区 | 视觉太"工具化"、破坏沉浸感；与剑挥砍动作割裂 |
| E. 地面范围圈 | MOBA 风格地面 decal 圆形指示器 | 第一人称下看不到自己的圈；不适用于立体空间（飞行敌人） |

## 影响

### 新增文件
- `scripts/melee_vfx.gd`：`MeleeVFX` 静态工具类，提供 `create_slash()` 和 `trigger()`

### 修改文件
- `objects/player.gd`：新增 `melee_slash` 变量、`_ready()` 中创建、`action_melee()` 活跃帧触发
- `objects/monster_melee.gd`：新增 `melee_slash` 变量、`_ready()` 中创建、`_start_attack()` 活跃帧触发

### 渲染层
- 玩家剑弧：layer 2（武器相机），仅第一人称可见
- 敌人剑弧：layer 3（主相机），第三人称可见

### 性能
- 每次挥砍 30 个粒子，生命周期 0.2s，`speed_scale=1.5`
- 玩家冷却 0.7s，怪物冷却 1.2s，同时最多 16 只怪物 → 峰值 ~480 粒子
- GPUParticles3D 在 GPU 端计算，CPU 开销可忽略