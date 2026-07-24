# 04 — 子弹商店摊位（物理 walk-in）

Status: ready-for-agent
Type: task
Refs: PRD.md, ADR 012, ADR 013, ADR 015, CONTEXT.md「Shop / gold_cost_per_bullet / Gold / Pause Semantics」

## 描述

在竞技场中放置一个固定位置的子弹商店摊位（`Shop Station`）。玩家走入其触发区即暂停游戏并打开购买 UI，按每枪金价补 `reserve` 备弹，离开恢复。

## 验收标准

### Shop Station 节点
- 竞技场场景新增 `Shop Station` 节点：`Area3D` 触发区 + 可视化模型（建议复用现有素材或简单占位，如发光柱/箱子）。
- `Area3D` 的 `body_entered` 检测 `"player"` 组进入 → 打开 Shop UI 并暂停。

### 暂停行为（见 ADR 015）
- 进入触发区 → `get_tree().paused = true` → 打开 Shop UI。
- Shop UI 根节点 `process_mode = PROCESS_MODE_WHEN_PAUSED`（暂停期间可点击）。
- 进入时 `Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)`；关闭时 `MOUSE_MODE_CAPTURED`。
- RunDirector 触发暂停前检查 `get_tree().paused`，若已暂停（如升级中）则忽略本次 shop 进入，避免叠加。

### Weapon 资源扩展
- [scripts/weapon.gd](file:///g:/work/Starter-Kit-FPS/scripts/weapon.gd) 的 Ammo 分组新增 `@export var gold_cost_per_bullet: int = 1`。
- 现有 `.tres` 武器文件需 backfill：blaster=1、blaster_repeater=2（若有其它武器按"强枪更贵"原则给值）。

### 购买 UI 与交互（新增）
- Shop UI 为 `Control`（`CanvasLayer` 下），列出玩家**当前持有**的武器（从 `player.weapons` 读取，非全部武器定义）。
- 每把武器一行：名称、当前 `reserve` / 有效上限、单发金价、`+1` 按钮、`+10` 按钮、`买满` 按钮。
- **购买步进**：`+1`（买 1 发）、`+10`（买 10 发）、`买满`（买到上限）。`+10` 在金币不足时自动降级为"买到买得起的数量"（不禁止，买多少算多少）；`买满` 同理。
- **金币不足**：若金币连 1 发都买不起，按钮 disable 并灰显，显示"金币不足"。
- **上限封顶**：购买后 `reserve` 不超过 `weapon.max_reserve + player.bonus_max_reserve`（issue 05 的升级 bonus，**不**改 Weapon 资源本身）。已满时按钮 disable 显示"已满"。
- 扣金币通过调用 `run_director.spend_gold(cost)`（RunDirector 提供，扣 `gold` 并发 `gold_changed`，不足返回 false）。

### 关闭机制（新增）
- 关闭方式：(a) 玩家走出 `Area3D`（`body_exited`）；(b) 按 ESC / 关闭按钮。
- 关闭 → `get_tree().paused = false` → 隐藏 Shop UI → 恢复鼠标捕获。
- 走出 Area3D 关闭时，若玩家在 UI 中正在点按钮，需保证点击不会落在已关闭的 UI 上（关闭即 `visible = false`）。

### 消费约束
- 金币只有此一个消费出口（升级不花金币）。
- 商店与 Intermission 解耦：可随时（含波次进行中）走入购买。

## 评论

- `+10` 降级而非禁止，避免玩家来回点 `+1` 的乏味体验。
- 商店 UI 只列已持有武器，避免显示玩家未解锁的枪。
- `bonus_max_reserve` 来自 issue 05 的升级卡，本 issue 只负责"读取有效上限"，不实现 bonus 本身。
