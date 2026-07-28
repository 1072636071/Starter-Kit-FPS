# 警戒翻倍 + 三级货币背包 — Issue 索引

功能目录：`.scratch/currency-backpack/`
整体规格：[PRD.md](./PRD.md)
领域词汇：`CONTEXT.md`「Chain Aggro / Gold / Silver / Copper / Backpack / Backpack Weight / Ammo Slot / B Key / T Key」
架构决策：`docs/adr/023`（三级货币+背包）、`017`（敌人AI）

| 状态 | Issue | 主题 | 关联 ADR |
|------|-------|------|----------|
| ready-for-agent | [01-alert-range-double.md](./issues/01-alert-range-double.md) | 全敌人警戒范围翻倍 | 017 |
| ready-for-agent | [02-currency-conversion.md](./issues/02-currency-conversion.md) | RunDirector 三级货币核心 + 击杀奖励换算 | 023 |
| ready-for-agent | [03-backpack-data-model.md](./issues/03-backpack-data-model.md) | Player 背包数据模型 + 重量系统 | 023 |
| ready-for-agent | [04-ammo-slots-reload.md](./issues/04-ammo-slots-reload.md) | 10 备弹槽 + 换弹逻辑改造 | 023 |
| ready-for-agent | [05-backpack-ui.md](./issues/05-backpack-ui.md) | B 键背包 UI + T 键整理动画 | 023 |
| ready-for-agent | [06-shop-hud-update.md](./issues/06-shop-hud-update.md) | 商店重新定价 + HUD 货币显示 | 023 |
| ready-for-agent | [07-upgrade-backpack-weight.md](./issues/07-upgrade-backpack-weight.md) | 升级池新增背包负重 | 023 |

## 跨 issue 关键约定

- **货币内部统一铜币**：issue 02 定义 `copper: int` 和 `format_currency()`，issue 06 的商店和 HUD 依赖此格式。
- **背包数据在 Player**：issue 03 定义背包/重量/备弹槽数据结构，issue 04 和 05 读取和修改此数据。
- **换弹改为消费备弹槽**：issue 04 改造 `action_reload()`，不再读 `ammo_reserve`（该字段保留但废弃）。
- **备弹槽只在背包 UI 中分配**：issue 05 是唯一修改备弹槽内容的入口，issue 04 只消费不修改。
- **B/T 键与现有键位无冲突**：B 键当前空闲；T 键专用于"整理"语义，与 B 键（打开/关闭背包）解耦。
- **整理动画 1.5s 期间**：`_is_packing = true`，禁止射击/换弹，允许移动。
- **暂停语义**：背包 UI 为 `PROCESS_MODE_WHEN_PAUSED`，与商店/升级/死亡暂停兼容（参考 ADR 015）。
