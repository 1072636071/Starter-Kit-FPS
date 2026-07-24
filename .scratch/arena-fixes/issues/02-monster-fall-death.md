# 02 — 怪物坠落死亡判定

Status: ready-for-agent

## 父 issue

`.scratch/arena-fixes/PRD.md`

## 构建内容

任何怪物（近战、远程、飞行）因出生点无地面、寻路异常或其他原因坠出地图后，自动触发死亡：播放死亡动画和音效、发射 `died` 信号、正常结算奖励（金币/经验/击杀），波次清场检测不受影响。玩家不再因怪物坠落而卡在"等待不存在的怪物"的死局中。

## 验收标准

- [ ] `monster_base.gd` 在 `_physics_process` 中检测 `position.y < -10` 时调用 `destroy()`
- [ ] `enemy.gd`（飞行敌人，非 monster_base 子类）同样增加 `position.y < -10` 坠落检测，触发其死亡流程
- [ ] 坠落死亡的怪物正常发射 `died(monster_type)` 信号
- [ ] RunDirector 收到 `died` 信号后正常结算奖励（金币/经验/击杀计数）并递减 `alive_count`
- [ ] 全部怪物坠落后 `alive_count` 归零，波次正常清场（`wave_cleared` 信号发射）
- [ ] 坠落阈值 `-10` 与玩家侧一致
- [ ] 新增测试场景验证：怪物 `position.y = -11` → `died` 信号发射；`position.y = -9` → 不触发死亡
- [ ] 测试先例参照 `tests/test_monster_died_signal.gd`

## 阻塞于

无——可立即开始。
