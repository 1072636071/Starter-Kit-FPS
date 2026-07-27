# ADR 012: 金币按"发"购买备弹

**状态**：已废弃（被 [ADR 022](022-enemy-weapon-expansion.md) + [ADR 023](023-currency-backpack-system.md) 取代）

## 原决策

金币在商店中按"发"购买备弹，每把枪有独立金价 `gold_cost_per_bullet`，受 `max_reserve` 封顶。

## 废弃原因

ADR 022 引入 6 种弹药类型 + 按捆售卖；ADR 023 进一步引入三级货币（金银铜），弹药以铜币定价。`gold_cost_per_bullet` 字段已退役，改为弹药捆模式（手枪弹捆 24 铜、步枪弹捆 60 铜等，详见 ADR 023）。
# ADR 012: 金币按"发"购买备弹（per-weapon 金价，受 max_reserve 封顶）

## 决策

金币在商店中**按"发"购买 `reserve`（背包备弹）**，每把枪有独立金价 `gold_cost_per_bullet`；购买受该枪 `max_reserve` 上限约束（买满即止）。换弹 `reserve → magazine` 链路不变，金币仅"往背包加子弹"。

## 背景

现有弹药为每枪独立的 `magazine`（弹匣）+ `reserve`（背包备弹），上限 `max_reserve`（`Weapon` 资源配置）。用户："金币用来购买子弹。"需决定金币与现有弹药体系的映射。

## 替代方案

| 方案 | 描述 | 否决原因 |
|------|------|----------|
| **A. 金币按发买 reserve（选中）** | 金币补 `reserve`，每发金价，受 `max_reserve` 封顶 | 最直接对应"买子弹"；复用现有换弹链路，零侵入 |
| B. 金币买整包 | 一次买 +N 发或 +1 弹匣容量 | 批量顺手但多一层抽象，与字面略远 |
| C. 金币买特殊 / 无限弹药 | 偏离字面 | v1 不做 |

## 影响

- `Weapon` 资源（`scripts/weapon.gd`）新增 `gold_cost_per_bullet: int`。初值：`blaster = 1`、`blaster_repeater = 2`（强枪更贵）。
- 商店购买逻辑：扣金币、加 `reserve[index]`（不超过 `max_reserve`）。
- 金币**只有这一个消费出口**（升级由 XP 驱动，不花金币）。
- 购买发生在 Intermission 的商店 UI（具体形式见后续决策）。
