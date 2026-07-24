Status: ready-for-agent
Blocked by: 无

# T1 — 导入剑模型并建近战视图模型场景

## 构建内容

将剑的 GLB 模型 `E:\work\sp\游戏素材\游戏蔬菜\3d素材\poly_pizza\quaternius_swords.glb` 导入项目（复制到 `models/` 触发 Godot 自动导入），从中选取一个剑网格，建立近战视图模型场景 `melee_viewmodel.tscn`。配置为仅在武器相机（layer 2）渲染，与现有 `Weapon` 模型一致；预设 `position`/`rotation` 与挥砍锚点，使其平时可被 `player.gd` 实例化并隐藏。

## 验收标准

- [ ] 剑 GLB 已置于 `models/`（或项目内可用路径）并完成导入
- [ ] 新建 `melee_viewmodel.tscn`，内部引用所选剑网格节点
- [ ] 视图模型下所有 `MeshInstance3D` 的 `layers` 设为 2（仅武器相机可见）
- [ ] 预设合理的 `position`/`rotation`，使剑在手中持握观感正确
- [ ] 该场景作为 `PackedScene` 可被 `player.gd` 以 `@export` 引用
- [ ] 不修改任何现有武器模型或 `weapon.gd`

## 评论
