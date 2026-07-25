# 24 — 宝箱奖励池扩展（随机武器 + 手雷补给）

Status: ready-for-agent
Type: task
Refs: ADR 022, issues 08/19/21/23

## 描述

扩展宝箱奖励池，新增"随机武器"和"手雷补给"两种奖励类型。宝箱框架（issue 08）已存在，本工单只追加两种新奖励。

## 前置依赖

- [ ] issue 08（宝箱框架 + `CHEST_REWARD_POOL` + `apply_chest_reward()` 方法）
- [ ] issue 19（20 把枪 `.tres` 存在）
- [ ] issue 21（弹药池 `ammo_reserve` + 武器槽管理）
- [ ] issue 23（手雷系统 `grenades` 字典）

## 验收标准

### 随机武器奖励

- [ ] `run_director.gd` 的 `CHEST_REWARD_POOL` 中追加 `random_weapon` 条目
- [ ] 抽卡逻辑：从 20 把枪池中按稀有度加权随机抽 1 把：
  - 低档（cost ≤ 70）：60% 权重
  - 中档（cost 71–120）：25% 权重
  - 高档（cost > 120）：15% 权重
- [ ] `apply_chest_reward("random_weapon")`：
  - 有空槽 → 直接装填到第一个空槽，耐久满
  - 3 槽全满 → 弹出替换对话框（复用商店替换 UI 逻辑）
- [ ] 不抽玩家已装备的同款枪（可选优化，v1 可略）

### 手雷补给奖励

- [ ] `CHEST_REWARD_POOL` 中追加 `grenade_supply` 条目
- [ ] `apply_chest_reward("grenade_supply")`：
  - EMP +1、破片 +1
  - 不超过 `max_grenades = 5`
  - 若已达上限 → 改为金币补偿（如 30 金）或跳过该条目

### 测试

- [ ] `tests/test_chest_expansion.gd`：
  - 模拟宝箱抽 `random_weapon` 100 次 → 断言低/中/高档分布接近 60/25/15
  - 空槽开箱 → 断言武器入槽
  - 满槽开箱 → 断言弹出替换对话框
  - 手雷已满 5 颗开箱 `grenade_supply` → 断言不超上限
