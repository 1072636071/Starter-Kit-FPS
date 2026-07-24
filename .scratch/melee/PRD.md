# PRD：玩家近战系统

为当前只有远程能力的角色补充**玩家近战**能力：用剑发动近身攻击，与现有 `Weapon`/弹体/弹药体系完全解耦。

## 来源

- 架构决策：`docs/adr/006-melee-as-independent-system.md`
- 领域词汇：CONTEXT.md「近战系统（Melee）」术语表（Melee / Melee Viewmodel / Melee Hitbox / Melee Tuning / Melee Action）

## 核心需求

1. 按独立近战键（V）发动一次挥砍，剑视图模型在挥砍期间显示、结束收回
2. 挥砍命中身前小范围内的怪物，按 `melee_damage` 结算，每次挥砍每怪只结算一次
3. 命中后怪物自动泛红（复用 ADR 005 的 `HitFeedback.flash`，经怪物既有 `damage()` 触发）
4. 受独立冷却约束（`melee_cooldown`），不占用武器槽、不影响弹药/HUD

## 关键决策（来自 grill 与 ADR 006）

- 接入方式：独立输入动作，与 `weapons` 数组 / 弹药 / 换弹解耦
- 剑显示：瞬态视图模型，平时隐藏
- 命中检测：前方 `Area3D` 命中区（Melee Hitbox），仅活跃帧开启
- 调参初版：`melee_damage=40`、`melee_cooldown=0.5s`、`melee_reach=2.0m`、宽高≈1.5m（均 `@export`）
- 按键：新增 `melee` 动作绑 V 键（已核查 `project.godot` 无冲突）
- 模型来源：`quaternius_swords.glb`（需导入项目，建议 `models/`）
