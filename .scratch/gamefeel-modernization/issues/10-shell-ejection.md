# 10 — 弹壳抛射 VFX

Status: needs-triage
Type: task
Refs: PRD.md, CONTEXT.md「Shell Ejection」

## 描述

射击时从武器抛壳口弹出弹壳粒子：小方块 GPUParticles3D，带重力、自旋、短寿命，提升射击的"实体感"。

## 验收标准

- Weapon 资源新增 `@export_subgroup("Shell Ejection")`：
  - `@export var ejection_port: Vector3 = Vector3(0.1, -0.05, 0)` — 抛壳口相对 muzzle 的偏移
  - `@export var shell_color: Color = Color(0.8, 0.7, 0.3)` — 弹壳颜色（默认黄铜）
  - `@export var shell_eject_force: float = 2.0` — 弹出速度
- `action_shoot()` 每次击发时触发弹壳抛射（非 beam 武器）：
  - 创建一次性 `GPUParticles3D`（或复用预创建节点）于 `muzzle.global_position + ejection_port`
  - 参数：`amount = 1`（单发一发弹壳），`lifetime = 1.5`，`one_shot = true`
  - `ParticleProcessMaterial`：`direction = Vector3(1, 1, 0).normalized()`（右上方弹出），`spread = 30`，`initial_velocity = shell_eject_force`，`gravity = (0, -9.8, 0)`，`angular_velocity = 10`
  - 粒子 mesh 用 `BoxMesh(0.02, 0.04, 0.02)`（小长方体模拟弹壳）
- 弹壳世界空间生成，父节点为 `get_parent()`（与弹体同级），自动 `queue_free`
- 性能保护：用 `_shell_pool: Array[GPUParticles3D]` 预创建 8 个节点循环使用
  - 如果 8 个全在活跃中，跳过本次抛射（不创建新节点）

## 技术要点

- 弹壳必须在世界空间生成（不是 viewmodel 的本地坐标）。获取世界抛壳位置：`camera.to_global(container.to_local(muzzle.global_position) + ejection_port)`，其中 `camera` 是 `$Head/Camera` 节点。或者直接 `(muzzle.global_transform * Transform3D().translated(ejection_port)).origin`
- 使用节点池避免频繁创建/销毁：8 个 `GPUParticles3D` 预创建为 `get_tree().root` 的子节点，通过 `_shell_pool_index` 循环索引复用
- `finished.connect(queue_free)` + 池回收逻辑
- v1 不需要不同弹种不同模型（手枪/步枪弹壳共用黄铜色小方块）

## 评论

（无）
