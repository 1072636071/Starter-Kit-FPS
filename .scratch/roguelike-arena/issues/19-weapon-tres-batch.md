# 19 — 武器 .tres 批量创建（18 把新枪）

Status: ready-for-agent
Type: task
Refs: ADR 022, issue 09

## 描述

导入全部 18 把新枪 GLB，创建对应 `.tres` 文件，填入 ADR 022 武器参数表中的全部数值。**纯数据工单**——不改 player/shop/HUD 逻辑。

## 前置依赖

- [x] issue 09（`Weapon` 资源 `ammo_type` / `weapon_cost` / `durability_max` / `role_title` / `role_features` / `reliability_stars` 字段已添加）

## 验收标准

### GLB 导入

- [ ] 从 `G:\work\游戏蔬菜\3D\武器\kenney_blaster-kit_2.1\Models\GLB format\` 导入全部 18 把枪 GLB → `models/weapons/`
- [ ] 每个 GLB 生成 `.import` 文件，确认材质/纹理路径正确

### .tres 创建

按 ADR 022 武器参数表创建 18 个 `.tres` 文件至 `weapons/`，每文件含：

| 字段 | 说明 |
|------|------|
| `model` | GLB 路径 |
| `display_name` | 中文名 |
| `damage` / `cooldown` / `spread` / `shot_count` | 战斗参数 |
| `magazine_size` / `max_reserve` / `reload_time` | 弹药参数 |
| `ammo_type` | 弹药类型 StringName |
| `weapon_cost` | 售价（金） |
| `durability_max` | 最大耐久 |
| `role_title` / `role_features` / `reliability_stars` | 身份字段 |

参数值见 ADR 022 武器参数表（已在本会话中更新为最终版）。

### 特殊行为标记

- [ ] `Weapon` 资源新增 `weapon_mode: StringName = &"projectile"`（默认）
- [ ] 持续射线枪 `.tres` 设置 `weapon_mode = &"beam"`
- [ ] 短柄榴弹发射器 `.tres` 设置 `projectile_explosion = true`（新增 `@export var projectile_explosion: bool = false`），便于后续 issue 实现 AOE 弹体

### 旧枪更新

- [ ] `weapons/blaster.tres` 和 `weapons/blaster-repeater.tres` 补全身份字段（已在之前会话中填充，本工单确认无遗漏）

### 测试

- [ ] `tests/test_weapon_tres.gd`：加载全部 20 个 `.tres` → 断言关键字段非默认值（`damage > 0`、`ammo_type != ""`、`durability_max > 0`）
- [ ] 断言弹药类型正确分布在 6 种之中
- [ ] 断言 `weapon_mode` 只有 &"projectile" 和 &"beam" 两种值
