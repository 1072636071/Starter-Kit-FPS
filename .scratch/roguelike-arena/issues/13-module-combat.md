# 13 — 战斗模块组（BerserkOnDamage + Shield + SelfDestruct/ExplodeOnDeath）

Status: ready-for-agent
Type: task
Refs: ADR 022, issue 09

## 描述

实现四个近战向战斗模块。这是模块系统中"受击响应"和"自毁"模式的验证。**本工单只写模块代码，不创建敌人。** 敌人组装见 issue 17。

## 前置依赖

- [x] issue 09（模块钩子 `on_damage` / `on_death` / `on_tick`）

## 验收标准

### BerserkOnDamage 模块

- [ ] 新建 `scripts/modules/module_berserk_on_damage.gd`，实现：
  - `on_damage(amount)` — 若不在冷却：启动狂暴（`_berserk_active = true`），修改宿主 `damage_multiplier *= berserk_damage_mult`、`move_speed *= berserk_speed_mult`
  - 设置 `SceneTree.create_timer(berserk_duration)` 恢复原值
  - 启动 `berserk_cooldown` 冷却
- [ ] `@export` 参数：`berserk_damage_mult: float = 1.5`、`berserk_speed_mult: float = 1.3`、`berserk_duration: float = 3.0`、`berserk_cooldown: float = 8.0`

### Shield 模块

- [ ] 新建 `scripts/modules/module_shield.gd`，实现：
  - `module_setup(enemy)` — `shield_current = shield_max`
  - `on_damage(amount) -> int` — 先扣盾，返回溢出量（供基类继续扣 health）；盾破时发 `shield_broken` 信号
  - `module_setup` 中连接 `shield_broken` → 触发 `_on_shield_broken()` 虚方法（子类覆盖）
- [ ] `@export` 参数：`shield_max: int = 60`

### SelfDestruct 模块

- [ ] 新建 `scripts/modules/module_self_destruct.gd`，实现：
  - `on_tick(delta)` — 检测玩家距离 < `detonate_range` → 启动 `_detonate_sequence()`
  - `_detonate_sequence()` — 0.8s 蜂鸣闪烁前摇（`modulate` 红白交替）→ AOE 爆炸（`radius = 5.0m`，`damage = 60`）→ 调用宿主 `destroy()`
- [ ] `@export` 参数：`detonate_range: float = 3.0`、`fuse_time: float = 0.8`、`explosion_radius: float = 5.0`、`explosion_damage: int = 60`

### ExplodeOnDeath 模块

- [ ] 新建 `scripts/modules/module_explode_on_death.gd`，实现：
  - `on_death()` — AOE 爆炸（`radius = 4.0m`，`damage = 40`），用 `Area3D` 一次性检测范围内玩家
  - 与 SelfDestruct 共存时：SelfDestruct 先触发 `destroy()` → `on_death()` 被调用，但模块内部记录 `_already_exploded` 标志避免重复爆炸
- [ ] `@export` 参数：`explosion_radius: float = 4.0`、`explosion_damage: int = 40`

### 测试

- [ ] `tests/test_module_berserk.gd`：触发伤害 → 断言 `move_speed` 和 `damage_multiplier` 变为乘后值，3s 后恢复
- [ ] `tests/test_module_shield.gd`：攻击有盾敌人 → 断言先扣盾再扣血；盾破后 `shield_broken` 信号发出
- [ ] `tests/test_module_self_destruct.gd`：玩家接近 → 断言 0.8s 前摇后爆炸 AOE 伤害 60，敌人死亡
- [ ] `tests/test_module_explode_on_death.gd`：杀死敌人 → 断言死亡时爆炸；挂 SelfDestruct 同时挂 ExplodeOnDeath → 断言只爆一次
