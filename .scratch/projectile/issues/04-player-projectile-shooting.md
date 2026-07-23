# 04 - 玩家射击改为弹体发射

Status: resolved
Type: task

## 构建内容

玩家射击时生成实体弹体飞向准星方向，移除 RayCast 伤害逻辑。spread 控制弹体发射方向随机偏移。完成后，运行游戏射击可看到慢速弹体飞行并命中敌人造成伤害。

## 验收标准

- [ ] 玩家射击时生成弹体，弹体沿准星方向（含 spread 随机偏移）飞行
- [ ] 移除 action_shoot() 中的 RayCast 伤害逻辑（不再通过 raycast 调用 damage）
- [ ] shot_count 控制每次射击生成的弹体数量
- [ ] 弹体伤害读取武器 damage 属性
- [ ] 两把武器（blaster、blaster-repeater）的 projectile_speed 更新为 30-50 范围
- [ ] 运行游戏射击时弹体可见飞行、命中敌人造成伤害

## 阻塞于

- 03 - 弹体实体化重构（Area3D + 伤害判定）
