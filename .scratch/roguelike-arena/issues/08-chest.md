# 08 — 清场宝箱（Chest）

Status: resolved
Type: task
Refs: PRD.md, ADR 015, CONTEXT.md「Chest / Chest Reward」, issue 02 / 03 / 07

## 描述

借鉴《元气骑士》清房间掉宝箱的设计：每波 `wave_cleared` 后在竞技场中央生成 1 个宝箱，玩家走近按 E 开启 → 暂停 → 弹 3 选 1 奖励，选 1 即时生效。给"清场→手动开下一波"之间补一个即时反馈断点，让清场有肉鸽式的大奖励获得感。

与 issue 03（血包小概率掉落）互补：血包是击杀小奖励（heal 25、单发），宝箱是清场大奖励（多选 1、按波次缩放）。

## 验收标准

### 宝箱实体
- 新建 `scenes/chest.tscn`（根节点 `Area3D` + 可视化模型，建议复用现有素材或简单占位如发光箱子）+ `scripts/chest.gd`。
- `Area3D` 检测 `"player"` 组进入 / 离开。
- 宝箱为静态可交互物，**不自动开**——玩家必须按 E。
- `process_mode = PROCESS_MODE_PAUSABLE`（默认）；开箱暂停期间自身冻结（但 UI 是 WHEN_PAUSED）。
- 视觉提示：玩家在 Area3D 内时宝箱做轻微浮动 Tween + HUD 提示"按 E 开启"（issue 07）。

### 生成时机与位置
- RunDirector 监听自身的 `wave_cleared(wave_number, cleared_by_timeout)` 信号 → 在竞技场中央（或玩家当前位置前方 3m）`instantiate(chest.tscn)` 一个宝箱。
- `cleared_by_timeout = true` 时也生成（玩家还是清了场）。
- 同一时间场上最多 1 个宝箱（若上一波宝箱未开，新波清场时不重复生成，避免堆积——但实际玩家大概率会先开宝箱再开下一波，属罕见边界）。

### 开箱流程
1. 玩家进入宝箱 `Area3D` → HUD 显示"按 E 开启"（issue 07）。
2. 玩家按 E → `get_tree().paused = true` → 打开 Chest UI（3 选 1）。
3. Chest UI 根节点 `process_mode = PROCESS_MODE_WHEN_PAUSED`（见 ADR 015）。
4. 进入时 `Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)`；选奖励后 `MOUSE_MODE_CAPTURED`。
5. 玩家选 1 → apply 奖励 → `get_tree().paused = false` → 隐藏 Chest UI → 宝箱 `queue_free()`。
6. 关闭机制：只能选 1（无 ESC 取消——宝箱必须开，避免玩家囤积）。

### 奖励池（3 选 1 不重复）
- 使用 `run_director.rng` 从奖励池抽 3 个不重复项呈现；池不足 3 时降级（抽全部）。
- 奖励池初版（均 `@export` 可调）：
  - **金币大礼包**：`gold_bonus = 20 + 5 × wave`（按波次缩放——与 issue 03 击杀奖励"不缩放"区别：宝箱是大奖励，缩放合理）。Apply：`run_director.add_gold(gold_bonus)`。
  - **血包 ×3**：一次性给 3 个血包的回血量（`heal_amount × 3 = 75`），直接调用 `player.heal(75)`（受 `max_health` 上限）。与 issue 03 的单个血包（25）互补。
  - **经验大礼包**：`xp_bonus = 15 + 3 × wave`。Apply：`run_director.add_xp(xp_bonus)`（可能触发 issue 05 的升级，由 RunDirector 内部级联）。
  - **备弹补给**：玩家当前所有武器的 `reserve` 直接回满到 `weapon.max_reserve + player.bonus_max_reserve`（issue 05 的有效上限）。Apply：遍历 `player.weapons` 设 `reserve = effective_max`。
- "3 个不重复"指本次三张互不相同（不跨波记忆）。

### 信号
- 宝箱开启时发 `chest_opened(choices: Array)` 信号（供测试与 HUD）。
- 玩家选择后发 `chest_reward_selected(reward_id: StringName)` 信号。
- 信号由 RunDirector 暴露（宝箱实例 `queue_free()` 前发，确保 RunDirector 收到）。

### 暂停互斥（见 ADR 015）
- 开箱触发前检查 `get_tree().paused`：
  - 若已暂停（shop / level-up），不触发开箱（玩家需先处理完当前暂停 UI）。
  - 死亡时若宝箱存在，宝箱随场景 reload 一起消失（无需特殊处理）。

### 与 issue 02 的集成
- RunDirector 在 `wave_cleared` 后**先生成宝箱**，再进入 Intermission（玩家可先开宝箱、再手动开下一波）。
- Intermission 的"开下一波"按键与"开宝箱"按键**不同**：开宝箱用 `interact`（E 键，复用现有），开下一波用 `start_wave`（issue 02 定义）。
- 玩家可不开宝箱直接开下一波——宝箱保留在场上，下一波清场时若仍有未开宝箱，新宝箱不生成（避免堆积，见上）。

### 与 issue 03 血包的关系
- 血包（issue 03）：击杀小概率 10% 掉落，heal 25，despawn 15s。
- 宝箱（本 issue）：清场必给 1 个，3 选 1，可能含"血包 ×3"（heal 75）。
- 互补：血包是"运气好的小回血"，宝箱是"清场的大奖励"。

### 与 issue 05 升级卡的关系
- 升级卡：XP 跨阈值触发，3 选 1 永久增益。
- 宝箱：清场触发，3 选 1 即时奖励（金币/血/XP/备弹，无永久 buff）。
- 两者 UI 同模式（暂停 + 3 选 1），但触发来源与奖励性质不同。
- 宝箱的"经验大礼包"可能触发升级卡——RunDirector 内部级联：`add_xp` → 跨阈值 → 暂停升级 UI → 选完 → 恢复（此时宝箱 UI 已关闭，不冲突）。

## 评论

- 奖励池 4 项均为"即时结算"，不引入临时 buff 系统（避免 scope 蔓延）。未来若要加临时 buff（狂战/风行者等），可扩充奖励池 + 新建 buff 状态机。
- "按波次缩放"只对宝箱的金币/经验大礼包生效，不破坏 issue 03 的"击杀奖励不缩放"原则——宝箱是清场大奖励，缩放让后期宝箱更诱人。
- "必须选 1，无取消"防止玩家囤积宝箱（与"场上最多 1 个宝箱"双保险）。
- 备弹补给是"懒人选项"——直接回满，省去商店跑腿，但放弃金币/经验/血量增益，形成取舍。