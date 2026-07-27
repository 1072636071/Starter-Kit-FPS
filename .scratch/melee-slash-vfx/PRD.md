> **[ARCHIVED]** 本 PRD 对应功能已实现。决策权威见 ADR 020，术语定义见 CONTEXT.md。

Status: ready-for-agent

# PRD：近战剑弧粒子特效 —— 攻击范围可视化

为玩家和近战怪物的近战攻击添加可见的剑弧拖尾粒子特效，让玩家直观感知攻击范围。

## 来源

- 架构决策：`docs/adr/020-melee-slash-vfx.md`
- 领域词汇：CONTEXT.md「Melee Slash VFX」「MeleeVFX」术语
- 相关 PRD：`.scratch/melee/PRD.md`（近战系统）

## 问题陈述

当前近战系统中，命中判定完全不可见：
- 玩家侧：MeleeHitbox 是透明 Area3D，玩家挥砍时看不到自己的攻击范围，无法判断"够不够得着"
- 怪物侧：纯距离判定（`_deal_damage()` 中的 `to_player.length() <= attack_range + 0.8`），玩家被怪物近战攻击时看不到判定范围，无法判断"什么时候该闪避"

近战缺乏空间感知反馈，玩家只能凭感觉挥砍和闪避。

## 解决方案

在近战攻击的**活跃帧**期间，显示一个**剑弧拖尾粒子特效**（GPUParticles3D 一次性爆发），用发光粒子弧面直观展示攻击范围：

- 玩家挥砍时：青白色剑弧在第一人称视角中出现，覆盖 MeleeHitbox 区域
- 怪物近战攻击时：红橙色剑弧在怪物前方出现，覆盖其攻击判定范围
- 粒子在 0.2s 内从出现到消失，与伤害结算窗口同步

## 用户故事

1. 作为玩家，当我按下 V 键发动近战攻击时，我想要在活跃帧看到一道青白色剑弧特效，以便我知道我的攻击范围覆盖了哪些区域
2. 作为玩家，当近战怪物向我发动攻击时，我想要在它攻击的瞬间看到一道红橙色剑弧特效，以便我能判断攻击范围并决定是否闪避
3. 作为玩家，我想要剑弧特效的颜色与攻击者身份对应（我的剑弧是青白色，敌人的是红橙色），以便我一眼区分攻击来源
4. 作为玩家，我想要剑弧特效只在伤害结算的活跃帧期间出现，不在前摇和后摇期间显示，以便特效与伤害时机精确对应
5. 作为玩家，我想要剑弧特效的大小与命中判定区匹配（我的剑弧覆盖 MeleeHitbox 盒子区域，敌人的剑弧覆盖其攻击范围），以便特效准确反映判定范围
6. 作为玩家，我想要剑弧特效有发光拖尾的视觉质感（additive 混合 + billboard 朝向相机），以便它看起来像真正的刀光而非调试框
7. 作为玩家，我想要自己的剑弧仅在第一人称视角中可见（不在第三人称视角中出现），以便它不干扰其他玩家的视野（未来多人场景）
8. 作为玩家，我想要敌人的剑弧在主相机视角中可见（第三人称），以便我能从远处看到怪物在攻击

## 实现决策

### 技术选型

- **GPUParticles3D**：一次性爆发（`one_shot=true`），30 粒子，0.2s 生命周期
- **粒子形状**：QuadMesh 扁条（0.4×0.15），additive 发光混合，billboard 朝向相机
- **发射模式**：Box 发射形状，下劈方向 + 25° 扇形扩散 + flatness 压扁形成弧面
- **粒子行为**：快速减速（damping 3-6）、轻微上飘（gravity y=3.0）、缩放曲线（快速放大再缩小）

### 配色与渲染层

| 角色 | 颜色 | 渲染层 | 可见视角 |
|------|------|--------|----------|
| 玩家 | 青白 `(0.3, 0.7, 1.0)` | layer 2（武器相机） | 仅第一人称 |
| 敌人 | 红橙 `(1.0, 0.25, 0.15)` | layer 3（主相机） | 第三人称 |

### 触发时机

- **玩家**：`ACTIVE_START`（挥砍开始后 0.2s），与 `melee_hitbox.monitoring = true` 同步
- **敌人**：`active_frame_time`（攻击动画活跃帧，默认 0.2s），与 `_deal_damage()` 同步

### 发射盒尺寸

- **玩家**：`PLAYER_BOX_EXTENTS = (0.75, 0.75, 1.0)`，匹配 MeleeHitbox 的 BoxShape3D(1.5, 1.5, 2.0) 半尺寸
- **敌人**：`ENEMY_BOX_EXTENTS = (1.0, 1.0, 1.4)`，匹配更大的攻击范围（`attack_range + 0.8 ≈ 2.8m`）

### 模块架构

新增 `MeleeVFX` 静态工具类，提供两个静态方法：
- `create_slash(parent, color, layer, box_extents, local_pos) -> GPUParticles3D`：创建并配置剑弧粒子节点
- `trigger(particles)`：触发一次性爆发

玩家和敌人各自调用 `create_slash()` 在初始化时创建节点，在攻击活跃帧调用 `trigger()` 触发。

### 节点挂载

- **玩家**：剑弧粒子挂载在 `CameraItem` 下（与 MeleeViewmodel 同级），本地位置 `(0, -0.5, -1.0)`（映射自 MeleeHitbox 在 Player 根下的 `(0, 0.5, -1.0)`，减去 Head 偏移 `(0, 1, 0)`）
- **敌人**：剑弧粒子挂载在怪物自身节点下，本地位置 `(0, 0.5, -1.5)`（敌人前方 1.5m、腰部高度）

## 测试决策

### 好测试的标准

- 仅测试外部行为：节点是否创建、配置是否正确、触发后是否 emitting
- 不测试视觉外观（粒子颜色、形状等无法通过代码断言）
- 不测试渲染管线（GPU 端行为）

### 测试 Seam

| Seam | 断言 |
|------|------|
| `MeleeVFX.create_slash()` | 返回的 GPUParticles3D 节点非空、`process_material` 已配置、`draw_pass_1` 为 QuadMesh、`layers` 正确 |
| `MeleeVFX.trigger()` | 调用后 `particles.emitting == true` |
| 玩家 `action_melee()` | 活跃帧后 `melee_slash.emitting == true` |
| 怪物 `_start_attack()` | `active_frame_time` 后 `melee_slash.emitting == true` |
| 怪物 `_dead` 守卫 | 死亡后 `_start_attack()` 不触发粒子（`melee_slash` 仍有效但不应 emitting） |

### 测试模式

复用项目现有 `btest...` 测试场景模式（参考 `tests/test_melee_transitions.gd`），创建 `tests/test_melee_slash_vfx.gd`。

## 超出范围

- 剑弧音效（v1 跳过，无合适素材，与 Melee Swing Sound 同等待遇）
- 不同武器类型的剑弧变体（如横扫 vs 下劈不同形状）
- 剑弧与命中反馈（Hit Flash）的叠加视觉效果调优
- 粒子数量/颜色/大小的运行时动态调整（当前为编译时常量）
- 连击特效（连续挥砍的视觉增强）

## 补充说明

- 剑弧粒子使用 `one_shot=true` + `explosiveness=1.0`，一次性全部发射，无需手动停止
- 每次挥砍复用同一个 GPUParticles3D 节点（`restart()` + `emitting=true`），不重复创建/销毁
- 粒子在 GPU 端计算，CPU 开销可忽略（峰值 ~480 粒子）
- 后续可扩展：替换 draw_pass_1 的 QuadMesh 为自定义刀光 mesh 以获得更精细的弧线形态

## 工单拆解

| 工单 | 标题 | 依赖 |
|------|------|------|
| T1 | 创建 MeleeVFX 静态工具类 | 无 |
| T2 | 玩家近战接入剑弧粒子特效 | T1 |
| T3 | 怪物近战接入剑弧粒子特效 | T1 |
| T4 | 领域模型更新与 ADR 020 | T1, T2, T3 |