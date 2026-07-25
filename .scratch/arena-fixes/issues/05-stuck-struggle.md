# 05 — 建筑缝隙卡住：惩罚性慢推回

Status: ready-for-agent

## 问题陈述

玩家在城市地图中战斗时，可以跳入相邻建筑之间的狭窄缝隙（0.6m~1m+）。一旦进入，胶囊体碰撞被两侧墙壁夹住，水平移动完全被阻挡，玩家卡死——只能退出游戏或等待坠落超时重置。这是一个破坏游戏节奏的软锁。

## 解决方案

不封堵缝隙（保留城市视觉完整性），而是将"卡住"转化为有代价的游戏体验：玩家卡住后进入惩罚状态（不能移动/跳跃，成为固定靶），屏幕提示按 G 挣扎，按下后以极慢速度（0.5 m/s）沿进入方向反向推出。卡住期间可被敌人攻击，形成"不要跳进缝隙"的自然学习循环。

## 用户故事

1. 作为玩家，我想要在跳入建筑缝隙后得到明确的反馈提示，以便我知道自己卡住了以及如何脱困
2. 作为玩家，我想要在卡住时仍能转动视角观察周围，以便评估战场态势和敌人位置
3. 作为玩家，我想要在卡住时仍能射击，以便在被卡住时保留一定的反击能力
4. 作为玩家，我想要按 G 键触发挣扎脱困，以便主动选择脱困时机而非被动等待
5. 作为玩家，我想要在挣扎推出时感受到明显的缓慢，以便理解这是对冒进行为的惩罚
6. 作为玩家，我想要在正常靠墙行走时不会误触发卡住状态，以便不影响正常的贴墙机动
7. 作为玩家，我想要在卡住期间被敌人攻击时正常受伤，以便理解卡住是有风险的
8. 作为玩家，我想要在推出完成后立即恢复正常操控，以便无缝继续战斗
9. 作为玩家，我想要在卡住时不能跳跃，以便不能通过跳跃绕过惩罚
10. 作为玩家，我想要在推回过程中不能取消，以便惩罚是确定性的而非可选的
11. 作为玩家，我想要在卡住期间死亡时正常进入死亡流程，以便不会卡在"卡住+死亡"的冲突状态
12. 作为玩家，我想要在缓降入场期间不触发卡住检测，以便出生时不会误判
13. 作为玩家，我想要在正常撞墙（单侧碰撞）时不触发卡住，以便只有真正被夹住才触发惩罚

## 实现决策

- **三态状态机**：Player 新增 `enum StuckState { NORMAL, STUCK, ESCAPING }` 和 `var stuck_state` 字段。状态变迁：NORMAL → STUCK（检测触发）→ ESCAPING（按 G）→ NORMAL（脱离）
- **卡住判定条件**（全部满足）：`is_on_floor()` + WASD 输入 `input.length() > 0.1` + 实际水平速度 `< 0.3 m/s` + 持续 `0.5s`。使用浮点累加器 `_stuck_timer` 计时
- **排除条件**：缓降中（`_dropping`）不检测；不在地面不检测；无输入不检测（靠墙站立不触发）
- **_last_move_dir 缓存**：NORMAL 状态下每帧更新为当前水平速度归一化方向（仅在速度 > 0.5 时更新，避免静止时覆盖）。进入 STUCK 时冻结该值
- **STUCK 状态行为**：`movement_velocity` 强制归零（禁止 WASD 移动）；跳跃输入被忽略；视角转动/射击/换弹/近战正常；`damage()` 正常生效
- **ESCAPING 状态行为**：每帧 `global_position += (-_last_move_dir) * 0.5 * delta`；同样禁止移动/跳跃；允许视角/射击/受伤；不可取消
- **ESCAPING 终止条件**：每帧用 `test_move` 检测推回方向前方是否仍有碰撞——无碰撞即脱离（回到 NORMAL）；或累计推出距离 ≥ 8m（安全上限，强制回到 NORMAL）
- **死亡优先**：`damage()` 中 `_dead = true` 时，若处于 STUCK/ESCAPING 则重置为 NORMAL（死亡流程接管）
- **UI 提示**：HUD 新增一个 `Label`（屏幕中下方），STUCK 时显示"按 G 尝试挣扎离开"，ESCAPING/NORMAL 时隐藏。通过 Player 的 `stuck_state_changed` 信号驱动
- **输入动作**：`project.godot` 新增 `struggle` 动作，绑定 G 键（已确认 G 未被占用）
- **信号**：Player 新增 `signal stuck_state_changed(new_state: StuckState)` 供 HUD 监听
- **无音效**：`sounds/` 下无合适素材，v1 不加

## 测试决策

- **测试对象**：Player 的卡住状态机（外部行为：状态变迁 + 推回位移），不测内部计时器实现
- **测试 seam**：Player 节点暴露 `stuck_state` 字段 + `stuck_state_changed` 信号
- **测试场景**：构建 `tests/test_stuck_struggle.tscn`——Player + 两面 StaticBody3D 墙形成 0.5m 窄缝 + 地面
- **测试用例**：
  1. 将 Player 放入缝隙 + 模拟 WASD 输入 → 0.5s 后 `stuck_state == STUCK`
  2. STUCK 状态下模拟 G 键 → `stuck_state == ESCAPING`
  3. ESCAPING 期间 Player 沿预期方向位移（z 坐标变化）
  4. 推出缝隙后 → `stuck_state == NORMAL`
  5. 正常行走（无夹缝）不触发 STUCK
  6. 缓降中不触发 STUCK
- **先例**：`tests/test_run_director.gd`（headless 场景 + `_check()` 断言 + `--quit-after` 超时）
- **运行命令**：`godot --headless --path . res://tests/test_stuck_struggle.tscn --quit-after 600`

## 超出范围

- 修改建筑碰撞体或转换管线（trimesh 保持精确，不生成整格盒子）
- 修改地图数据消除缝隙
- 卡住时的音效/粒子特效（无素材）
- 怪物卡住处理（怪物使用 NavMesh 寻路，不会进入不可导航区域）
- 多人游戏同步（本项目为单人）
- 推回方向的智能探测（RayCast 找最空旷方向）——v1 只用进入反向

## 补充说明

- 设计哲学参见 [ADR 016](../../docs/adr/016-stuck-struggle-punishment.md)
- 领域术语参见 `CONTEXT.md`「卡住与挣扎」一节
- 玩家胶囊体：半径 0.3m、高度 1.0m（直径 0.6m），可进入 ≥ 0.6m 的缝隙
- 正常行走速度 5 m/s，推回速度 0.5 m/s = 1/10，体感明显缓慢
- G 键当前未被占用（已核查 project.godot：WASD/Space/E/R/V/鼠标已用，G 空闲）
