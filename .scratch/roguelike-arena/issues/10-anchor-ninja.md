# 10 — 锚点敌人：忍者（Stealth + Dash 模块）

Status: planning
Type: task
Refs: ADR 022, issue 09

## 描述

实现第一个锚点敌人「忍者」及其依赖的两个模块（Stealth / Dash），验证模块系统架构是否可行。忍者定位为**近战刺客**：进 ATTACK 状态时隐身 0.5s 并朝玩家方向瞬步冲刺。

## 前置依赖

- [ ] issue 09（模块钩子 + ENEMY_CONFIG + 弹药池）完成

## 验收标准

### Stealth 模块

- [ ] 新建 `scripts/modules/module_stealth.gd`，实现 `module_setup` + `on_enter_state` 接口
- [ ] `on_enter_state(AIState.ATTACK)` 时：把宿主模型所有 mesh 的 `transparency` 设为 0.4（半透明），0.5s 后恢复为 0
- [ ] 非 ATTACK 状态进入不触发
- [ ] 模块挂为敌人 `.tscn` 子节点即可工作，无需代码耦合

### Dash 模块

- [ ] 新建 `scripts/modules/module_dash.gd`，实现 `module_setup` + `on_enter_state` 接口
- [ ] `on_enter_state(AIState.ATTACK)` 时：沿"敌人→玩家"水平方向瞬间位移 `dash_distance`（`@export float = 5.0`，可调）
- [ ] Dash 后立即结算一次近战伤害判定（复用 `_deal_damage` 距离判定逻辑）
- [ ] Dash 期间（约 0.15s）敌人不响应 RVO / NavMesh（设 `_desired_velocity = dash_dir * dash_speed`）
- [ ] 非 ATTACK 状态进入不触发

### 忍者敌人配置

- [ ] 导入 `character-r（忍者）.glb` 到 `models/monsters/`
- [ ] 创建 `objects/enemy_ninja.tscn`：继承 `monster_base.gd`，子节点挂 Stealth + Dash 模块
- [ ] `@export` 参数：`move_speed = 5.0`（快）、`health = 70`（脆）、`attack_cooldown = 2.0`、`jump_height = 5.0`
- [ ] 在 `run_director.gd` 的 `ENEMY_CONFIG` 中添加忍者条目（cost=25, reward=25, min_wave=13）
- [ ] 模型导入并挂到 `arm-right` 为近战武器（空手或剑，同现有 `monster_melee` 模式）

### 测试

- [ ] `tests/test_enemy_ninja.gd`：
  - 验证进 ATTACK 后 0.5s 内透明度 → 恢复
  - 验证 Dash 位移方向和距离在 `dash_distance ± 0.5m` 内
  - 验证 Dash 后能命中近距离玩家
