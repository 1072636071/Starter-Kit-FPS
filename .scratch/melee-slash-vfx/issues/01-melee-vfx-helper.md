Status: completed
Blocked by: 无

# T1 — 创建 MeleeVFX 静态工具类

## 构建内容

新建 `MeleeVFX` 静态工具类（`class_name MeleeVFX`），统一管理玩家和敌人的近战剑弧粒子特效的创建与触发。

**两个静态方法：**

- `create_slash(parent: Node3D, color: Color, cull_layer: int, box_extents: Vector3, local_pos: Vector3) -> GPUParticles3D`
  - 创建并配置完整的 GPUParticles3D 节点
  - 配置 ParticleProcessMaterial：Box 发射形状、下劈方向、25° 扇形扩散、flatness 压扁
  - 配置颜色渐变（中间亮两端淡）和缩放曲线（快速放大再缩小）
  - 配置 draw_pass_1：QuadMesh 扁条 + additive 发光 + billboard 朝向相机
  - 将节点挂载到 parent 下，返回引用

- `trigger(particles: GPUParticles3D)`
  - 调用 `particles.restart()` + `particles.emitting = true`
  - 触发一次性爆发

**共享常量：**

| 常量 | 值 | 说明 |
|------|-----|------|
| `SLASH_LIFETIME` | 0.2 | 粒子生命周期 |
| `SLASH_AMOUNT` | 30 | 每次爆发粒子数 |
| `COLOR_PLAYER` | `(0.3, 0.7, 1.0, 0.85)` | 玩家青白配色 |
| `COLOR_ENEMY` | `(1.0, 0.25, 0.15, 0.85)` | 敌人红橙配色 |
| `PLAYER_BOX_EXTENTS` | `(0.75, 0.75, 1.0)` | 玩家命中区半尺寸 |
| `ENEMY_BOX_EXTENTS` | `(1.0, 1.0, 1.4)` | 敌人命中区半尺寸 |

## 验收标准

- [x] `MeleeVFX.create_slash()` 返回配置完整的 GPUParticles3D 节点
- [x] 返回节点的 `process_material` 为 ParticleProcessMaterial，Box 发射形状
- [x] 返回节点的 `draw_pass_1` 为 QuadMesh，材质为 additive 发光 + billboard
- [x] `MeleeVFX.trigger()` 调用后 `particles.emitting == true`
- [x] 所有颜色/大小/生命周期等参数为常量，可在一处修改

## 完成备注

- 文件：`scripts/melee_vfx.gd`
- `class_name MeleeVFX` 使全局可用，无需 preload
- 粒子 QuadMesh 使用 `QuadMesh.FACE_Z` 朝向，配合 `BILLBOARD_ENABLED` 始终面向相机
- 颜色渐变用 8 点 Gradient 做"明暗交替"效果，模拟刀光闪烁
- 缩放曲线：0→0.3→0.7→1.0 对应 scale 0.1→1.0→0.3→0.0，快速出现再消失