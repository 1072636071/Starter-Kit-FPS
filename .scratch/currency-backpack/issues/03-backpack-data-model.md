# 03 — Player 背包数据模型 + 重量系统

Status: done
Type: task
Refs: PRD.md, ADR 023, CONTEXT.md「Backpack / Backpack Weight」

## 实现记录

- `player.gd` 新增 `backpack_items`、`backpack_weight`、`backpack_max_weight`（初始 80）
- `ITEM_WEIGHTS` 常量表（手枪弹 0.01, 步枪弹 0.02, 霰弹 0.04, 狙击弹 0.08, 能量电池 0.03, 榴弹 0.10, 血包 1.5）
- `_weapon_backpack_weight(w)` 枪械分档（≤5金→3, ≤10金→5, >10金→8）
- 背包操作接口: `backpack_add/remove/can_add/get_weight`
- `add_backpack_capacity(amount)` 升级扩展接口

## 描述

在 `Player` 中建立重量制背包数据结构，存子弹、枪械、血包。无格子上限，仅有重量上限（初始 80）。

## 验收标准

### 背包数据结构

`player.gd` 新增：

```gdscript
# 背包物品：{item_key: {type: StringName, count: int, weight_per_unit: float}}
var backpack_items: Dictionary = {}

# 当前总重量和上限
var backpack_weight: float = 0.0
var backpack_max_weight: float = 80.0
```

### 物品重量常量

在 `player.gd` 或独立常量文件中定义：

| 物品 | 重量/单位 |
|------|----------|
| 手枪弹 (`pistol_ammo`) | 0.01 |
| 步枪弹 (`rifle_ammo`) | 0.02 |
| 霰弹 (`shotgun_ammo`) | 0.04 |
| 狙击弹 (`sniper_ammo`) | 0.08 |
| 能量电池 (`energy_cell`) | 0.03 |
| 榴弹 (`grenade_ammo`) | 0.10 |
| 枪械 (`weapon`) | 3–8（按 `weapon_cost` 分档：≤5金→3, ≤10金→5, >10金→8） |
| 血包 (`health_pack`) | 1.5 |

### 背包操作接口

- `backpack_add(item_key: StringName, type: StringName, count: int, weight_per_unit: float) -> bool`：添加物品，超重返回 false，成功返回 true 并更新 `backpack_weight`
- `backpack_remove(item_key: StringName, count: int) -> int`：移除指定数量，返回实际移除数，更新 `backpack_weight`
- `backpack_get_weight(item_key: StringName) -> float`：查询某物品总重量
- `backpack_can_add(weight: float) -> bool`：检查可否再承受指定重量

### 初始状态

- 背包初始为空（`backpack_items = {}`, `backpack_weight = 0`）
- 初始 `backpack_max_weight = 80.0`

### 重量升级接口

- `add_backpack_capacity(amount: float)`：增加 `backpack_max_weight`
