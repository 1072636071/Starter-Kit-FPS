# 04 — 子弹商店摊位（物理 walk-in）

Status: resolved
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

## 答案

已实现，TDD 测试 [tests/test_shop.gd](file:///g:/work/Starter-Kit-FPS/tests/test_shop.gd) 全绿（42 项断言）。

实现要点：
- **Weapon 资源扩展**（[scripts/weapon.gd:37-38](file:///g:/work/Starter-Kit-FPS/scripts/weapon.gd#L37-L38)）：Ammo 分组新增 `@export var gold_cost_per_bullet: int = 1`。
- **.tres backfill**：
  - [weapons/blaster.tres:27](file:///g:/work/Starter-Kit-FPS/weapons/blaster.tres#L27) → `gold_cost_per_bullet = 1`
  - [weapons/blaster-repeater.tres:24](file:///g:/work/Starter-Kit-FPS/weapons/blaster-repeater.tres#L24) → `gold_cost_per_bullet = 2`（强枪更贵）
- **ShopStation 摊位**（[scripts/shop.gd](file:///g:/work/Starter-Kit-FPS/scripts/shop.gd) + [scenes/shop.tscn](file:///g:/work/Starter-Kit-FPS/scenes/shop.tscn)）：`Area3D` + 3×3×3 `BoxShape3D` 触发区 + 发光柱（`BoxMesh` + `emission`，`layers = 1` 作地标，主相机 + 小地图皆可见）。位置 `(60, 1.5, 60)` 竞技场东南角（避开 SP5=40,40 出生点）。
  - `body_entered` → `_on_body_entered`（[shop.gd:57-74](file:///g:/work/Starter-Kit-FPS/scripts/shop.gd#L57-L74)）：互斥检查 `get_tree().paused` → 暂停 → `_shop_ui.open(player, run_director)`。
  - `body_exited` → `_on_body_exited`（[shop.gd:76-85](file:///g:/work/Starter-Kit-FPS/scripts/shop.gd#L76-L85)）：调 `_shop_ui.close()`（汇入 closed 信号）。
  - `_on_shop_ui_closed`（[shop.gd:89-92](file:///g:/work/Starter-Kit-FPS/scripts/shop.gd#L89-L92)）：三个关闭来源（ESC / 关闭按钮 / body_exited）的统一恢复点 → `_active = false` + `get_tree().paused = false`。
  - 通过 group `"shop_ui"` / `"run_director"` 在 `call_deferred` 中查找依赖（生产环境），测试用 `set_shop_ui` / `set_run_director` 直接注入。
- **ShopUI 购买 UI**（[scripts/shop_ui.gd](file:///g:/work/Starter-Kit-FPS/scripts/shop_ui.gd) + [scenes/shop_ui.tscn](file:///g:/work/Starter-Kit-FPS/scenes/shop_ui.tscn)）：`Control`，`process_mode = WHEN_PAUSED`（暂停期间可点击），挂在 HUD 下。
  - **UI 结构**（[shop_ui.gd:159-209](file:///g:/work/Starter-Kit-FPS/scripts/shop_ui.gd#L159-L209)）：`PanelContainer` → `VBoxContainer`（标题 / 金币 Label / 武器行 VBox / 关闭按钮）。每把武器一行 `HBoxContainer`：名称 / 当前 reserve/cap / 单价 / +1 / +10 / 买满 / 状态 Label。
  - **购买步进**（`buy_bullets` [shop_ui.gd:110-146](file:///g:/work/Starter-Kit-FPS/scripts/shop_ui.gd#L110-L146)）：`+1` 买 1 发、`+10` 买 10 发（金币不足自动降级到 `gold / cost_per`，不禁止）、`买满` 买到 `headroom` 发（同样降级）。
  - **上限封顶**（[shop_ui.gd:84-89](file:///g:/work/Starter-Kit-FPS/scripts/shop_ui.gd#L84-L89)）：`effective_cap = player.effective_max_reserve(weapon) = weapon.max_reserve + player.bonus_max_reserve`（复用 issue 05 的 player API，不改 Weapon 资源）。
  - **金币不足**：`can_afford(weapon_index, 1) == false` 时按钮 disable + 状态 Label 显示"金币不足"。**已满**时按钮 disable + 显示"已满"。
  - **扣金币**：`run_director.spend_gold(actual * cost_per)`，不足返回 false 不扣；扣成功后 `player.reserve[idx] += actual` + 广播 `_emit_ammo_updated()` 让 HUD 同步。
  - **关闭**（[shop_ui.gd:76-82](file:///g:/work/Starter-Kit-FPS/scripts/shop_ui.gd#L76-L82) + [shop_ui.gd:330-335](file:///g:/work/Starter-Kit-FPS/scripts/shop_ui.gd#L330-L335)）：ESC（复用 `mouse_capture_exit` 动作，PAUSABLE 玩家冻结不冲突）/ 关闭按钮 / body_exited 三路汇入 `close()` → `visible = false` + `Input.MOUSE_MODE_CAPTURED` + `emit closed`。
  - **gold_changed 绑定延迟到 open()**（[shop_ui.gd:71-73](file:///g:/work/Starter-Kit-FPS/scripts/shop_ui.gd#L71-L73)）：`_run_director` 注入后再绑，避免重复连接。
- **main.tscn 集成**（[scenes/main.tscn:12-13,167,239-240](file:///g:/work/Starter-Kit-FPS/scenes/main.tscn#L239-L240)）：`ShopUI` 挂在 `HUD` 下（属 `"shop_ui"` group），`ShopStation` 挂在 `Main` 下（位置 `(60, 1.5, 60)`）。

测试：`godot --headless res://tests/test_shop.tscn --quit-after 600` → `[TEST] PASS — arena issue 04 shop station`（42 项断言：gold_cost_per_bullet 默认值 + .tres backfill、+1/+10/买满购买、金币不足降级、effective_cap 受 bonus_max_reserve 影响、close 隐藏 + closed 信号、ShopStation body_entered/body_exited 暂停/恢复、暂停期间购买、互斥：已暂停不重入）。

### 全测试套件回归
12 个测试文件中 11 个 PASS，仅 `test_minimap_t3` FAIL（已确认是 issue 02 的遗留回归——`Monsters` 节点改为 RunDirector 动态生成后，minimap.gd `_refresh_monsters` 在场景树静态查找时找不到怪物。与 issue 04 无关，已在 issue 02 复盘中记录）。

### 已知边界
- 暂停期间物理冻结，玩家无法走动，故 `body_exited` 在暂停态实际不会触发；关闭主路径是 ESC / 关闭按钮。测试用 `_on_body_exited` 白盒调用验证 handler 逻辑。
- 若 add_xp 在商店暂停期间触发升级（罕见，需玩家走入商店后立即击杀奖励 XP），当前简单覆盖暂停并弹升级卡；ADR 015 的"延迟到 unpause 后再弹"作为边界情况记录，v1 不实现（与 issue 05 一致）。
