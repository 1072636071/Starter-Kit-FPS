# 02 — RunDirector 三级货币核心 + 击杀奖励换算

Status: done
Type: task
Refs: PRD.md, ADR 023, CONTEXT.md「Gold / Silver / Copper / Kill Reward」

## 实现记录

- `run_director.gd`: `gold`→`copper`、`add_gold`→`add_copper`、`spend_gold`→`spend_copper`、新增 `format_currency()`、信号 `gold_changed`→`currency_changed`
- ENEMY_CONFIG reward: 5→500, 8→800, 10→1000
- 宝箱/手雷补偿: 金→铜换算（×100 和 ×3000）
- `game_over` stats: `gold_earned_total`→`copper_earned_total`
- 所有引用点已迁移: `hud.gd`, `shop_ui.gd`, `chest_ui.gd`, `game_over.gd`, `weapon_pickup.gd`
- 测试文件已适配新 API: `test_run_director.gd`, `test_chest_expansion.gd`, `test_monster_fall_death.gd`, `test_shop.gd`, `test_shop_ui_redesign.gd`

## 描述

将 `RunDirector` 的货币系统从单一金币重构为统一铜币内部存储，提供铜币加减接口和金银铜混合格式的显示函数。同时将击杀奖励从金币改为铜币。

## 验收标准

### 数据层

- `run_director.gd` 中：
  - `gold: int = 0` 改为 `copper: int = 0`
  - `add_gold(amount)` 改为 `add_copper(amount: int)`，累加 `copper`
  - `spend_gold(cost) -> bool` 改为 `spend_copper(cost: int) -> bool`，扣减 `copper`
  - 新增 `format_currency(amount: int = -1) -> String`，返回如 `"1金 23银 45铜"` 的混合格式字符串（amount 默认取 `copper` 当前值）
  - `gold_earned_total` 改为 `copper_earned_total: int`

### 信号

- `gold_changed(gold: int)` 改为 `currency_changed(copper: int)`
- 信号发射点在 `add_copper` 和 `spend_copper` 中

### 击杀奖励

- `ENEMY_CONFIG` 表中 `reward` 值 ×100：
  - `monster_melee`: 5 → 500（5 银）
  - `monster_ranged`: 8 → 800（8 银）
  - `enemy`: 10 → 1000（10 银 = 1 金）
- `_on_monster_died` 中 `add_gold(reward)` → `add_copper(reward)`
- `_reward_for()` 返回铜币值不变（只是改了表中的数字）

### 宝箱金币奖励

- `apply_chest_reward` 中 `&"gold_bonus"`: `add_gold(20 + 5 * wave)` → `add_copper((20 + 5 * wave) * 100)`

### 手雷补给满上限补偿

- `cancel_chest_weapon_replace` 中 `add_gold(30)` → `add_copper(3000)`（30 金 = 3000 铜 = 3 金）
- `_apply_grenade_supply_reward` 中金币补偿 `add_gold(30)` → `add_copper(3000)`

### 兼容

- 所有现有的 `gold_changed` 连接点改为 `currency_changed`
- `game_over` 信号 stats 中 `gold_earned_total` → `copper_earned_total`
