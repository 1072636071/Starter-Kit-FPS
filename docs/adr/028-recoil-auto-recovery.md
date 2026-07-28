# ADR 028：后坐力自动恢复模型

- **日期**：2026-07-26
- **状态**：✅ 已采纳

## 上下文

当前后坐力系统施加角度偏转后**永不恢复**——连续射击导致准星持续偏移，破坏手感。需决定后坐力恢复的行为模型。

## 决策

采用 **真实后坐 + 自动恢复（Real Recoil with Auto-Recovery）**：

- 后坐力**真实偏移相机角度**（非纯视觉欺骗），弹道从偏转后方向射出
- 停止射击后，偏转角度**自动回弹**至射击前的原始瞄准点
- 恢复曲线由武器参数控制（速度、延迟、缓动），不同武器可不同

## 被否决的替代方案

### A：纯视觉后坐（View Kick）
- 相机指向不变，仅武器模型/准星 UI 做视觉跳动
- **否决理由**：手感"软"，缺乏射击重量感；与项目已有近战 Hit-Stop + FOV Pulse 的"动作游戏感"不一致

### C：纯真实后坐（无自动恢复）
- 后坐永久偏移，完全靠玩家手动压枪
- **否决理由**：项目 16 种角色化敌人 + Roguelike 竞技场体系定位非硬核拟真；对休闲玩家不友好

## 影响

- 后坐力系统需新增：恢复曲线参数（`recoil_recovery_speed`、`recoil_recovery_delay`）、`_process` 中自动 lerp 回弹逻辑
- 动态准星和射击震屏将围绕此恢复模型设计
- 每把枪可能需要独立的恢复参数（或默认值 + 可覆盖）

## 实现设计（issue 01）

### Weapon 资源新增字段

```gdscript
@export_subgroup("Recoil")
@export var recoil_recovery_speed: float = 8.0    # 恢复速度，越大越快
@export var recoil_recovery_delay: float = 0.08    # 停止射击后等待时间（秒）
```

### Player 运行时状态

```gdscript
var _recoil_offset: Vector2 = Vector2.ZERO   # 当前后坐力累积偏移（x=垂直, y=水平）
var _recoil_timer: float = 0.0                # 停止射击后倒计时
```

### 核心逻辑

- **射击时**（`action_shoot()`）：移除当前第 825-828 行对 `camera.rotation` / `rotation.y` / `rotation_target` 的直接修改，改为仅累加 knockback 到 `_recoil_offset`（`_recoil_offset.x += knockback.x`，`_recoil_offset.y += knockback.y`），并重置 `_recoil_timer = weapon.recoil_recovery_delay`。`container.position.z += 0.25` 和 `movement_velocity` knockback 保持不变。
- **恢复时**（`_process` → `_step_recoil_recovery(delta)`）：`_recoil_timer` 递减到 0 后，每帧 `_recoil_offset = _recoil_offset.lerp(Vector2.ZERO, 1.0 - exp(-weapon.recoil_recovery_speed * delta))`
- **每帧合成**（关键架构变更）：`camera.rotation` 必须在 `_process` 中每帧重新计算——不能仅在 `_input` 事件（鼠标移动）时计算，因为后坐力恢复发生在无鼠标输入期间。在 `_process` 的 `handle_controls(delta)` 之后新增 `_step_apply_recoil(delta)`：
  - 鼠标模式：`camera.rotation.x = rotation_target.x + _recoil_offset.x`，`rotation.y = rotation_target.y + _recoil_offset.y`
  - 手柄模式：`handle_rotation()` 中 lerp 目标已包含 `_recoil_offset`，不重复赋值
  - `handle_rotation()` 鼠标路径移除 `camera.rotation.x = rotation_target.x` 和 `rotation.y = rotation_target.y`（第 700-701 行），`handle_rotation` 仅负责更新 `rotation_target` 和 clamp
- **切枪清零**：`initiate_change_weapon()` 中 `_recoil_offset = Vector2.ZERO`
- **空弹扣扳机**：不累加后坐力（无击发无后坐）

### 参数化策略

采用**统一模板 + 参数差异化**：所有 20 把枪使用同一恢复逻辑，仅通过 `recoil_recovery_speed` / `recoil_recovery_delay` 区分。默认值 8.0 / 0.08s 适合大多数武器，个别需要微调的在 `.tres` 中覆盖。
