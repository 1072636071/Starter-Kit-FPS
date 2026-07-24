# 07 — HUD 集成

Status: resolved
Type: task
Refs: PRD.md, ADR 015, CONTEXT.md 相关术语, issue 01 / 02 / 03 / 05 / 08

## 描述

在现有 HUD 上新增肉鸽竞技场所需的实时显示：护盾条、金币、经验/等级、波数指示、开局提示、宝箱提示。全部通过监听既有 / 新增信号实现，不引入新的游戏逻辑。

## 验收标准

- 新增**护盾条**，监听 `Player.shield_updated`（issue 01），与现有血条并列。
- 显示**金币**与**经验/等级**，监听 `RunDirector.gold_changed` / `xp_changed`（issue 02/03）。
- 显示**当前波数**，监听 `RunDirector.wave_started` / `wave_cleared(wave_number, cleared_by_timeout)`（issue 02，注意信号签名带 `cleared_by_timeout` 参数）。
- 显示**击杀数**（可选），监听 `RunDirector.kills_changed`（issue 02）。
- 新增**开局提示**："按 [start_wave 键] 开始第 1 波"——在波 0 Intermission 时显示，`wave_started(1)` 后隐藏（issue 02 的开局 UX）。
- 新增**波间提示**：`wave_cleared` 后显示"按 [start_wave 键] 开始下一波"，`wave_started(N)` 后隐藏。
- 新增**宝箱提示**（issue 08）：玩家进入宝箱 Area3D 时显示"按 [interact/E 键] 开启宝箱"，离开或宝箱被开过后隐藏。提示由宝箱实例发信号给 HUD（如 `chest_entered_range(chest_id)` / `chest_left_range`），或宝箱直接调 `hud.show_chest_prompt(true/false)`。
- "开始波次"按键由 issue 02 定义为 `start_wave` 输入动作（建议 Enter 或 F）；宝箱交互复用现有 `interact` 输入动作（E 键）。HUD 用 `InputMap.action_get_events()` 读键名显示。

### 暂停期间行为（见 ADR 015）
- HUD 为 `PROCESS_MODE_PAUSABLE`（默认）：暂停期间不接收新信号、不刷新。
- 暂停期间的 UI 刷新（如商店购买后金币显示更新、选卡后等级更新）由**对应的 WHEN_PAUSED UI 自身**调用 HUD 的更新方法（或直接读取状态刷新），不依赖 HUD 自己的 `_process`。
- 即：Shop UI 购买扣金币后，由 Shop UI 显式调用 `hud.update_gold(new_amount)`；Level Up UI 选卡后调用 `hud.update_level(new_level)`；Chest UI 选奖励后调用对应 `hud.update_gold/xp/...`。HUD 暴露这些 public 方法。
- Game Over UI 的战绩由 RunDirector 的 `game_over(stats)` 信号直接传 Dictionary 填充，不走 HUD。

### 现有 HUD 不变
- 不改动现有弹药 HUD / 小地图 HUD 的结构与行为。
- 所有新增 HUD 元素在非暂停态从信号驱动，零轮询。

## 评论

- HUD 暴露 `update_gold` / `update_xp` / `update_level` / `update_wave` / `update_kills` / `show_chest_prompt(bool)` 等 public 方法，供暂停态 UI 显式调用刷新——这是 ADR 015 暂停分层的必然结果（HUD 自己暂停了，得让别人推它）。
- "开始波次"与"开宝箱"按键提示的具体键名在实施时由 RunDirector 的输入动作决定（`start_wave` / `interact`），HUD 用 `InputMap.action_get_events()` 读键名显示。
