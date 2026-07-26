# 04 — 10 备弹槽 + 换弹逻辑改造

Status: done
Type: task
Refs: PRD.md, ADR 023, CONTEXT.md「Ammo Slot / Reload」

## 实现记录

- `player.gd` 新增 `AMMO_SLOT_COUNT = 10`、`ammo_slots: Array[Dictionary]`，`_ready()` 初始化为 10 空槽
- `action_reload()` 改造：遍历 `ammo_slots` 找匹配弹种 → `remaining -= 1`（不再使用 `ammo_reserve`）
- `_step_reload()`: 完成时直接填满弹匣到 `magazine_size`
- 新增 `get_available_reloads(ammo_type)`、`get_slot_status()`、`set_ammo_slot(idx, type, remaining, capacity)`
- `get_reserves_snapshot()` 改为从备弹槽计算；`_emit_ammo_updated()` 的 reserves 同样改为备弹槽来源
- `ammo_reserve` 字典保留字段但换弹逻辑不再读取；HUD 右下角弹药列表适配备弹槽

## 描述

在 Player 中建立 10 个备弹槽（每槽 = 一弹匣量，可自由分配弹种），改造换弹逻辑从消费 `ammo_reserve` 改为消费备弹槽。现有 `ammo_reserve` 字典保留但不再被换弹逻辑使用。

## 验收标准

### 备弹槽数据结构

`player.gd` 新增：

```gdscript
# 10 个备弹槽，每槽 {ammo_type: StringName, remaining: int}
# remaining 为该槽还可以提供多少次弹匣填充（初始由背包 UI 设置）
var ammo_slots: Array[Dictionary] = []
# 初始化 10 个空槽
# ammo_slots 每项: {"ammo_type": &"", "remaining": 0, "capacity": 0}
```

- 槽位数量：`const AMMO_SLOT_COUNT := 10`
- 在 `_ready()` 中初始化为 10 个空槽

### 换弹逻辑改造

- `action_reload()` 中：
  1. 获取当前武器 `ammo_type` 和 `magazine_size`
  2. 遍历 `ammo_slots`，找到第一个 `ammo_type` 匹配且 `remaining > 0` 的槽
  3. 从该槽 `remaining -= 1`，将 `magazine_size` 发子弹填入弹匣
  4. 若所有匹配槽 `remaining == 0`，无法换弹，可选提示"备弹槽已空"
- 换弹时间不变（仍用 `reload_time`）

### 备弹槽查询

- `get_available_reloads(ammo_type: StringName) -> int`：返回所有匹配槽的 `remaining` 之和
- `get_slot_status() -> Array`：返回 10 个槽的 `{ammo_type, remaining, capacity}` 摘要

### 备弹槽设置

- `set_ammo_slot(slot_idx: int, ammo_type: StringName, remaining: int, capacity: int)`：
  由背包 UI（issue 05）调用，设置某个槽的类型和容量
  - `capacity` = 对应弹种的 `magazine_size`
  - `remaining` = 该槽能填充的弹匣次数

### 废弃旧弹药池

- `ammo_reserve` 字典保留字段但不被换弹逻辑读取
- `_emit_ammo_updated()` 发射的数据改为从备弹槽计算

### HUD 弹药显示适配

- 右下角弹药列表改从备弹槽计算各弹种还能换弹次数（而非 `ammo_reserve` 总量）
