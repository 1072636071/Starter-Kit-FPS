# 02 — 波次刷怪控制器（RunDirector）

Status: ready-for-agent
Type: task
Refs: PRD.md, ADR 009, ADR 015, CONTEXT.md「Wave / Escalation / Wave Spawn / Intermission / Spawn Point / Pause Semantics」, Q6, Q8, issue 08（Chest）

## 描述

新增竞技场运行编排器 `RunDirector`（作为 `Main` 子节点，挂在 `Monsters` 旁的兄弟节点；`Main` 根当前无脚本，RunDirector 是首个"游戏导演"逻辑），负责波次推进、难度递增、清场检测、波间手动开波、本局状态（金币 / 经验 / 等级 / 击杀 / RNG）。这是整个循环的最高层 seam。

## 验收标准

### 波次数量与类型
- 第 N 波怪物数量 = `4 + 2×(N-1)`。
- 怪物类型分阶段解锁，**解锁后的类型比例**（按数量取整，余数补到已解锁的最弱类型）：
  - 1–3 波：100% `monster_melee`。
  - 4–6 波：60% `monster_melee` / 40% `monster_ranged`。
  - 7+ 波：50% `monster_melee` / 30% `monster_ranged` / 20% `enemy`（飞行）。
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
- 暴露信号：`wave_started(wave_number)`、`wave_cleared(wave_number, cleared_by_timeout: bool)`（供 HUD 显示波数）。

### 本局状态与 RNG（新增）
- RunDirector 持有本局状态：`gold: int`、`xp: int`、`level: int`、`wave: int`、`kills: int`、`gold_earned_total: int`（用于 issue 06 结算"累计金币"=本局总赚取，非当前余额）。
- `@export var rng_seed: int = 0`（0 = 随机）；`var rng: RandomNumberGenerator`，`_ready()` 中 `rng = RandomNumberGenerator.new(); rng.seed = rng_seed if rng_seed != 0 else Time.get_ticks_usec()`。
- 暴露 `rng` 供 issue 03（血包掉率）与 issue 05（抽卡）使用（`run_director.rng.randf()` 等）。
- 暴露信号：`gold_changed(amount: int)`、`xp_changed(amount: int, threshold: int)`、`level_up_offered(choices: Array)`、`game_over(stats: Dictionary)`、`kills_changed(count: int)`（供 HUD/测试）。

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
