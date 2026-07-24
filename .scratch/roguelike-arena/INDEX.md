# Roguelite Arena — Issue 索引

功能目录：`.scratch/roguelike-arena/`
整体规格：[PRD.md](./PRD.md)
领域词汇：`CONTEXT.md`「Roguelike 竞技场系统」
架构决策：`docs/adr/009`（运行结构）、`010`（护盾）、`011`（升级卡）、`012`（金币买备弹）、`013`（商店摊位）、`014`（游戏结束）、`015`（暂停语义）

| 状态 | Issue | 主题 | 关联 ADR |
|------|-------|------|----------|
| ready-for-agent | [01-shield-layer.md](./issues/01-shield-layer.md) | 护盾吸收层 + 延时恢复 + died 信号 | 010, 015 |
| ready-for-agent | [02-wave-spawn-controller.md](./issues/02-wave-spawn-controller.md) | 波次刷怪控制器 / RunDirector + 出生点 + RNG | 009, 015, Q8 |
| ready-for-agent | [03-kill-rewards.md](./issues/03-kill-rewards.md) | 击杀奖励 + 血包实体 + monster_type | 015, Q7 |
| ready-for-agent | [04-bullet-shop-station.md](./issues/04-bullet-shop-station.md) | 子弹商店摊位 + 购买 UX | 012, 013, 015 |
| ready-for-agent | [05-level-up-cards.md](./issues/05-level-up-cards.md) | 升级三选一卡 + 叠加语义 + bonus 字段 | 011, 015, Q5, Q10 |
| ready-for-agent | [06-game-over-screen.md](./issues/06-game-over-screen.md) | 游戏结束界面 + 重开机制 | 014, 015 |
| ready-for-agent | [07-hud-integration.md](./issues/07-hud-integration.md) | HUD 集成 + 暂停刷新 | 015 |

## 跨 issue 关键约定（grill 补充）

- **died 信号**：issue 03 在三种怪物新增 `died(monster_type)`，issue 02 的 RunDirector 监听它做清场检测与奖励结算。issue 02 不重复定义此信号。
- **monster_type 取值**：`&"monster_melee"` / `&"monster_ranged"` / `&"enemy"`，与脚本基名一致，const 硬编码（不 export）。
- **Player bonus 字段**：issue 05 定义 `bonus_max_reserve` / `damage_multiplier` / `reload_time_multiplier` / `move_speed_bonus` / `shield_regen_rate_bonus` / `max_health`，issue 04 的商店上限检查与射击/换弹代码读取这些"有效值"。**不修改 Weapon 资源**。
- **重开机制**：issue 06 用 `reload_current_scene()`（gate 在 Game Over UI 后），天然重置 Player bonus 字段与 RunDirector 状态，无需手动 reset。
- **暂停互斥**：RunDirector 触发新暂停前检查 `get_tree().paused`；死亡优先级最高，会接管并隐藏 shop/level-up UI。
- **wave_cleared 信号签名**：`(wave_number, cleared_by_timeout: bool)`，issue 02 定义、issue 07 HUD 监听需同步。
