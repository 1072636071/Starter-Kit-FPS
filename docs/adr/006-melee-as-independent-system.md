# ADR 006: 玩家近战能力作为独立系统接入

## 决策

玩家的近战能力采用 **方案 A：独立近战入口**——新增一个**独立的输入动作**（如 `melee` 键），由它触发近战攻击，**与 `weapons` 数组、`Weapon` 资源、`action_shoot()`、弹药/换弹体系完全解耦**。近战是"随时可用"的副攻击，开火键（`shoot`）仍只管枪械弹体。

## 背景

当前角色只有远程能力。现有 `Weapon` 资源（`scripts/weapon.gd`）与开火逻辑（`player.gd` 的 `action_shoot()`）强绑定于"发射弹体 + 弹药/换弹"模型：`projectile_color/size/speed`、`magazine_size/max_reserve/reload_time`、右下角弹药 HUD、换弹 Tween 全部围绕弹体设计，`action_shoot()` 无条件生成 `projectile.tscn`。`weapons` 数组通过 `weapon_toggle` 循环切换。

玩家侧没有任何近战入口（怪物侧 `monster_melee` 已有近战 AI，但那是敌人行为，与玩家开火无关）。用户希望补充玩家近战，并提供了剑的模型 `quaternius_swords.glb`。

核心张力：近战**没有弹体、没有弹药、没有换弹**，与 `Weapon` 的资源契约不兼容。必须决定近战如何接入现有系统。

## 替代方案

| 方案 | 描述 | 否决原因 |
|------|------|----------|
| A. 独立近战入口（**选中**） | 新增独立输入动作，与 `weapons` 数组解耦；剑模型在挥砍动画中显示 | 对现有 `Weapon`/`action_shoot`/弹药/HUD 体系**零侵入**，最省事，且语义清晰（"随时可用的副攻击"） |
| B. 近战做成武器槽 | 在 `weapons` 数组加一把近战武器，切到它后按开火触发挥砍 | 需给 `Weapon` 加 `type` 枚举并对 `action_shoot()` 做分支，弹药/换弹逻辑要特判（近战不该有弹匣），侵入性大、易引入边界 bug |
| C. 混合（近处开火自动变近战） | 枪口很近时开火自动转近战 | 逻辑耦合复杂，远程/近战判定边界模糊，不推荐 |

## 影响

- 新增近战专属输入动作（绑定见后续决策），**不**改动 `Weapon` 资源与 `action_shoot()`。
- 新增近战处理逻辑（命中检测、伤害、冷却、挥砍动画），与 `weapons`/`magazine`/`reserve` 互不依赖。
- 剑的模型（`quaternius_swords.glb`）需导入项目（建议置于 `models/`），作为近战挥砍的**瞬态**视图模型（viewmodel）：平时隐藏，仅按下近战键的挥砍动画期间显示并随手臂摆动，动画结束自动收回隐藏（与常驻枪械视图模型互不干扰）。
- 命中检测复用三种怪物已有的 `damage(amount)` 接口（ monsters 的 `damage()` 已接入 ADR 005 的 `HitFeedback.flash`，命中变色反馈自动生效）。具体采用**玩家正前方的 `Area3D` 命中区（Melee Hitbox）**：仅在挥砍动画的"活跃帧"开启 `monitoring`，用 `get_overlapping_bodies()` 收集命中怪物，每个敌人每次挥砍只结算一次伤害（用 `Set` 去重）。**注：** `monster_melee.tscn` 虽有 `HitArea` Area3D 节点，但其 `monster_melee.gd::_deal_damage()` 实际用的是距离判定而非 Area3D 监听——该节点是"声明而未使用"的死代码，不构成真正的用法先例。玩家近战的 Area3D + `get_overlapping_bodies()` 是项目内的首次实现。
- **初版调参**（均为 `@export`）：`melee_damage = 40`、`melee_cooldown = 0.5s`、`melee_reach = 2.0m`（与 `monster_melee.attack_range` 一致）、命中区宽高约 `1.5m`。
- 新增独立输入动作 `melee`，默认绑定 **V 键**（已核查 `project.godot`：W/A/S/D、Space、E、R 已占用，V 空闲无冲突），与 `shoot`/`aim`/`reload`/`weapon_toggle` 完全解耦。
- 受击反馈可复用 ADR 005 的 `HitFeedback.flash(target)`，无需新建反馈通道。

## 后续决策（grill 会话补充）

下列子决策在 grill 会话中确定，详见 CONTEXT.md「近战系统（Melee）」对应术语条目。

| 子决策 | 选定方案 | 关键理由 |
|--------|----------|----------|
| **挥砍时序** | `swing_duration = 0.4s`，Active Frames `0.1s–0.3s`（伤害窗口 0.2s，前摇/后摇各 0.1s） | 留 0.1s 缓冲到 `melee_cooldown`（0.5s）结束；前摇给"举剑"动画时间，后摇给"收剑"动画时间 |
| **Melee Hitbox 朝向** | 挂 Player 根节点，**只跟随 yaw，不跟随 pitch**；中心 `Vector3(0, 0.5, -1.0)`，`BoxShape3D(1.5, 1.5, 2.0)` | 近战短射程+0.5s 冷却下可预测性 > 技巧表达；与射击系统（用相机方向+散布做瞄准）差异化才有辨识度；pitch 跟踪会让盒子穿地板/天花板 |
| **挥砍动画样式** | 下劈（Downward Slash），剑从右上→左下 | FP 视觉冲击最强；"挥砍"语义最贴合；与挥砍时序天然契合 |
| **近战-换弹并发** | 互不阻塞：换弹中可挥砍，挥砍中可换弹 | ADR 006 核心是解耦——若近战被换弹阻塞就破坏解耦语义 |
| **穿墙语义** | v1 用 `has_method("damage")` 过滤重叠体；接受薄墙穿墙边缘情况 | 墙体 StaticBody3D 无 `damage()` 自然被过滤；RayCast 视线检查对 v1 是过度工程 |
| **Viewmodel 生命周期** | `_ready()` 中实例化一次、挂 `CameraItem` 下（与 `Container` 平级）；每次挥砍复用同一实例 | 不在 `Container` 内否则被 `change_weapon()` 清掉；不每次挥砍重新 instantiate（最简最稳） |
| **冷却实现** | 浮点累加器 `melee_cooldown_remaining`，在 `_process(delta)` 递减 | 与 `_step_reload` 同模式；避免向 `player.tscn` 加 Timer 节点 |
| **挥砍音效** | v1 跳过 | `sounds/` 下无合适 whoosh/挥砍素材；不复用现有音效（语义不符） |
