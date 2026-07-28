# ADR 029：操作手感现代化设计系统

- **日期**：2026-07-26
- **状态**：✅ 已采纳

## 上下文

当前项目 FPS 操作手感基础骨架齐全（移动/射击/ADS/近战），但现代化要素大量缺失：后坐力不恢复、准星纯静态、射击无震屏、无武器摆动、无移动能力分层、无命中标记等。需在不动整体架构的前提下，补充让手感从"能用"变为"爽快"的关键系统。

## 前置决策

- **ADR 028**：后坐力模型 = 真实后坐 + 自动恢复，统一模板 + 参数差异化
- 范围级别：**B（中度扩展）**
- 优先级：**射击 > 移动 > 视听**

## 决策

### 操作手感设计系统总览

以下为 Grill 会话中自主裁定的全部决策，整理为统一设计系统：

| 系统 | 决策 | 关键参数 |
|------|------|----------|
| **后坐力恢复** | Spring-back：停止射击后相机角度自动回弹至原始瞄准点 | `recoil_recovery_speed=8.0`, `recoil_recovery_delay=0.08s` |
| **动态准星** | 四线 procedural 准星，随移动/射击/后坐力扩张 | `base_gap=6px`, `max_gap=40px`, expand_speed=12, contract_speed=6 |
| **射击震屏** | sin/cos 组合近似 Perlin-noise 相机抖动 | `amplitude` per weapon, `frequency=30Hz`, ADS 降为 0.3× |
| **命中标记** | 准星位置 × 形 + "叮"音效，200ms 淡出 | `marker_size=8px`, `fade_duration=0.2s` |
| **冲刺** | Hold Shift, 1.6× 移速, FOV 85, 不可射击 | `sprint_speed_multiplier=1.6`, `sprint_fov=85` |
| **蹲伏** | Hold Ctrl, 0.5× 移速, 碰撞体降高, 静音脚步声 | `crouch_speed_multiplier=0.5`, `crouch_height=0.6×` |
| **武器摆动** | Procedural sine-wave bob + idle sway | `bob_speed=8Hz`, `bob_amp_h=0.015m`, `idle_sway_amp=0.005m` |
| **跳跃缓冲** | 150ms 输入缓冲 + 100ms 土狼时间 | `JUMP_BUFFER_WINDOW=0.15`, `COYOTE_TIME=0.1` |
| **换弹音效** | Weapon 新增 `sound_reload` 字段 | fallback: `sounds/reload_default.ogg` |
| **弹壳抛射** | GPUParticles3D 单发弹壳，节点池 8 个循环 | `lifetime=1.5s`, `eject_force=2.0` |
| **受伤反馈** | 屏幕边缘红色径向 vignette + 方向指示箭头 | vignette max alpha=0.5, fade=0.5s |

### 架构原则

1. **叠加不重写**：所有新系统叠加在现有逻辑之上（如后坐力偏移叠加在 `rotation_target` 之上），不破坏已有行为
2. **参数在 Weapon 资源**：所有可调参数定义为 `@export`，20 把枪无需逐个修改代码
3. **帧率无关**：所有 lerp/衰减使用 `exp(-speed * delta)` 公式
4. **不新增 Timer 节点**：计时器用 `_process` 浮点累加器（与现有风格一致）
5. **独立 Tween**：每个系统用自己的 Tween 引用，互不干扰

## 被否决的替代方案

### C 级（全面重做）
- 完整骨骼 AnimationPlayer 驱动的 viewmodel、高级移动（滑铲/翻越/墙壁跑）、空间音频混响
- **否决理由**：项目阶段过早（20 把枪定型不久），成本远超收益

### A 级（保守打磨）
- 仅修补后坐力恢复 + 少数音效
- **否决理由**：改完后手感依然单薄，射击和移动体验仍是"2005 年级别"

## 影响

- **Weapon 资源**：新增 ~8 个 `@export` 字段（恢复、震屏、换弹音效、弹壳参数等）
- **player.gd**：新增 ~300 行代码（主要在 `_process` 和 `handle_controls`）
- **HUD**：新增 2-3 个 Control 子节点（DynamicCrosshair、HitMarker、DamageVignette）
- **project.godot**：新增 2 个输入动作（sprint、crouch）
- **音效资源**：新增换弹音效、命中标记音效、默认弹壳落地音
