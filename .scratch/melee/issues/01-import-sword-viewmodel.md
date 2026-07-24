Status: ready-for-agent
Blocked by: 无

# T1 — 导入剑模型并建近战视图模型场景

## 构建内容

将剑的 GLB 模型 `E:\work\sp\游戏素材\游戏蔬菜\3d素材\poly_pizza\quaternius_swords.glb` 导入项目（复制到 `models/quaternius_swords.glb` 触发 Godot 自动导入），从中选取**一个**剑网格（GLB 文件名 "swords" 为复数，内含多个剑变体——选最简单/最普通的一把即可，实现时自行判断），建立近战视图模型场景 `objects/melee_viewmodel.tscn`。

**场景结构（重要）：**

- 根节点：`Node3D`（命名 `MeleeViewmodel`，作为后续 Tween 的目标）
- 子节点：所选剑网格的 `MeshInstance3D`（如 GLB 内含多 mesh 可全保留，但根 Node3D 必须是 `Node3D` 而非 `MeshInstance3D`，以便挂多个子节点）

**渲染层配置：**

- 视图模型下所有 `MeshInstance3D` 的 `layers` 设为 **2**（仅武器相机 `CameraItem` 可见，主相机 `Camera` cull_mask 排除 layer 2）
- 与 [player.tscn](file:///e:/work/sp/Starter-Kit-FPS/objects/player.tscn) 中 `Container` 内枪械模型 layer 配置一致（参见 [player.gd](file:///e:/work/sp/Starter-Kit-FPS/objects/player.gd) 的 `change_weapon()` 中 `child.layers = 2` 模式）

**持握锚点：**

- 预设根节点 `position` / `rotation_degrees`，使剑在玩家右下视角持握观感正确（剑柄在右下、剑尖朝左上偏前）
- 该位置是**挥砍动画的起始锚点**（前摇阶段从这里举到右上）——T3 会在此位置基础上做 Tween
- 锚点位置无需精准调，T5 端到端调参时再微调；初版可参考 `Vector3(0.8, -0.8, -2.5)`（CameraItem 局部坐标系，与 `container_offset = Vector3(1.2, -1.1, -2.75)` 同量级）

## 验收标准

- [ ] 剑 GLB 已置于 `models/quaternius_swords.glb` 并完成导入（生成 `.import` 文件）
- [ ] 新建 `objects/melee_viewmodel.tscn`，根为 `Node3D`，内部引用所选剑网格 `MeshInstance3D`
- [ ] 视图模型下所有 `MeshInstance3D` 的 `layers` 设为 2（仅武器相机可见）
- [ ] 预设合理的 `position`/`rotation_degrees`，使剑在右下持握观感正确
- [ ] 该场景作为 `PackedScene` 可被 `player.gd` 以 `@export var melee_viewmodel: PackedScene` 引用
- [ ] 不修改任何现有武器模型或 `weapon.gd`

## 评论

- 视图模型生命周期由 T3 处理（`_ready()` 中实例化一次、挂 `CameraItem` 下、复用）——本工单只产出场景资源
- 挥砍动画样式为**下劈**（剑从右上→左下），见 ADR 006 后续决策与 CONTEXT.md「Swing Animation Style」
