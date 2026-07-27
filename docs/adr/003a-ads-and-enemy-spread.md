# ADR 003a: ADS 瞄准与敌人散布系统

**状态**：部分被取代
**日期**：2026-07-24

> ADS 三参数（FOV/散布/移速）的"全武器统一"决策已被 [ADR 030](030-per-weapon-ads-coefficients.md) 取代——改为按武器差异化配置 4 个 ADS 字段。以下仅保留仍有效的决策。

## 仍有效的决策

### 输入映射变更

- 右键改为 ADS（`aim` 输入动作），`weapon_toggle` 仅保留 E 键
- 按住持续 ADS，松开退出

### 后坐力减半

Blaster knockback 40→20，Blaster-Repeater 10→5。

### 敌人散布：export var + 距离缩放

- Enemy 和 MonsterRanged 均新增 `@export var enemy_spread: float = 0.08`
- 散布随目标距离线性缩放：`effective_spread = enemy_spread * clamp(distance / 10, 0.5, 2.0)`
- 垂直方向散布 ×0.6

## 被否决的替代方案

- 右键保留切换武器（Shift 瞄准）：Shift 更自然用于奔跑，右键空闲是浪费
- ADS 无移动惩罚：无代价精度加成削弱战术深度
- 敌人散布硬编码：不可调，缺乏灵活性
# ADR 003: ADS 瞄准与敌人散布系统

**日期：** 2026-07-24
**状态：** 部分被取代
**决策者：** Grill with Docs 会话

> **修订记录**：本 ADR 中"FOV 75→60、散布×0.5、移速×0.7 全武器统一"的 ADS 三参数决策已被 [ADR 030](030-per-weapon-ads-coefficients.md) 取代——按武器差异化配置 4 个 ADS 字段（`ads_zoom_factor` / `ads_fov_override` / `ads_spread_factor` / `ads_speed_factor`）。本 ADR 的输入映射变更（右键 = aim，E = weapon_toggle）与敌人散布（`enemy_spread` + 距离缩放）部分仍有效。

## 背景

当前玩家武器后坐力过强（Blaster knockback=40），且没有右键瞄准能力。右键被 `weapon_toggle`（切换武器）占用，与 E 键功能重复。敌方射击精度过高：旧版 Enemy 无散布、MonsterRanged 仅硬编码极小偏移（±0.05），玩家缺乏生存空间。

需要：1）减弱后坐力；2）添加右键 ADS 降低散布；3）给敌人加可控散布。

## 决策

### 1. 后坐力减半

Blaster knockback 40→20，Blaster-Repeater 10→5。保留后坐力手感但不再过度。

### 2. 右键改为 ADS，E 键独占武器切换

- 新建 `aim` 输入动作，绑定右键
- `weapon_toggle` 移除右键绑定，仅保留 E 键
- ADS 效果：FOV 75°→60° 平滑 lerp、散布减半、移动速度 ×0.7
- 按住持续 ADS，松开退出

### 3. 敌人散布：export var + 距离缩放

- Enemy 和 MonsterRanged 均新增 `@export var enemy_spread: float = 0.08`
- 散布随目标距离线性缩放：`effective_spread = enemy_spread * clamp(distance / 10, 0.5, 2.0)`
- 垂直方向散布乘以 0.6（弹道偏转在水平面上更显著）

## 否决的替代方案

### 方案 B：右键保留切换武器，用其他键瞄准（如 Shift）

否决原因：Shift 更自然用于奔跑，且 E 键已能完成武器切换，右键空闲是浪费。将最常用的战术动作（瞄准）绑定到最易触达的右键是标准 FPS 惯例。

### 方案 C：ADS 无移动惩罚

否决原因：无代价的精度加成会导致 ADS 成为无脑选择，削弱战术深度。30% 移动减速是经典 FPS 权衡（CS/Valorant 等均采用类似设计）。

### 方案 C：敌人散布硬编码

否决原因：硬编码不可调，未来新增敌人类型时缺乏灵活性。`export var` 可在编辑器直接调整，无需改代码。

## 影响范围

- `weapons/blaster.tres`, `weapons/blaster-repeater.tres` — 数值变更
- `project.godot` — 输入映射变更
- `objects/player.gd` — 新增 ADS 逻辑
- `objects/enemy.gd`, `objects/monster_ranged.gd` — 新增散布逻辑
- `CONTEXT.md` — 新增词汇表章节
