# 03 — 击杀奖励（金币 / 经验 / 血包）

Status: resolved
Type: task
Refs: PRD.md, ADR 015, CONTEXT.md「Kill Reward / Health Pack / Gold / XP / monster_type」, Q7

## 描述

怪物死亡时结算奖励。当前怪物在 `health <= 0` 时 `destroy()` → `queue_free()` 且**不发射任何死亡信号**，需先建立死亡 seam，再由其触发奖励结算（金币 / 经验 / 小概率血包），由 `RunDirector`（issue 02）监听。

## 验收标准

### 死亡信号与 monster_type 约定
- 在三种怪物（`monster_melee` / `monster_ranged` / `enemy`）中新增 `signal died(monster_type: StringName)`，于 `destroy()` 内、`queue_free()` 前（含延迟 `queue_free()` 分支）发射。
- 每个怪物脚本顶部用 `const MONSTER_TYPE: StringName = &"<value>"` 硬编码类型标识（**不**用 `@export`，避免漏配）：
  - [monster_melee.gd](file:///g:/work/Starter-Kit-FPS/objects/monster_melee.gd): `const MONSTER_TYPE: StringName = &"monster_melee"`
  - [monster_ranged.gd](file:///g:/work/Starter-Kit-FPS/objects/monster_ranged.gd): `const MONSTER_TYPE: StringName = &"monster_ranged"`
  - [enemy.gd](file:///g:/work/Starter-Kit-FPS/objects/enemy.gd): `const MONSTER_TYPE: StringName = &"enemy"`
- 信号发射时机：`destroy()` 开始处（设置 `destroyed = true` / `_dead = true` 之后、`queue_free()` 之前），确保 `died` 在 `MeleeA`/`RangedA` 的延迟 `queue_free()`（死亡动画期间）也能被 RunDirector 收到并正确减 `alive_count`。
- 同时给 [enemy.gd](file:///g:/work/Starter-Kit-FPS/objects/enemy.gd) 补 `_dead` 守卫（现无），与 melee/ranged 一致，防止 `destroy()` 重入。

### 奖励结算
- `RunDirector` 监听 `died`，按 `monster_type` 查表结算：金币 = 经验（同值）——`monster_melee`=5、`monster_ranged`=8、`enemy`=10。
- 奖励**不随波次缩放**（数值固定，靠每波数量/种类递增自然增长）。
- 金币 / 经验变化经 `RunDirector` 的 `gold_changed` / `xp_changed` 信号广播；`kills` 计数 `+= 1` 并发 `kills_changed`。
- `gold_earned_total` 同步 `+= reward_gold`（用于 issue 06 结算"累计金币"=总赚取，不受消费影响）。

### 血包掉落
- 怪物死亡有 **10%** 概率掉落血包（`Health Pack`）。掉率判定使用 `run_director.rng.randf() < 0.10`（RNG 由 issue 02 提供，可注入种子以便测试）。
- 血包在**怪物死亡位置**生成；若死亡位置 y > 1.0m（飞行敌人或被击飞），血包做一次 RayCast 向下投影到地面（避免悬空）。

### Health Pack 实体规格（新增）
- 新建 `scenes/health_pack.tscn`（根节点 `Area3D`）+ `scripts/health_pack.gd`。
- `@export var heal_amount: int = 25`（恢复 25 血，约占 100 基础血量的 1/4，可调）。
- **拾取机制**：`Area3D` + `body_entered` 信号，检测进入者是否在 `"player"` 组；命中后调用 `player.heal(heal_amount)`（Player 需新增 `heal(amount)` 方法，仅加血不超过 `max_health`，不发 `damage`、不影响护盾）。
- **过期**：血包生成后 `despawn_time = 15s`（`@export`）后自动 `queue_free()`；最后 3 秒做一次闪烁 Tween 提示即将消失。
- **视觉**：复用现有素材或简单占位（红色十字 / 发光球体 `SphereMesh` + emission 材质）；`layers = 1`（进主相机，不刻意避开小地图——但小地图 cull_mask 只看 layer 1，血包作为 layer 1 的 Area3D 无 mesh 不会产生 blob）。
- **暂停**：血包节点 `PROCESS_MODE_PAUSABLE`（默认），暂停期间 `despawn_time` 计时器冻结、不拾取。
- **不堆叠**：同一位置只刷一个血包（概率判定一次，不因多怪同帧死亡而叠加）。

### Player.heal 方法
- `Player` 新增 `func heal(amount: int)`：`health = min(health + amount, max_health)`，发 `health_updated` 信号。**不**改护盾。
- 若 issue 01 已定义 `max_health`，沿用；否则本 issue 新增 `@export var max_health: int = 100`（现 `health: int = 100` 无上限字段）。

## 评论

- `monster_type` 取值与脚本/场景基名一致（`&"monster_melee"` 等），便于 grep 与 RunDirector 查表。
- 血包 `heal_amount = 25` 是初值，平衡阶段可调；不与护盾恢复冲突（血包只加 `health`）。
- 血包过期机制防止场上堆积；15s 是占位，可调。

## 答案

已实现，TDD 测试 [tests/test_monster_died_signal.gd](file:///g:/work/Starter-Kit-FPS/tests/test_monster_died_signal.gd)（14 项断言）+ [tests/test_health_pack.gd](file:///g:/work/Starter-Kit-FPS/tests/test_health_pack.gd)（7 项断言）全绿。

实现要点：
- **died 信号 & monster_type**：
  - [monster_base.gd:20,122-123](file:///g:/work/Starter-Kit-FPS/objects/monster_base.gd#L20-L123) — `signal died(monster_type: StringName)` + 虚方法 `_monster_type()`（动态分派，避免 const 词法作用域静态绑定基类问题）。
  - [monster_base.gd:129-138](file:///g:/work/Starter-Kit-FPS/objects/monster_base.gd#L129-L138) — `destroy()`：`_dead = true` → `died.emit(_monster_type())` → 播 die 动画 + 延迟 queue_free（或立即 queue_free）。
  - [monster_melee.gd:6,17-18](file:///g:/work/Starter-Kit-FPS/objects/monster_melee.gd#L6-L18) — `const MONSTER_TYPE = &"monster_melee"` + override。
  - [monster_ranged.gd:7,23-24](file:///g:/work/Starter-Kit-FPS/objects/monster_ranged.gd#L7-L24) — `const MONSTER_TYPE = &"monster_ranged"` + override。
  - [enemy.gd:4,20,50-57](file:///g:/work/Starter-Kit-FPS/objects/enemy.gd#L4-L57) — `const MONSTER_TYPE = &"enemy"` + `signal died` + `destroy()` 发射 died + `_dead` 守卫防重入（原 enemy 无 _dead，补齐与 melee/ranged 一致）。
- **奖励结算**（[run_director.gd:218-238](file:///g:/work/Starter-Kit-FPS/scripts/run_director.gd#L218-L238)）：`_on_monster_died(monster_type, monster)` 查表 `REWARD_MELEE=5 / REWARD_RANGED=8 / REWARD_ENEMY=10` → `add_gold` + `add_xp` + `add_kills`（gold/xp 同值，不随波缩放）。
- **血包掉落**（[run_director.gd:277-305](file:///g:/work/Starter-Kit-FPS/scripts/run_director.gd#L277-L305)）：`rng.randf() < health_pack_drop_chance (0.10)`；死亡位置 y>1 时 RayCast 向下投影到地面；同位置 2m 内已有血包则跳过（不堆叠）。
- **Health Pack 实体**（[scripts/health_pack.gd](file:///g:/work/Starter-Kit-FPS/scripts/health_pack.gd) + [scenes/health_pack.tscn](file:///g:/work/Starter-Kit-FPS/scenes/health_pack.tscn)）：`Area3D` + `body_entered` 检测 player 组 → `player.heal(heal_amount)`；`despawn_time=15s` 后 queue_free；`@export heal_amount=25`；`PROCESS_MODE_PAUSABLE`。
- **Player.heal**（[player.gd:654-658](file:///g:/work/Starter-Kit-FPS/objects/player.gd#L654-L658)）：`health = min(health + amount, max_health)`，`_dead` 时 no-op，发 `health_updated`。

测试：
- `godot --headless res://tests/test_monster_died_signal.tscn --quit-after 600` → `[TEST] PASS`（三怪 MONSTER_TYPE 常量、died 信号、致死单次发射、类型携带、_dead 守卫防重入）。
- `godot --headless res://tests/test_health_pack.tscn --quit-after 600` → `[TEST] PASS`（heal_amount/despawn_time 默认值、拾取回血+queue_free、非玩家 body 忽略、过期自动消失）。
