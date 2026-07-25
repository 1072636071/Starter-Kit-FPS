# 02 — 波次刷怪控制器（RunDirector）

Status: resolved
Type: task
Refs: PRD.md, ADR 009, ADR 015, CONTEXT.md「Wave / Escalation / Wave Spawn / Intermission / Spawn Point / Pause Semantics」, Q6, Q8, issue 08（Chest）

## 描述

新增竞技场运行编排器 `RunDirector`（作为 `Main` 子节点，挂在 `Monsters` 旁的兄弟节点；`Main` 根当前无脚本，RunDirector 是首个"游戏导演"逻辑），负责波次推进、难度递增、清场检测、波间手动开波、本局状态（金币 / 经验 / 等级 / 击杀 / RNG）。这是整个循环的最高层 seam。

## 验收标准

### 波次数量与类型（已由 ADR 018 改为分数预算制）
- 第 N 波怪物由**分数预算**决定：`wave_budget(N) = 60 × 1.2^(N-1)`。
- 每种怪物有刷出成本：`monster_melee`=5, `monster_ranged`=8, `enemy`=10。
- 刷怪时从可用类型中随机选取，直到总成本 ≥ 预算。
- 怪物类型分阶段解锁（保留）：
  - 1–3 波：仅 `monster_melee`。
  - 4–6 波：`monster_melee` + `monster_ranged`。
  - 7+ 波：全部三种类型。
- 每波怪物在波开始时**一次性全刷**入竞技场。

### 出生点策略（新增）
- 在 `main.tscn` 的 `Main` 下新增 `SpawnPoints` 节点（`Node3D`），含 ≥ 8 个 `Marker3D` 子节点，沿竞技场四周/边缘布置（避开玩家出生点与商店摊位）。
- RunDirector 持有 `@export var spawn_points: Array[Marker3D]`（或在 `_ready()` 自动收集 `SpawnPoints` 下的所有 Marker3D）。
- 刷怪时：打乱出生点顺序，按需求数量依次取点；若需求 > 出生点数，循环取点并叠加 ±2m 随机抖动避免精确重叠。
- 怪物在出生点 `Marker3D.global_position` 处 `instantiate()` 对应场景，作为 `Monsters` 节点子节点加入树。

### 清场检测（新增）
- RunDirector 维护 `alive_count: int`，每刷一只怪 `+= 1`。
- 监听每只怪物的 `died` 信号（issue 03 新增），收到时 `alive_count -= 1`。
- `alive_count == 0` → 发射 `wave_cleared(wave_number)`、进入 Intermission。
- **不使用** `Monsters.get_child_count()` 检测——`monster_melee`/`ranged` 的 `destroy()` 有延迟 `queue_free()`（死亡动画期间仍在树上），会导致误判。

### 卡怪兜底（新增）
- 每波开始时记录 `wave_start_time`。
- 若 `wave_timeout = 120s`（`@export`，可调）后仍未清场，RunDirector 对剩余存活怪物**强制调用 `destroy()`**（触发 `died` 信号、正常结算奖励），避免卡怪软锁。
- 兜底触发时在 `wave_cleared` 信号参数中带 `cleared_by_timeout: bool` 标志（供 HUD/日志区分）。

### Intermission 与开波
- Intermission 中下一波由**玩家手动确认**开始（非倒计时自动）。
- 开局 UX：场景加载后即进入"波 0 Intermission"，显示"开始第 1 波"提示（HUD issue 07 实现），玩家确认后才刷第一波。
- "开始波次"按键定义：新增 `start_wave` 输入动作（建议绑定 Enter 或 F 键，避免与 `interact`/E 键冲突——E 留给宝箱 issue 08 与未来其它交互）。
- 暴露信号：`wave_started(wave_number)`、`wave_cleared(wave_number, cleared_by_timeout: bool)`（供 HUD 显示波数）。

### 宝箱生成钩子（issue 08 集成）
- `wave_cleared` 信号发射后，RunDirector 检查场上是否已有未开宝箱；若无，`instantiate(chest.tscn)` 一个宝箱（位置：竞技场中央或玩家前方 3m）。
- 宝箱由 issue 08 实现具体实体与开箱流程；RunDirector 只负责"何时何地生成"与"避免堆积"。
- 宝箱存在期间，Intermission 仍可手动开下一波（玩家可不开宝箱直接开下一波，但下一波清场时若仍有未开宝箱则不重复生成）。

### 本局状态与 RNG（新增）
- RunDirector 持有本局状态：`gold: int`、`xp: int`、`level: int`、`wave: int`、`kills: int`、`gold_earned_total: int`（用于 issue 06 结算"累计金币"=本局总赚取，非当前余额）。
- `@export var rng_seed: int = 0`（0 = 随机）；`var rng: RandomNumberGenerator`，`_ready()` 中 `rng = RandomNumberGenerator.new(); rng.seed = rng_seed if rng_seed != 0 else Time.get_ticks_usec()`。
- 暴露 `rng` 供 issue 03（血包掉率）、issue 05（抽卡）、issue 08（宝箱抽卡）使用（`run_director.rng.randf()` 等）。
- 暴露信号：`gold_changed(amount: int)`、`xp_changed(amount: int, threshold: int)`、`level_up_offered(choices: Array)`、`game_over(stats: Dictionary)`、`kills_changed(count: int)`（供 HUD/测试）。
- 暴露 public 方法供 issue 04（商店）与 issue 08（宝箱）调用：
  - `func add_gold(amount: int)`：加金币（`gold += amount; gold_earned_total += amount; gold_changed.emit(gold)`）。
  - `func spend_gold(cost: int) -> bool`：扣金币，不足返回 false 不扣；足够则扣并发 `gold_changed`。
  - `func add_xp(amount: int)`：加经验，跨阈值触发 issue 05 升级流程（内部级联：暂停 → 弹升级卡 → 选完恢复）。
  - `func add_kills(count: int = 1)`：加击杀计数（供 issue 03 调用）。

### 移除手放怪（新增）
- `main.tscn` 现有 `Monsters` 节点下的 4 个手放实例（MeleeA/B、RangedA/B）**移除**——波次由 RunDirector 全权负责刷怪。`Monsters` 节点保留为空容器，作为运行时刷怪父节点。

### 暂停行为
- RunDirector 为 `PROCESS_MODE_PAUSABLE`（见 ADR 015）：商店/升级/死亡暂停期间不推进波次、不倒计时卡怪兜底。
- 触发新暂停源（如升级）前检查 `get_tree().paused`，已暂停则不叠加。

### 复用约束
- 复用现有三种怪物场景与导航（NavMesh / NavigationAgent3D），不改动怪物 AI 本身。

## 评论

- 出生点 `Marker3D` 的具体坐标在实现时根据竞技场几何布置，验收只检查"有 ≥ 8 个点、刷怪落在 NavMesh 可达区域"。
- `wave_cleared` 信号签名变更（加了 `cleared_by_timeout`）需同步到 issue 07 HUD 监听。

## 答案

已实现于 [scripts/run_director.gd](file:///g:/work/Starter-Kit-FPS/scripts/run_director.gd)，TDD 测试 [tests/test_run_director.gd](file:///g:/work/Starter-Kit-FPS/tests/test_run_director.gd) 全绿（38 项断言）。

实现要点：
- **RunDirector**（[run_director.gd](file:///g:/work/Starter-Kit-FPS/scripts/run_director.gd)）挂在 `Main` 下，`_ready()` 自动收集 `SpawnPoints` / `Monsters`，监听 `player.died` → `game_over`。
- **波次组成**（[run_director.gd:250-282](file:///g:/work/Starter-Kit-FPS/scripts/run_director.gd#L250-L282)）：分数预算制——`MONSTER_COST` 常量（melee=5/ranged=8/enemy=10）、`wave_budget(N) = 30 × 1.5^(N-1)`、`compute_wave_composition` 随机选取至总成本 ≥ 预算。类型分阶段解锁（1-3 melee only、4-6 +ranged、7+ +enemy）。参见 [ADR 018](file:///g:/work/Starter-Kit-FPS/docs/adr/018-score-based-wave-composition.md)。
- **出生点**（[main.tscn:192-216](file:///g:/work/Starter-Kit-FPS/scenes/main.tscn#L192-L216)）：`SpawnPoints` 节点下 8 个 `Marker3D` 沿竞技场四周布置；刷怪时用本局 rng 打乱出生点顺序，需求 > 出生点数时循环取点并叠加 ±2m 抖动。
- **清场检测**（[run_director.gd:218-227](file:///g:/work/Starter-Kit-FPS/scripts/run_director.gd#L218-L227)）：维护 `alive_count`，监听每只怪物 `died` 信号减 1，归零 → `wave_cleared(wave, cleared_by_timeout)`。不依赖 `get_child_count()`（避免 die 动画延迟 queue_free 误判）。
- **卡怪兜底**（[run_director.gd:250-274](file:///g:/work/Starter-Kit-FPS/scripts/run_director.gd#L250-L274)）：`wave_timeout = 120s`（@export），到点 `_force_clear_wave()` 强制 `destroy()` 剩余怪物（触发 died → 正常结算）；防御性兜底——若 destroy 后 alive_count 仍 > 0 则直接 `_end_wave`。`_cleared_by_timeout` 标志通过信号参数传出。
- **Intermission & 开波**（[run_director.gd:133-149](file:///g:/work/Starter-Kit-FPS/scripts/run_director.gd#L133-L149)）：`start_next_wave()` 由 `start_wave` 输入动作（F 键）触发；暂停期间不开波。
- **本局状态 & RNG**（[run_director.gd:41-49](file:///g:/work/Starter-Kit-FPS/scripts/run_director.gd#L41-L49)）：`gold/xp/level/wave/kills/gold_earned_total`；`rng_seed`（0=随机），`rng` 暴露供 issue 03/05/08。
- **公共方法**（[run_director.gd:92-126](file:///g:/work/Starter-Kit-FPS/scripts/run_director.gd#L92-L126)）：`add_gold` / `spend_gold` / `add_xp`（跨阈值触发 issue 05 升级流程，当前发空 choices 信号）/ `add_kills`。
- **宝箱生成钩子**（[run_director.gd:311-324](file:///g:/work/Starter-Kit-FPS/scripts/run_director.gd#L311-L324)）：`wave_cleared` 后检查场上宝箱，若无则 `instantiate(chest.tscn)`（chest_scene 为 null 则跳过，待 issue 08 接入）。
- **移除手放怪**：`main.tscn` 的 `Monsters` 节点已清空为容器，由 RunDirector 全权刷怪。
- **输入动作**（[project.godot](file:///g:/work/Starter-Kit-FPS/project.godot)）：新增 `start_wave` 绑定 F 键。

测试：`godot --headless res://tests/test_run_director.tscn --quit-after 600` → `[TEST] PASS`（含状态初值、金币方法、XP 阈值、波次组成、奖励结算、血包掉落、清场检测、真实刷怪清场、卡怪兜底 7 大场景）。

### 调试笔记（卡怪兜底测试）
测试 7（timeout fallback）曾因 GDScript lambda 局部变量按值捕获导致计数器不更新（`timeout_cleared` 局部变量在 lambda 内 `+=1` 不反映到外部）。修复方式：改用 `_counters` Dictionary（引用类型）计数，与 `test_arena_shield.gd` 同类注释一致。生产代码（`_force_clear_wave`）本身正确，另加防御性兜底以防 died 信号异常未触发。
