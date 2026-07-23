# 03 - 弹体实体化重构（Area3D + 伤害判定）

Status: resolved
Type: task

## 构建内容

弹体从纯视觉对象变为实体伤害载体——包含 Area3D 碰撞检测，命中物体时造成伤害、生成 impact 特效并销毁。速度降至 30-50 m/s，超出 max_distance 自动销毁。完成后，弹体场景本身具备完整的碰撞-伤害-销毁能力。

## 验收标准

- [ ] 弹体场景包含 Area3D + CollisionShape3D，通过 body_entered 信号检测碰撞
- [ ] 弹体命中有 damage() 方法的物体时调用 damage() 造成伤害
- [ ] 命中后在碰撞点生成 impact 特效
- [ ] 命中后弹体自身销毁
- [ ] 弹体飞行速度默认 30-50 m/s 范围
- [ ] 弹体超出 max_distance 后自动销毁
- [ ] Weapon 资源的 projectile_speed 范围更新为 30-50

## 阻塞于

无——可立即开始
