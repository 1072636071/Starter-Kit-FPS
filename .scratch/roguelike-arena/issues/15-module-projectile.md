# 15 — 弹道模块组（MultiShot + ChargedShot + DebuffOnHit）

Status: ready-for-agent
Type: task
Refs: ADR 022, issue 09

## 描述

实现三个远程弹道模块。这是模块系统中"修改攻击行为"模式的验证——模块不替换整个攻击系统，而是在攻击触发时叠加效果。**本工单只写模块代码，不创建敌人。** 敌人组装见 issue 18。

## 前置依赖

- [x] issue 09（模块钩子 `on_enter_state`）

## 验收标准

### MultiShot 模块（连续快射）

- [ ] 新建 `scripts/modules/module_multishot.gd`，实现：
  - `on_enter_state(AIState.ATTACK)` — 在 `burst_interval` 间隔内连续调用 `enemy._fire_projectile()` 共 `burst_count` 次
  - 用 `SceneTree.create_timer()` 链式调度每次发射（或 for 循环 + `await`）
  - 非 ATTACK 进入不触发
- [ ] `@export` 参数：`burst_count: int = 4`、`burst_interval: float = 0.15`

### ChargedShot 模块（蓄力高伤单发）

- [ ] 新建 `scripts/modules/module_charged_shot.gd`，实现：
  - `on_enter_state(AIState.ATTACK)` — 进入蓄力状态（敌人在原地，`_desired_velocity = Vector3.ZERO`，模块标记 `_charging = true`）
  - `charge_time` 秒后发射：临时提升 `enemy.attack_damage *= charged_damage_mult` → 调用 `_fire_projectile()` → 恢复原值
  - `on_tick` 中如果 `_charging` 为 true，强制 `enemy._desired_velocity = Vector3.ZERO`（阻止移动）
- [ ] `@export` 参数：`charge_time: float = 1.2`、`charged_damage_mult: float = 3.0`

### DebuffOnHit 模块（命中减伤）

- [ ] 新建 `scripts/modules/module_debuff_on_hit.gd`，实现：
  - `module_setup(enemy)` — 连接 `enemy.projectile_hit_player` 信号（需先确保 `monster_ranged` 有该信号，或模块通过覆盖弹体碰撞逻辑实现）
  - 当弹体命中玩家后：玩家 `damage_multiplier *= debuff_mult`，持续 `debuff_duration` 秒后恢复
- [ ] `@export` 参数：`debuff_mult: float = 0.7`、`debuff_duration: float = 2.0`

### 额外：MonsterRanged 辅助接口

- [ ] `monster_ranged.gd` 新增 signal：`projectile_hit_player(player)`（在弹体碰撞回调中 emit）
- [ ] 此改动使 DebuffOnHit 模块可通过信号解耦，无需修改怪物攻击代码

### 测试

- [ ] `tests/test_module_multishot.gd`：挂 MultiShot 模块的远程怪触发 ATTACK → 断言 0.45s 内射出 4 发弹体
- [ ] `tests/test_module_charged_shot.gd`：挂 ChargedShot 模块 → 触发 ATTACK → 断言 1.2s 蓄力后才射出 1 发，伤害为 3 倍
- [ ] `tests/test_module_debuff_on_hit.gd`：挂 DebuffOnHit 模块的远程怪命中玩家 → 断言 2s 内玩家伤害输出降至 0.7 倍
