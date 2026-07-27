# ADR 001: 弹体伤害模型

**状态**：已接受（v2 实体弹体）
**日期**：2026-07-24

## 演化记录

| 版本 | 决策 | 状态 |
|------|------|------|
| v1 | 弹体纯视觉装饰，命中判定保持 RayCast hitscan | 已废弃 |
| v2 | 弹体为实体伤害载体，完全取代 hitscan | **当前生效** |

## 背景

项目初始使用 RayCast3D hitscan 判定。v1 添加发光弹体仅作视觉装饰（80-120 m/s）。实际体验后认为纯视觉弹体缺乏游戏性——无法预判、无法躲避、无战术深度。

## 最终决策（v2）

- 弹体为实体对象（Area3D + CollisionShape3D），飞行中碰撞到物体时造成伤害并销毁
- 完全移除 RayCast 伤害逻辑，弹体为唯一伤害来源
- 玩家和敌人都使用弹体（对称公平）
- 飞行速度 30-50 m/s（中速，需轻微预判）
- 命中即销毁（不穿透），碰撞点生成 impact 特效
- `weapon.spread` 控制发射方向随机偏移，`weapon.max_distance` 控制最大飞行距离

## 弹体规格

- 形态：发光拉伸胶囊体（CapsuleMesh + emission 材质）
- 场景：`objects/projectile.tscn`
- 可配置：颜色（projectile_color）、大小（projectile_size）、速度（projectile_speed）
- 配置位置：`Weapon` 资源类

## v1 被废弃的原因

纯视觉弹体无法提供真实的游戏交互反馈。慢速实体弹体引入预判和躲避机制，增加战术维度，且与 arcade 风格兼容。
