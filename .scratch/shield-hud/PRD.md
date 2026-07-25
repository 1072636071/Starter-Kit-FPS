# 护盾 HUD 信息展示（Shield HUD）

Status: ready-for-agent

## 问题陈述

玩家在战斗中只有护盾条（蓝色 ProgressBar）显示护盾比例，无法看到精确的护盾数值、冷却倒计时和充能速率。护盾作为血量前的可再生吸收层（ADR 010），其恢复机制（受击后延时 + 持续充能）对战斗决策至关重要——但当前 HUD 没有提供足够的信息让玩家判断"我该等护盾回满再冲，还是现在就上？"。

## 解决方案

在护盾条上叠加关键信息，让玩家一眼掌握护盾全貌：

- **条内文字**：显示 `35/50`（当前护盾 / 护盾容量），精确到整数
- **左侧冷却倒计时**：受击后显示递减秒数（如 `2.1s`），冷却结束后隐藏
- **右侧充能速率**：始终显示 `10/s`（含升级 bonus），让玩家了解回盾速度
- **冷却中视觉反馈**：护盾条变灰（与正常蓝色区分），让玩家无需读数字也能感知状态

## 用户故事

1. 作为玩家，我想要在护盾条上看到当前护盾值和容量，以便我能精确判断还能承受多少伤害。
2. 作为玩家，我想要看到护盾受击后的冷却倒计时，以便我知道还有多久才能开始回盾。
3. 作为玩家，我想要护盾条在冷却中变灰，以便我用余光就能判断护盾是否在恢复。
4. 作为玩家，我想要冷却倒计时在冷却结束后自动消失，以便它不干扰正常战斗视野。
5. 作为玩家，我想要始终看到护盾的充能速度，以便我了解升级后的回盾效率。
6. 作为玩家，我想要护盾满时左侧不显示任何文字，以便 HUD 保持简洁。
7. 作为玩家，我想要护盾值变化时条内文字同步更新，以便信息始终准确。
8. 作为玩家，我想要升级护盾恢复速率后右侧速率数字同步更新，以便我能确认升级生效。
9. 作为玩家，我想要升级护盾容量后条内最大值同步更新，以便我能看到扩容效果。

## 实现决策

### 信号接口

- 新增 `shield_cooldown_changed(timer: float)` 信号，由 Player 在 `_step_shield_regen` 中发射
- 信号在三种状态下发射：冷却中（timer > 0，递减值）、满盾（timer = 0.0）、充能中（timer = 0.0）
- 已有 `shield_updated(shield, shield_max)` 信号不变，继续驱动条值更新

### HUD 布局

- 护盾条从单一 ProgressBar 重构为容器 Control，内含四个子元素
- 布局：左侧冷却标签（55px 宽，橙色 `Color(1, 0.6, 0.2, 1)`，右对齐）→ 护盾条（200px 宽，蓝色/灰色）→ 右侧速率标签（50px 宽，淡蓝 `Color(0.6, 0.8, 1, 1)`）
- 条内文字：白色 Label 叠加在 ProgressBar 上，居中，18px 字体
- 容器位置：左下角（offset top 596），与原有位置一致但向左扩展至 offset_left=8（原为 48）

### 颜色状态

- 正常/充能中：蓝色 `Color(0.15, 0.5, 0.85, 0.9)`
- 冷却中：灰色 `Color(0.35, 0.35, 0.35, 0.9)`
- 颜色切换由 `_shield_style_normal` 和 `_shield_style_cooldown` 两个 StyleBoxFlat 管理，通过 `add_theme_stylebox_override("fill", ...)` 切换

### 充能速率显示

- 初始值从 Player 的 `shield_regen_rate + shield_regen_rate_bonus` 读取
- 格式：`"%.0f/s"`（如 `10/s`、`15/s`）
- 始终显示，不随状态切换
- 升级 bonus 变化时需同步更新（当前实现：仅在 `_bind_player` 时读取一次；后续升级场景需由 issue 05 升级系统触发 HUD 刷新）

### 数据流

```
Player._step_shield_regen(delta)
  ├─ 满盾      → shield_cooldown_changed(0.0)
  ├─ 冷却中     → shield_cooldown_changed(timer)  [每帧递减]
  └─ 充能中     → shield_updated(shield, max) + shield_cooldown_changed(0.0)
```

HUD 响应：
- `shield_updated` → 更新 ProgressBar 值 + 条内文字
- `shield_cooldown_changed(timer > 0)` → 显示左侧倒计时 + 条变灰
- `shield_cooldown_changed(0.0)` → 隐藏左侧倒计时 + 条恢复蓝色

## 测试决策

### 什么是好测试

- 仅测试 Player 的信号发射行为，不测 HUD 渲染（HUD 由代码审查 + 视觉验证保证）
- 测试三种状态下的信号参数值
- 测试边界条件：timer 恰好归零的瞬间

### 测试目标

1. **`shield_cooldown_changed` 信号在三种状态下正确发射**：
   - 受击后 → 验证 timer 初始值 = `shield_regen_delay`（3.0s）
   - 推进 delta 时间 → 验证 timer 递减
   - 冷却结束 → 验证 timer = 0.0
   - 满盾 → 验证 timer = 0.0
   - 测试先例：`tests/test_arena_shield.gd`

2. **升级 bonus 影响充能速率**：
   - 设置 `shield_regen_rate_bonus = 5.0` → 验证每帧充能量为 `15.0 * delta`
   - 验证 `shield_cooldown_changed` 不受 bonus 影响（bonus 只影响充能阶段，不影响冷却延时）

### 测试先例

- `tests/test_arena_shield.gd` — 护盾 damage/充能/信号测试，已覆盖 `shield_updated`
- `tests/test_melee_transitions.gd` — 时序断言测试模式（create_timer + 逐帧推进）

## 超出范围

- **升级后速率标签更新**：本 spec 的充能速率在 `_bind_player` 时读取一次。升级 bonus 变化后速率标签的同步刷新由 issue 05（升级系统）负责，不在本 spec 范围内。
- **护盾条动画**：值变化时 ProgressBar 自带平滑过渡，不额外添加 Tween 动画。
- **护盾破碎特效**：护盾归零时的视觉特效不在本 spec 范围内。
- **音效**：护盾受击/充能音效不在本 spec 范围内。
- **HUD 自定义/缩放**：护盾条位置和大小固定，不支持玩家自定义。

## 补充说明

- 护盾系统本身的机制（优先吸收、延时恢复、战斗中可回）由 ADR 010 定义，本 spec 仅涉及 HUD 展示层。
- 领域词汇表（CONTEXT.md）中「护盾」条目已涵盖 `shield_max`、`shield_regen_delay`、`shield_regen_rate` 概念，无需新增术语。
- 本 spec 的决策来自 grill 会话（jxx-grill-with-docs），逐项确认了展示方式、冷却显示、充能速率显示时机和布局。