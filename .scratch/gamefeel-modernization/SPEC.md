# SPEC：操作手感现代化

Status: ready-for-agent
Type: spec
Refs: PRD.md, ADR 028, ADR 029, CONTEXT.md「操作手感（Game Feel）」

## 问题陈述

当前项目 FPS 基础骨架齐全（移动/射击/ADS/近战/换弹），但现代化手感要素大量缺失。具体表现为：

- 后坐力施加后永不恢复，连续射击准星持续偏移，破坏射击节奏感
- 准星是纯静态纹理，不随移动、射击、后坐力状态变化
- 射击缺乏震屏反馈，开火"像在放幻灯片"
- 没有命中标记，玩家不清楚子弹是否命中敌人
- 移动只有单一速度，缺乏冲刺/蹲伏等速度分层
- 武器在屏幕中完全静止，缺乏持枪重量感
- 没有跳跃缓冲和土狼时间，平台边缘体验生硬
- 换弹无音效，弹壳无抛射视觉
- 受伤反馈仅有 Hit Flash，缺乏方向感和压迫感

这使得手感停留在"2005 年级别"，与项目的 Roguelike 竞技场定位和 20 把武器的丰富内容不匹配。

## 解决方案

在不动整体架构的前提下，补充 11 项现代化手感系统，让手感从"能用"提升至"爽快"。

所有系统遵循**叠加不重写**原则：新逻辑叠加在现有 Player/Weapon/HUD 之上，不破坏已有行为。参数在 Weapon 资源中定义（`@export`），15 把枪无需逐个修改代码。所有衰减/lerp 使用 `exp(-speed * delta)` 公式保证帧率无关。

## 用户故事

### 射击手感

1. 作为玩家，我希望停止射击后准星能自动回到原始瞄准点，以便在连续点射时保持精准度，不需要手动"压枪"回位
2. 作为玩家，我希望不同武器有不同的后坐力恢复速度（如手枪快、机枪慢），以便感受到每种武器的独特"重量"和节奏
3. 作为玩家，我希望准星能根据我的移动速度、射击状态和跳跃状态动态扩张/收缩，以便直观感知当前的射击精度状态
4. 作为玩家，我希望 ADS（瞄准）时准星完全收紧，以便进行精确瞄准射击
5. 作为玩家，我希望每次射击时屏幕有轻微震动，以便感受到开火的冲击力和武器威力
6. 作为玩家，我希望不同武器的震屏幅度不同（狙击枪强、手枪弱），以便感知武器的威力等级
7. 作为玩家，我希望子弹出膛命中敌人时屏幕中央闪现一个命中标记并播放短促音效，以便获得即时的命中反馈，不用盯着血条看
8. 作为玩家，我希望连射命中多个敌人时每个命中都有独立标记，以便感知弹道覆盖效果

### 移动手感

9. 作为玩家，我希望按住 Shift 键时能冲刺跑，移动速度明显提升，以便在竞技场中快速调整位置和躲避敌人
10. 作为玩家，我希望冲刺时屏幕 FOV 略微扩张（模拟速度感），且冲刺中不能射击（需先松 Shift 再开火），以便冲刺是一种有代价的战术选择
11. 作为玩家，我希望按住 Ctrl 键时能蹲伏移动，降低身位以便利用掩体，且蹲伏时射击更精准
12. 作为玩家，我希望武器模型会随我的移动有节奏地摆动，静止时也有轻微的呼吸式晃动，以便感受到武器的物理存在感和重量
13. 作为玩家，我希望蹲伏和 ADS 时武器摆动幅度减小，以便在这些姿态下保持更稳定的瞄准
14. 作为玩家，我希望在落地前瞬间按下跳跃键能被"记住"并在落地瞬间自动起跳，以便在快速跳跃中不会因为"差一帧"被吞跳
15. 作为玩家，我希望走出平台边缘后的极短时间内仍能起跳，以便在边缘跳跃时有容错空间，不会因为"晚按了一点点"而坠落

### 视听包装

16. 作为玩家，我希望每把枪换弹时播放独立的换弹音效，以便通过听觉区分不同武器的换弹节奏和个性
17. 作为玩家，我希望每次射击时枪膛弹出弹壳并有物理下落动画，以便感受到射击的真实感和"机械感"
18. 作为玩家，我希望受到伤害时屏幕边缘出现红色渐晕效果，以便直观感知当前的危险程度
19. 作为玩家，我希望受到伤害时屏幕显示指向伤害来源的箭头，以便快速定位敌人方向做出反应

## 实现决策

### 后坐力模型（ADR 028）

- **真实后坐 + 自动恢复**：相机角度被后坐力真实推开，停止射击后自动回弹至原始瞄准点
- **统一模板 + 参数差异化**：所有枪用同一套恢复逻辑，仅通过 `recoil_recovery_speed` / `recoil_recovery_delay` 区分
- 恢复曲线：指数衰减 `lerp(offset, ZERO, 1.0 - exp(-speed * delta))`
- 射击时仅累加 knockback 到 `_recoil_offset`，不再直接修改 `camera.rotation` / `rotation.y` / `rotation_target`
- **每帧合成**：`camera.rotation` 必须在 `_process` 中每帧重新计算（`camera.rotation.x = rotation_target.x + _recoil_offset.x`），不能仅在 `_input` 事件触发时计算——因为后坐力恢复发生在无鼠标输入期间
- `handle_rotation()` 鼠标路径不再直接设置 `camera.rotation`，仅更新 `rotation_target`；手柄路径的 `lerp_angle` 目标需要包含 `_recoil_offset`
- 切枪时 `_recoil_offset` 清零，空弹匣扣扳机不累加后坐力

### 动态准星

- Procedural 四线准星（`draw_line()` 绘制），零额外纹理依赖
- 扩张因子综合：移动速度（0-0.6）+ 射击中（每发 +0.15）+ 后坐力累积（0-0.4）
- 扩张快（speed=12）、收缩慢（speed=6），制造重量感
- ADS 时强制因子 0.0，四线隐藏，显示静态小圆点
- 独立 `scripts/dynamic_crosshair.gd` Control 节点，提供 `set_spread_factor(f)` 和 `get_gap()` 接口
- v1 忽略 `Weapon.crosshair` 纹理，统一使用四线准星；Player 中 `@export var crosshair` 类型从 `TextureRect` 改为 `Control`；现有 `crosshair.texture =` 调用改为 `is TextureRect` 防御判断

### 射击震屏

- sin/cos 组合近似噪声（无 FastNoiseLite 依赖），频率 30Hz
- 振幅 = `Weapon.screen_shake_amplitude`（新增字段），指数衰减
- ADS 时振幅降为 0.3×
- 与已有近战震屏和落地回弹叠加共存

### 命中标记

- 准星位置短 × 形标记（`scripts/hit_marker.gd`），红色 200ms 淡出
- 伴随短促"叮"音效
- 多连击自然覆盖（不堆叠显示）
- HUD 独立 Control 节点
- **通信链路**：Player 暴露 `hit_confirmed(global_position: Vector3)` 公开方法 + 同名信号；`projectile.gd` 的 `_hit()` 中通过 `shooter.hit_confirmed()` 通知 Player；HUD 连接 Player 信号触发标记。beam 武器的射线命中也需要调用 `hit_confirmed()`

### 冲刺

- Hold Shift 触发：移速 ×1.6，FOV 扩张至 85°，脚步音调 pitch=1.3
- 冲刺中不可射击（自动退出冲刺），冲刺与 ADS 互斥
- 不消耗体力（PvE 不需要资源管理）
- 输入动作 `sprint`（project.godot 新增）

### 蹲伏

- Hold Ctrl 触发：移速 ×0.5，碰撞体高度缩至 0.6×，相机下移 0.6m
- 蹲伏中射击散布 ×0.8（更精准），脚步声音量降至 -6dB
- 站起时 `test_move` 检测头顶空间，有障碍物保持蹲伏
- 碰撞体为 `$Collider`（`CapsuleShape3D`，radius=0.3，height=1.0）。修改 `$Collider.shape.height`（CapsuleShape3D.height 是圆柱段高度，不含半球）。`_ready()` 中缓存原始值用于站起恢复
- 输入动作 `crouch`（project.godot 新增）

### 武器摆动

- Procedural sine-wave bob：水平 sine + 垂直 abs(sine)×2（双峰模拟脚步）
- 移动时 bob（速度 8Hz，振幅 0.015m 水平），冲刺 ×1.3，蹲伏 ×0.6，ADS ×0.3
- 静止时 breathing sway（1.5Hz，振幅 0.005m）+ 轻微 z 轴旋转
- 全部通过 `container.position` 叠加偏移实现

### 跳跃缓冲 + 土狼时间

- Jump Buffer：落地前 150ms 内按跳 → 落地瞬间自动触发
- Coyote Time：离开平台边缘后 100ms 内仍可跳跃
- 在 `action_jump()` 和 `_process` 中通过浮点计时器实现

### 换弹音效

- Weapon 资源新增 `sound_reload: String` 字段
- 换弹开始时播放；空字符串 → fallback `sounds/reload_default.ogg`

### 弹壳抛射

- GPUParticles3D 单发弹壳（黄铜色小方块，带重力 + 自旋）
- 节点池 8 个循环，寿命 1.5s
- `ejection_port` 定义在 Weapon 资源（新增字段）
- `action_shoot()` 触发单次 emission

### 受伤反馈

- 红色径向 vignette（`scripts/damage_vignette.gd`）：强度 = `damage / max_health`，max alpha=0.5，0.5s 淡出
- 方向指示箭头（`scripts/damage_direction.gd`）：指向伤害来源，1s 淡出，v1 仅前方受伤有效
- 两者均为 HUD 独立 Control 节点

### 架构约束

- **叠加不重写**：所有新系统叠加在现有逻辑之上
- **参数在 Weapon 资源**：所有可调参数 `@export`，15 把枪无需逐个修改代码
- **帧率无关**：所有 lerp/衰减使用 `exp(-speed * delta)`
- **不新增 Timer 节点**：计时器用 `_process` 浮点累加器
- **独立 Tween**：每个系统用自己的 Tween 引用，互不干扰

### 影响范围

- **Weapon 资源**（`scripts/weapon.gd`）：新增 ~8 个 `@export` 字段
- **Player**（`objects/player.gd`）：新增 ~300 行代码（`_process`、`handle_controls`）
- **HUD**（`scripts/hud.gd`）：新增 2-3 个 Control 子节点
- **project.godot**：新增 2 个输入动作（sprint、crouch）
- **音效资源**：新增换弹音效、命中标记音效、默认弹壳落地音
- **新脚本**：`dynamic_crosshair.gd`、`hit_marker.gd`、`damage_vignette.gd`、`damage_direction.gd`

## 测试决策

### 测试 Seam

核心 seam 为 **Player**（`objects/player.gd`）——所有手感功能收敛到 Player 的状态机、`_process` 和 action 方法中。不需要新建抽象层。

次级 seam 为 **HUD**（`scripts/hud.gd`）——用于验证视觉反馈节点（命中标记、受伤渐晕、方向指示、动态准星）。

唯一需要的接口扩展：`dynamic_crosshair.gd` 暴露 `get_gap() -> float` 公开方法。

### 测试策略

沿用项目现有无框架模式（`_check()` + `quit(0/1)`），不引入 GUT 或其他测试框架。

三个测试文件覆盖全部 11 项功能：

| 测试文件 | 覆盖功能 | 驱动方式 |
|----------|---------|---------|
| `tests/test_gamefeel_recoil.gd` | 后坐力恢复、动态准星、射击震屏、命中标记 | `preload` main.tscn → 驱动 `action_shoot()` → 验证 Player 内部状态 + HUD 节点 |
| `tests/test_gamefeel_mobility.gd` | 冲刺、蹲伏、武器摆动、跳跃缓冲+土狼 | `preload` Player 场景 → 驱动 action 方法 + 模拟 Input 状态 → 验证速度/碰撞体/跳跃行为 |
| `tests/test_gamefeel_feedback.gd` | 换弹音效、弹壳抛射、受伤反馈 | 实例化 Player + HUD → 触发 reload/damage → 验证 Weapon 字段/粒子/UI 节点 |

### 测试设计原则

- 仅测试外部可观察行为（状态变化、信号发射、UI 节点可见性），不测内部实现
- 通过 `.get("_private_field")` 读取运行时状态（项目约定模式）
- 时间推进使用 `await get_tree().process_frame`（不依赖真实时钟）
- 每个测试文件遵循一致的 `failures` 计数器 + `_check()` + `quit(0/1)` 模式

### 测试先例

- `test_minimap_t1.gd`：场景实例化型，preload main.tscn → 验证节点树
- `test_weapon_durability.gd`：独立实例化型，手动构建 Player + HUD
- `test_module_hooks.gd`：纯逻辑型，但手感测试不适用此模式（需要场景树支持物理/collision）

## 超出范围

- 滑铲、翻越、墙壁跑等高级移动（C 级方案，成本远超收益）
- 完整骨骼 AnimationPlayer 驱动 viewmodel 动画（当前 Tween 足够）
- 空间音频混响系统（体量过大）
- 每枪独立 spray pattern（A 方案，不匹配 PvE Roguelike 定位）
- 手柄独立配置（v1 仅键盘鼠标）
- 体力/耐力资源系统（PvE 不需要资源管理复杂度）
- 弹壳落地音效（v1 仅视觉弹壳，落地音效属后续增强）

## 补充说明

### 实施顺序

按 Phase A（射击手感）→ Phase B（移动手感）→ Phase C（视听包装）顺序实施。Phase A 中的后坐力恢复（01）是核心依赖——动态准星的宽度和射击震屏的强度都基于后坐力状态。其余 issue 相对独立，可在各自 phase 内并行。

### 与已有系统的关系

- 后坐力恢复叠加在现有 `rotation_target` 体系之上，不修改鼠标输入管线
- 冲刺/蹲伏在已有 `movement_velocity` / `handle_controls` 框架内扩展，不新建移动控制器
- 震屏与已有近战 Hit-Stop + FOV Pulse 的"动作游戏感"风格一致
- 命中标记和已有 Hit Flash 互补——Hit Flash 标记已死亡敌人，命中标记标记正在被射击的敌人
