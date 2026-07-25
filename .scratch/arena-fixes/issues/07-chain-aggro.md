# 07 - 连锁 Aggro（警觉传播）

Status: ready-for-agent
Type: feature

## 问题陈述

作为玩家，我在竞技场中开第一枪后，远处的怪物仍然站在原地发呆，直到我主动走进它们的感知范围才加入战斗。这导致战斗节奏被割裂——我先清掉一波近处的怪物，然后像"清房间"一样逐个激活远处的怪物，而非一场紧张的大混战。枪声和怪物死亡应该惊动周围的同伴，制造"捅了马蜂窝"的连锁反应体验。

## 解决方案

引入两级感知模型：**被动感知**（怪物自己看见很近的玩家，约 8m）和**警觉传播**（听到枪声/同伴死亡，追踪范围扩至 chase_range）。玩家开枪、怪物开枪、怪物死亡时发出 alert 事件，距离内的 IDLE 怪物被惊动并转为 CHASE。alert 穿墙传播（声音隔墙也能听到），一旦进入 CHASE 就不会因"安静下来"而退回 IDLE。

## 用户故事

1. 作为玩家，我想要开枪后远处的怪物也被惊动并朝我追来，以便战斗有"捅马蜂窝"的连锁反应体验
2. 作为玩家，我想要怪物死亡时附近的同伴被惊动，以便击杀一只怪不会让旁边另一只怪继续发呆
3. 作为玩家，我想要远程怪物开枪时其附近的 IDLE 怪物也被惊动，以便枪战自然扩散
4. 作为玩家，我想要非常近的怪物（8m 内）直接看到我并追击，以便距离太近时 stealth 不成立
5. 作为玩家，我想要怪物被惊动后不会因我停止开枪而失去追踪，以便我无法靠"安静下来"消仇恨
6. 作为玩家，我想要近战攻击不惊动远处怪物，以便近战保留 stealth 属性（v1 无挥砍音效）
7. 作为玩家，我想要枪声能穿透墙壁惊动怪物，以便躲在墙后的怪物也能听到枪声加入战斗
8. 作为玩家，我想要不同怪物类型有不同的被动感知范围，以便远程怪（视力更好）能比近战怪更早看到我
9. 作为开发者，我想要 alert 系统作为独立 autoload 暴露简单接口，以便所有模块（玩家、怪物）统一调用

## 实现决策

### AlertSystem Autoload

- 新增 `AlertSystem` autoload，暴露两个方法：
  - `emit_alert(world_pos: Vector3, radius: float)` — 缓存 alert 事件（存活 0.5s 后自动丢弃）
  - `has_alert_nearby(world_pos: Vector3, check_radius: float) -> bool` — 查询 check_radius 内是否有 alert
- alert 缓存为 `[{position, radius, expire_time}]` 数组，每帧清理过期条目
- 与现有 `Audio`、`StepConstants` autoload 同模式，项目全局可访问

### 感知模型

- **被动感知**：始终检测，范围 `awareness_range`（默认 8m），用现有视线检测（RayCast，不穿墙）
- **警觉传播**：alert 事件驱动，范围 `chase_range`（已有参数，25-30m），穿墙
- IDLE → CHASE 条件：`distance < awareness_range`（被动感知）OR `has_alert_nearby`（警觉传播）
- 进入 CHASE 后只走 LOST 路线回到 IDLE，不会因"安静下来"直接退回
- 其余 FSM 状态（CHASE/LOST/ATTACK/RETREAT）不变

### Alert 事件发射点

| 事件 | 发射方 | 传播半径 |
|------|--------|---------|
| 玩家开枪 | `player.gd` `action_shoot()` | 30m |
| 怪物远程开枪 | `monster_ranged.gd` `_fire_projectile()` | 25m |
| 怪物死亡 | `monster_base.gd` `destroy()` | 20m |
| 玩家近战 | 不触发 | — |

### 新增参数

- `awareness_range: float`（`@export`，`monster_base.gd`，默认 8.0）— 被动感知半径。子类覆盖：`monster_melee` 默认 8m、`monster_ranged` 默认 12m
- `alert_check_interval: float`（`monster_base.gd`，默认 0.5）— IDLE 态下检测 alert 的频率
- `alert_lifetime: float`（`AlertSystem`，默认 0.5）— alert 缓存存活时间

### 不在范围

- 近战挥砍不触发 alert（v1 无挥砍音效）
- 玩家脚步声/跳跃不触发 alert
- 没有"消仇恨"机制（CHASE 不因安静退回 IDLE）
- 不同枪械响度不区分（玩家/怪物开枪各一个固定半径）
- 不修改飞行敌人 `enemy.gd`（飞行敌人无 IDLE 态，已在追踪模式）

## 测试决策

### 什么是好测试

- 仅测试外部可观测行为（状态转换、alert 存在性），不测内部实现细节
- 测试"怪物做了什么"而非"怪物怎么做的"
- 每个测试用例独立，不依赖其他测试的副作用

### 测试 seam

- 复用现有模式：实例化怪物场景 → 提供 dummy player（"player" 组 Node3D）→ 跑物理帧 → 断言公共属性/信号
- AlertSystem 作为 autoload，测试中直接调用 `AlertSystem.emit_alert()` 模拟 alert 事件
- 无需新建 seam

### 被测试的模块

- `AlertSystem` autoload：`emit_alert` 存入缓存、`has_alert_nearby` 正确返回、过期条目自动清理
- `monster_base.gd`：被动感知（awareness_range 内看到玩家转 CHASE）、警觉传播（alert 触发 CHASE）、死亡时 emit alert
- `monster_melee.gd`：`awareness_range` 默认值验证
- `monster_ranged.gd`：`awareness_range` 默认值验证、开枪时 emit alert
- `player.gd`：开枪时 emit alert

### 测试先例

- `tests/test_monster_died_signal.gd`：实例化怪物 + dummy player + 断言信号
- `tests/test_monster_fall_death.gd`：物理帧驱动 + 信号断言

### 测试用例概要

1. AlertSystem 存入 alert 后 `has_alert_nearby` 返回 true
2. AlertSystem 过期 alert 后 `has_alert_nearby` 返回 false
3. IDLE 怪物在玩家进入 awareness_range 内时转为 CHASE（被动感知）
4. IDLE 怪物在 awareness_range 外、chase_range 内，有 alert 时转为 CHASE（警觉传播）
5. IDLE 怪物在 chase_range 外，有 alert 也不转为 CHASE
6. 怪物死亡时触发 AlertSystem emit_alert（覆盖 monster_melee 和 monster_ranged）
7. 怪物远程开枪时触发 AlertSystem emit_alert
8. 玩家开枪时触发 AlertSystem emit_alert
9. `awareness_range` 默认值验证：近战怪 8m、远程怪 12m
10. 已进入 CHASE 的怪物在 alert 消失后不退回 IDLE

## 超出范围

- 飞行敌人（`enemy.gd`）不参与连锁 aggro（无 IDLE 态，已在追踪模式）
- 近战怪物攻击不触发 alert（v1 无挥砍音效）
- 脚步声/跳跃/换弹/切枪不触发 alert（只有枪声）
- 不同枪械（Blaster vs Blaster-Repeater）响度不区分
- 没有"消仇恨"计时器（CHASE 不因安静退回 IDLE，只走 LOST 路线）
- 没有 crouch/静步机制

## 补充说明

- 参见 ADR 017 了解当前 FSM 架构与 RVO 避障设计
- 参见 CONTEXT.md「敌人 AI 系统」章节了解现有术语定义
- 现有测试（`test_monster_died_signal`、`test_monster_fall_death`、AI overhaul 测试）必须在本次改动后继续通过——它们是回归基线
- AlertSystem 的 0.5s 缓存存活时间意味着：alert 发出后怪物最多有 0.5s 窗口检测到（配合 IDLE 态的 0.5s 检测间隔，最坏情况 1s 延迟）
- 被动感知仍用视线检测（RayCast 穿墙判断），与现有 CHASE → LOST 的 `_update_los()` 逻辑一致