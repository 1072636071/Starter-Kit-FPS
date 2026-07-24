# ADR 010: 护盾作为血量前的可再生吸收层

## 决策

伤害采用 **方案 A：护盾优先吸收 + 延时自动恢复**。一次伤害先扣 `Shield`，护盾不足以覆盖的部分才**溢出**扣 `Health`；护盾在"最后一次受击后 `shield_regen_delay` 秒"开始以 `shield_regen_rate` 自动恢复（**战斗中亦可回**，不只在间歇）；`Health` 仅由血包（Health Pack）恢复，不自动恢复。

## 背景

`player.gd` 现有 `damage(amount)` 直接扣 `health`，无护盾；`health < 0` 时调用 `get_tree().reload_current_scene()`。用户要求："人物有血量和护盾，护盾会自动恢复。血量需要血包。"需决定护盾与血量的关系及恢复方式。

## 替代方案

| 方案 | 描述 | 否决原因 |
|------|------|----------|
| **A. 护盾优先吸收 + 延时自动恢复（选中）** | 伤害先扣护盾，溢出扣血量；受击延时后自动回 | 最贴合描述；改动集中在 `damage()` 一处（先减 shield 再减 health），最简单 |
| B. 护盾 / 血量平行独立 | 护盾只挡特定伤害类型（如远程弹体），其余直扣血量 | 机制化但 v1 复杂、收益不明显 |
| C. 护盾 = 一次性临时血 | 进局给一层临时血、不自动回、只靠血包补 | 与"护盾自动恢复"矛盾，排除 |

## 影响

- `player.gd` 新增 `shield: int`、`shield_max`、`shield_regen_delay`、`shield_regen_rate`；`damage(amount)` 改为**先减 `shield`、溢出再减 `health`**。
- 新增护盾恢复计时：最后一次受击后启动 `shield_regen_delay` 倒计时，到点每帧按 `shield_regen_rate` 回盾（受击即重置倒计时）。
- HUD 需新增**护盾条**（现有仅 `health` 条，由 `health_updated` 信号驱动）。
- 死亡判定仍为 `health <= 0`（护盾归零不致死，只有血量归零才结束本局）。
- 初值（均可 `@export` 调参）：`shield_max = 50`、`shield_regen_delay = 3s`、`shield_regen_rate = 10/s`。
