# 12 — 锚点敌人：化学人（PlaceTrap:Poison 模块）

Status: planning
Type: task
Refs: ADR 022, issue 09

## 描述

实现第三个锚点敌人「化学人」及其 PlaceTrap:Poison 模块。化学人定位为**远程陷阱型**：在当前位置放置毒雾陷阱（最多 3 个同时在场），玩家踩中后触发持续 10s DOT 区域。

## 前置依赖

- [ ] issue 09（模块钩子）完成

## 验收标准

### PlaceTrap:Poison 模块

- [ ] 新建 `scripts/modules/module_place_trap_poison.gd`
- [ ] `on_tick(delta)` 中：检查放置冷却（`place_cooldown = 5.0s`），冷却就绪且在场陷阱 < `max_traps = 3` 时在敌人脚下放置
- [ ] 陷阱为 `Area3D` 子场景（`scenes/trap_poison.tscn`），不可见但可被玩家踩入触发
- [ ] 触发后：展开一个半径 `poison_radius = 3.0m` 的绿色半透明圆柱/球体粒子区域
- [ ] 区域内玩家每 `tick_interval = 0.5s` 受到 `poison_dps = 8` 伤害（共 10s = 20 ticks = 160 总伤）
- [ ] 10s 后陷阱 `queue_free()`
- [ ] 化学人死亡 → 所有其陷阱 `queue_free()`

### 化学人敌人配置

- [ ] 导入 `character-d（化学人）.glb` 到 `models/monsters/`
- [ ] 创建 `objects/enemy_chemist.tscn`：远程型，`PlaceTrapPoison` 模块为子节点
- [ ] `@export` 参数：`health = 90`（中低）、`move_speed = 2.8`、远程射击伤害 18、攻击冷却 1.8s
- [ ] 模型挂远程武器
- [ ] `ENEMY_CONFIG` 添加：cost=15, reward=15, min_wave=7

### 测试

- [ ] `tests/test_enemy_chemist.gd`：
  - 验证最多 3 个陷阱
  - 验证冷却节奏（5s 放一个）
  - 验证玩家踩中后持续 10s DOT
  - 验证化学人死亡陷阱消失
