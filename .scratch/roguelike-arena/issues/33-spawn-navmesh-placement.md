# 33 — 刷怪位置 NavMesh 选点

Status: ready-for-agent
Type: task
Refs: ADR 025, issue 31

## 描述

将 RunDirector 刷怪位置从固定 `SpawnPoints` 改为以玩家为中心的 NavMesh 选点。每波怪物在玩家周围 15–60m 的 NavMesh 空旷地带出生（带间距约束和天花板检测），复用现有 `DROP_HEIGHT=8m` 缓降机制。NavMesh 选点全部失败时回退固定 `SpawnPoints` 兜底。

## 前置依赖

无 — 可立即开始。

## 验收标准

### 选点逻辑

- [ ] `run_director.gd` 新增 `_find_spawn_positions(count: int, player_pos: Vector3) -> Array[Vector3]`
- [ ] 选点流程：
  1. 以 `player_pos` 为中心，在近圈（15–30m）随机角度和距离 → 候选点
  2. `NavigationServer3D.map_get_closest_point()` 验证 NavMesh 可达
  3. 向下 RayCast（2m）验证命中地面
  4. 向上 RayCast（5m）验证无天花板遮挡
  5. 与已选点水平距离 ≥ 3m
  6. 近圈不足 → 扩大到远圈（30–60m）重试
- [ ] 返回的每点：水平距离在 15–60m，相邻点间距 ≥ 3m

### 刷怪集成

- [ ] `_spawn_all()` 中调用 `_find_spawn_positions()` 替代固定 `SpawnPoints`
- [ ] `_spawn_monster()` 中，怪物 `global_position` 设为地面位置 + `DROP_HEIGHT`（8m），复用现有缓降

### 兜底

- [ ] 固定 `SpawnPoints` 节点保留在 `main.tscn` 中不动
- [ ] `_find_spawn_positions()` 返回空数组时 → 退回原固定 `SpawnPoints` 逻辑
- [ ] 兜底发生时记录 `push_warning("RunDirector: NavMesh选点失败，回退固定出生点")`

### 不修改内容

- [ ] 波次制不动（`compute_wave_composition` / 预算公式 / 类型分阶段解锁不变）
- [ ] 追击触发逻辑（awareness_range + Chain Aggro 不变）
- [ ] 卡怪兜底、血包掉落、宝箱生成等其他 RunDirector 功能不变

## 测试

- [ ] `tests/test_spawn_navmesh.gd`：
  - 测试 5：刷怪位置选点（注入玩家位置，检查返回点水平距离 15–60m，相邻间距 ≥ 3m）
  - 测试 6：刷怪位置兜底（模拟 NavMesh 不可用，检查仍能产出位置，不崩溃）
