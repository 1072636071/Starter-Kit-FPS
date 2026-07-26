# 07 — 升级池新增背包负重

Status: done
Type: task
Refs: PRD.md, ADR 023, CONTEXT.md「Upgrade Pool / Backpack Weight」

## 实现记录

- `run_director.gd` `UPGRADE_POOL` 新增第 7 项: `{"id": &"backpack_weight", "name": "+10 背包负重", "desc": "背包负重上限 +10"}`
- `_apply_upgrade_to_player` 新增 `match` 分支: `&"backpack_weight": _player.backpack_max_weight += 10.0`
- 加法叠加（每次 +10），效果立即生效

## 描述

在升级三选一卡池中新增"+10 背包负重"选项，允许玩家通过升级扩展背包容量。

## 验收标准

### 升级池扩展

`run_director.gd` 的 `UPGRADE_POOL` 新增一项：

```gdscript
{"id": &"backpack_weight", "name": "+10 背包负重", "desc": "背包负重上限 +10"},
```

- 总升级项从 6 变为 7
- `_pick_upgrades(3)` 仍随机抽不重复 3 项

### 升级生效

`_apply_upgrade_to_player` 新增 `match` 分支：

```gdscript
&"backpack_weight":
    _player.backpack_max_weight += 10.0
```

- 加法叠加（每次 +10）
- 效果立即生效，玩家可立即携带更多物品

### 验证

- 在 `tests/test_balance_wave_survival.tscn` 或其他升级测试中验证新选项出现并可选中
- 验证选中后 `player.backpack_max_weight` 增加了 10
