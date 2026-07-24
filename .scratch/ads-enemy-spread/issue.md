# 工单：ADS 瞄准 + 后坐力减弱 + 敌人散布

来源：2026-07-24 Grill with Docs 会话。四个子任务已全部实施完成。

## 减弱后坐力

**构建内容：** Blaster knockback 40→20，Blaster-Repeater knockback 10→5。相机抖动和武器模型回弹均等比减弱。

- [x] `weapons/blaster.tres`: knockback = 20
- [x] `weapons/blaster-repeater.tres`: knockback = 5

## 右键 ADS 瞄准

**构建内容：** 右键从武器切换改为瞄准。按住右键进入 ADS：FOV 75°→60° 平滑过渡、武器散布减半、玩家移动速度减慢 30%。

- [x] `project.godot`: 右键从 `weapon_toggle` 移除，新增 `aim` 动作
- [x] `objects/player.gd`: 新增 `is_aiming`/`default_fov`/`aim_fov` 变量，FOV lerp 过渡，散布 ×0.5，移动速度 ×0.7
- [x] `objects/player.gd`: **审查修复** — 魔法数字提取为命名常量（`ADS_SPEED_FACTOR`、`ADS_SPREAD_FACTOR`、`DEFAULT_FOV`、`AIM_FOV`），FOV lerp 改用 `move_toward`（帧率无关线性插值），ADS 进入时强制确保鼠标捕获模式

## 敌人射击散布

**构建内容：** Enemy 和 MonsterRanged 均新增 `@export var enemy_spread: float = 0.08`。散布随目标距离线性缩放（`distance_factor = clamp(distance / 10, 0.5, 2.0)`），模拟远距离精度下降。

- [x] `objects/enemy.gd`: 新增 `enemy_spread` export var，散布随距离缩放
- [x] `objects/monster_ranged.gd`: 硬编码散布替换为 `enemy_spread` export var，散布随距离缩放
- [x] `scripts/combat_utils.gd`: **审查修复** — 提取 `apply_enemy_spread()` 静态函数，消除 enemy.gd 与 monster_ranged.gd 之间的重复代码
