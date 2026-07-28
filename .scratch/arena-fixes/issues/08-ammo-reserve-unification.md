# 08 — 备弹系统三层统一重构

> triage: `ready-for-agent`

## 问题陈述

当前备弹系统存在两套并行存储：旧的 `ammo_reserve: Dictionary`（按弹药类型共享池）和新的 `ammo_slots: Array[Dictionary]`（10 个备弹槽）。换弹逻辑（`action_reload`）只读 `ammo_slots`，但商店购买、宝箱补给仍写入 `ammo_reserve`，导致买到的弹药永远无法被换弹消耗——两套系统数据断连。此外，备弹槽 HUD 显示 `[remaining/capacity]` 单位是弹匣次数而非实际发数，玩家看到的数字不直观。

## 解决方案

彻底退役 `ammo_reserve`，统一为三层弹药流模型：

```
背包 backpack_items（仓库）→ 备弹槽 ammo_slots（快速取用）→ 弹匣 magazine（装填）
```

所有外部弹药补给（商店、宝箱）写入背包层；玩家按 B 打开背包手动分配到备弹槽；换弹 R 键消耗备弹槽；HUD 显示实际发数。

## 用户故事

1. 作为玩家，我想要商店购买的弹药进入背包，以便我可以通过背包 UI 统一管理所有弹药
2. 作为玩家，我想要在背包 UI 中点击弹药再点击备弹槽来分配弹药，以便我控制哪些弹种放在快速取用槽
3. 作为玩家，我想要 HUD 上的备弹数字显示实际发数（如 96 发），以便我直观知道还有多少子弹可用
4. 作为玩家，我想要换弹时从备弹槽消耗弹药（每次换弹 = 1 弹匣量），以便备弹槽的弹药逐步减少
5. 作为玩家，我想要备弹槽打空后按 B 从背包补货，以便形成"背包→槽→弹匣"的自然补给节奏
6. 作为玩家，我想要宝箱的备弹补给也进入背包，以便与商店购买走同一入口、体验一致
7. 作为开发者，我想要 `ammo_reserve` 彻底退役，以便消除两套并行系统的数据断连问题
8. 作为开发者，我想要 `get_reserve()` / `add_reserve()` 标记废弃，以便渐进迁移而不破坏现有调用方

## 实现决策

### 数据模型

- **`ammo_reserve: Dictionary`**：标记 `@deprecated`，字段保留但不再作为弹药数据源。`get_reserve()` 内部改为从 `ammo_slots` 汇总计算；`add_reserve()` 内部改为调用 `backpack_add()`
- **`ammo_slots` 的 `remaining` 字段**：语义不变，仍以弹匣次数为单位（每次背包分配 +1，每次换弹 −1）
- **`ammo_slots` 的 `capacity` 字段**：语义不变，= 对应武器的 `magazine_size`（即该槽最多能装几个弹匣量）
- **HUD 显示换算**：备弹发数 = `slot.remaining × weapon.magazine_size`；总备弹 = 所有匹配弹种槽的 `remaining` 之和 × `magazine_size`

### 补给入口迁移

- **商店 `shop.gd` / `shop_ui.gd`**：弹药购买从 `add_reserve()` 改为 `backpack_add()`，弹药进背包层
- **宝箱 `chest.gd`**：备弹补给奖励从写 `ammo_reserve` 改为 `backpack_add()`
- **RunDirector 初始化**：开局弹药初始化从 `ammo_reserve[ammo_type] = 36` 改为 `backpack_add()` 写入背包

### 显示层迁移

- **HUD `hud.gd`**：备弹数字从 `get_reserve(w)` 改为遍历 `ammo_slots` 汇总 `remaining × magazine_size`
- **背包 UI `backpack_ui.gd`**：右侧备弹槽显示从 `[remaining/capacity]` 改为 `[remaining×mag_size / capacity×mag_size]`（实际发数）
- **武器检视 `weapon_inspect_ui.gd`**：备弹字段同步改为从 `ammo_slots` 读取

### 初始化流程

- 开局初始化：首把武器的弹药类型按 100 发总量写入 `backpack_items`（而非直接填 `ammo_slots`）
- `ammo_slots` 初始全空（10 个空槽），玩家首次按 B 打开背包时手动分配

### 废弃策略

- `get_reserve(w)` → 内部改为 `get_available_reloads(w.ammo_type) * w.magazine_size`
- `add_reserve(w, amount)` → 内部改为 `backpack_add(w.ammo_type, &"ammo", amount, ITEM_WEIGHTS[...])`
- 标记 `@deprecated` 注释，后续清理时删除

## 测试决策

- **好测试的描述**：测试外部行为（弹药从背包→槽→弹匣的流转结果），不测内部字段
- **测试模块**：
  - `player.gd`：`backpack_add` → `ammo_slots` 分配 → `action_reload` 消耗的完整链路
  - `shop.gd`：购买弹药后 `backpack_items` 数量正确增加
  - `chest.gd`：备弹补给后 `backpack_items` 数量正确增加
  - `hud.gd`：备弹显示值 = `ammo_slots` 汇总 × `magazine_size`
- **测试先例**：`tests/` 目录下已有的 player 相关测试（如 `test_backpack_*.gd`）

## 超出范围

- 背包 UI 的拖拽交互改进（当前是点击分配，不做拖拽）
- `ammo_reserve` 字段的物理删除（本次只标记废弃，后续清理 issue 处理）
- 备弹槽数量扩展（保持 10 个不变）
- 弹药类型新增（保持现有 6 种不变）
- `Weapon.max_reserve` 字段处理（本次不动，后续可标记废弃）

## 补充说明

### 变更文件清单

| 文件 | 变更类型 |
|------|---------|
| `objects/player.gd` | 修改：`get_reserve` / `add_reserve` 废弃 + 内部改读 `ammo_slots`；初始化流程改为 `backpack_add` |
| `scripts/shop.gd` / `scripts/shop_ui.gd` | 修改：弹药购买改为 `backpack_add` |
| `scripts/chest.gd` | 修改：备弹补给改为 `backpack_add` |
| `scripts/hud.gd` | 修改：备弹显示改为从 `ammo_slots` 读 |
| `scripts/backpack_ui.gd` | 修改：槽位显示改为实际发数 |
| `scripts/weapon_inspect_ui.gd` | 修改：备弹字段改为从 `ammo_slots` 读 |
| `scripts/run_director.gd` | 修改：开局弹药初始化改为 `backpack_add` |
| `CONTEXT.md` | 已更新：`Ammo Pool` / `Reserve` / `ammo_reserve` / `Backpack` / `Ammo Slot` 条目 |
