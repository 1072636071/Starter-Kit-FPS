# 08 — 补全 ENEMY_CONFIG 并修复 Issue 27 平衡测试

Status: done
Type: task
Refs: issues 16–19, 27, ADR 022
Blocked by: none（可独立完成）

## 根因分析

Issue 27 标记为 `done`，但实际存在严重的结构性缺口：

### 缺口 1：ENEMY_CONFIG 仅 3/16 条目（致命）

**文件**: `scripts/run_director.gd:76-89`

当前只有 3 个原始敌人：
```gdscript
const ENEMY_CONFIG: Dictionary = {
    &"monster_melee":  { "cost": 5,  "reward": 500, "min_wave": 1, "scene": ... },
    &"monster_ranged": { "cost": 8,  "reward": 800, "min_wave": 4, "scene": ... },
    &"enemy":         { "cost": 10, "reward": 1000, "min_wave": 7, "scene": ... },
}
```

**根本原因**: Issues 16（锚点敌人）、17（近战组）、18（远程组）均标记为 `ready-for-agent`——**从未实施**。这 3 个 issue 负责创建 16 个角色敌人 `.tscn` 场景文件。没有这些场景，ENEMY_CONFIG 无法引用它们。

Issue 19（武器 .tres 批量创建）同样 `ready-for-agent`——`weapons/` 下仅 2 把枪。

**实际上 Issue 27 的前置依赖（issues 16–19）根本没有完成**，因此它被错误地标记为 `done`。

### 缺口 2：平衡测试脚本无法运行

`tests/test_balance_wave_survival.gd` 和 `tests/test_balance_ammo_economy.gd` 均 `extends Node`，但使用了未定义的 `assert_eq()`、`assert_gt()`、`assert_true()`、`assert_neq()` 方法——这些不是 `Node` 的内置方法。运行时必定崩溃。

此外，测试的 `_config()` 硬编码了自己的 3 条目表（而非读取 `run_director.ENEMY_CONFIG`），与生产代码脱节。

## 前置依赖

- [x] Issue 09–15（模块系统全部完成，16 个 `.gd` 模块文件就绪）
- [x] Issue 21–25（高级系统完成）
- [ ] Issue 16（3 锚点敌人 .tscn）
- [ ] Issue 17（5 近战组 .tscn）
- [ ] Issue 18（8 远程组 .tscn）
- [ ] Issue 19（20 武器 .tres）

> **注意**: 本工单聚焦于 ENEMY_CONFIG 本身和测试修复。Issues 16–19 应在完成本工单前先行实施（或并行）。

## 验收标准

### Phase 1：修复 Issue 27 平衡测试脚本（不依赖 16–19）

- [ ] `test_balance_wave_survival.gd` 改为 `extends Node3D` 并使用 `_check()` 模式（与 smoke test 一致），替代不存在的 `assert_*`
- [ ] `test_balance_ammo_economy.gd` 同上
- [ ] 两个测试的 `_config()` 改为从 `run_director.ENEMY_CONFIG` **动态读取**（而非硬编码）
- [ ] 运行两个测试 → 通过（当前 3 条目下应通过）→ 日志保存

### Phase 2：ENEMY_CONFIG 只读文档补丁（立即生效）

- [ ] 在 `ENEMY_CONFIG` 注释块中追加完整的 16 条目映射表（ADR 022 的花名册），作为注释文档。格式：

```
# 完整花名册（ADR 022）—— 待 issues 16–19 完成后逐条激活：
# &"普通女":   { "cost": 5,  "reward": 500,  "min_wave": 1,  "scene": preload("res://objects/enemy_normal_female.tscn") },
# &"普通黑女": { "cost": 5,  "reward": 500,  "min_wave": 1,  "scene": preload("res://objects/enemy_normal_black_female.tscn") },
# ... 共 16 条
```

这使后续 issue 16–19 的实施者可以逐条取消注释来激活敌人，而非从零写 ENEMY_CONFIG。

### Phase 3：ENEMY_CONFIG 与敌人场景对接（依赖 16–19）

- [ ] `_available_types()` 返回所有 `min_wave <= current_wave` 的已注释+已激活条目
- [ ] `_spawn_monster()` 能按 `ENEMY_CONFIG[type_id].scene` 实例化任意角色敌人场景
- [ ] 波次解锁规则与 ADR 022 一致：
  - 波 1–3: 普通女、普通黑女、游戏宅
  - 波 4–6: +警察、律师、日本艺妓、研究员-老人
  - 波 7–9: +牛仔、独眼牛仔、猎人、化学人
  - 波 10–12: +健壮男、机器人-男电、机器人-女心
  - 波 13+: +驯兽师、忍者

### 测试

- [ ] `tests/test_balance_wave_survival.gd` — 修复后通过（Phase 1）
- [ ] `tests/test_balance_ammo_economy.gd` — 修复后通过（Phase 1）
- [ ] 新增 `tests/test_enemy_config_completeness.gd` — 断言 ENEMY_CONFIG 条目数与花名册一致、cost/reward/min_wave/scene 四字段齐全、min_wave 随 cost 单调不降

## 评论

Issue 27 之所以被错标为 `done`，很可能是因为当时只有一个模糊的"平衡调参"概念——测试脚本写了（但有 bug），注释里写了平衡设计意图——但没有意识到核心数据 `ENEMY_CONFIG` 被 issues 16–19 阻塞。这不是实施者漏做，而是工单拆分时未建立显式阻塞关系。

补救策略分三层：
1. **即刻**：修复测试脚本，让现有代码至少能跑测试（Phase 1）
2. **文档**：在 ENEMY_CONFIG 旁写入完整花名册注释，降低后续实施摩擦（Phase 2）
3. **对接**：等 16–19 完成后逐条激活（Phase 3）
