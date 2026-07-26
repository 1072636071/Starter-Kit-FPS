# 06 — 商店重新定价 + HUD 货币显示

Status: done
Type: task
Refs: PRD.md, ADR 023, CONTEXT.md「Shop / Silver / Copper」

## 实现记录

- `shop_ui.gd` AMMO_CONFIG 价格更新：手枪弹 24铜, 步枪弹 60铜, 霰弹 80铜, 狙击弹 80铜, 能量电池 60铜, 榴弹 100铜
- GRENADE_CONFIG: EMP 3银, 破片 2银
- 武器价格: `weapon_cost/10` 显示为 "X 金"，购买 `spend_copper(price*10000)`
- 弹药: 显示 "X 铜"，购买 `spend_copper(price)`，弹药添加到背包而非 `ammo_reserve`
- 手雷: 显示 "X 银"，购买 `spend_copper(price*100)`
- `_gold_label` 改为 `format_currency()` 混合格式，监听 `currency_changed`
- 武器/弹药/手雷三区按钮状态刷新方法拆分（武器/弹药/手雷各独立方法，适配不同货币单位）
- `hud.gd`: 货币显示改为 `format_currency()` 格式
- `chest_ui.gd`: 取消按钮文字 "30 金补偿" → "3 金补偿"
- `game_over.gd`: `gold_earned_total`→`copper_earned_total`
- `weapon_pickup.gd`: 弹药初始化改用 `backpack_add`

## 描述

更新商店弹药/手雷/武器价格为金银铜体系，更新 HUD 货币显示为混合金银铜格式。

## 验收标准

### 商店弹药价格更新

`shop_ui.gd` 的 `AMMO_CONFIG`：

| 弹种 | 旧价（金） | 新价（铜） |
|------|----------|----------|
| 手枪弹捆 24 发 | 1 | 24 |
| 步枪弹捆 20 发 | 2 | 60 |
| 霰弹捆 8 发 | 3 | 80 |
| 狙击弹捆 4 发 | 4 | 80 |
| 能量电池捆 12 发 | 3 | 60 |
| 榴弹捆 2 发 | 5 | 100 |

### 商店手雷价格更新

`shop_ui.gd` 的 `GRENADE_CONFIG`：

| 手雷 | 旧价（金） | 新价（银） |
|------|----------|----------|
| EMP | 25 | 3 |
| 破片 | 20 | 2 |

### 商店武器价格更新

- `Weapon.weapon_cost` 整体 ÷10（原 30–175 → 3–18）
- 武器区显示 "X 金"
- 手雷区显示 "X 银"
- 弹药区显示 "X 铜"

### 商店金币标签

- `_gold_label` 改为显示金银铜混合格式：调用 `_run_director.format_currency()`
- 监听 `currency_changed` 而非 `gold_changed`

### 商店购买逻辑

- `_buy_ammo`: 用 `spend_copper(price)` 替代 `spend_gold(price)`
- `_buy_grenade`: 价格单位是银币，调用 `spend_copper(price * 100)`（内部转铜）
- `_buy_weapon`: 价格单位是金币，调用 `spend_copper(price * 10000)`（内部转铜）
- 金币不足提示改为按对应货币层级显示

### HUD 货币显示

`hud.gd`：
- 现有金币显示改为金银铜混合格式
- 监听 `currency_changed(copper)` 信号
- 调用 `run_director.format_currency()` 获取显示字符串
- 格式示例："🪙 1金 23银 45铜"

### 宝箱 UI 适配

`chest_ui.gd` 中如有金币引用也改为新格式。
