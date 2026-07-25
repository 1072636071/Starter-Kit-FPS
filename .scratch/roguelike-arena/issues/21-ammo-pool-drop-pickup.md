# 21 — 弹药池重构 + 丢弃拾取

Status: done
Type: task
Refs: ADR 022, issues 09/20

## 描述

将弹药系统从"每枪独立备弹数组"重构为"按弹药类型共享池"，同时实现丢枪（X 键）和地面拾取机制。

## 前置依赖

- [x] issue 09（`Weapon.ammo_type` 字段 + `Player` 弹药池槽位定义）
- [ ] issue 20（耐久度系统——丢弃/拾取需同步操作 `weapon_durability` 数组）

## 验收标准

### 弹药池重构

- [ ] `player.gd` 新增 `ammo_reserve: Dictionary = {&"手枪弹": 36, &"步枪弹": 0, &"霰弹": 0, &"狙击弹": 0, &"能量电池": 0, &"榴弹": 0}`
- [ ] 移除旧的 `reserve: Array[int]`（改为 `ammo_reserve`）
- [ ] 开火时改为从 `ammo_reserve[w.ammo_type]` 扣减（弹匣 `magazine` 数组不变）
- [ ] 换弹时改为从 `ammo_reserve[w.ammo_type]` 取出填弹匣
- [ ] `ammo_reserve` 变更时 emit `ammo_reserve_changed(dict)` 信号，HUD 监听更新
- [ ] 弹药归零时无法射击 + 无法换弹，显示提示"弹药耗尽"
- [ ] 搜索项目中所有引用 `player.reserve` 的代码（shop.gd / chest / 测试等），全部改为 `ammo_reserve` 方式

### 丢弃武器（X 键）

- [ ] `project.godot` 确认 `drop_weapon` 动作绑定 X 键
- [ ] `player.gd` 新增 `action_drop_weapon()` 逻辑：
  - 空手 → 忽略
  - 有枪 → 在 `global_position` 处 `instantiate(weapon_pickup_scene)`
  - 拾取物上设置：`weapon_resource`（`Weapon` 引用）、`durability_current`（当前耐久）
  - 从 `weapons` / `weapon_durability` / `magazine` / `reserve`（或 `ammo_reserve`）中移除该槽
  - 自动切下一把或空手
- [ ] 新建 `scenes/weapon_pickup.tscn` + `scripts/weapon_pickup.gd`：
  - `Area3D` + 该枪模型（缩小 0.3 倍，绕 Y 轴旋转）+ 小发光粒子
  - `body_entered` 检测 `"player"` 组 → 检查空槽
  - 有空槽 → 装填 + 设置耐久 + `queue_free()`
  - 3 槽全满 → 不拾取（武器留地上）
  - **允许重复武器**（不检查已持有同款）

### 测试

- [ ] `tests/test_ammo_pool.gd`：
  - 两把同弹种枪：A 开枪 → 断言 `ammo_reserve[type]` 减少；B 开枪 → 共享同一池
  - 弹药归零 → 断言无法射击 + 换弹后弹匣仍为 0
- [ ] `tests/test_weapon_drop_pickup.gd`：
  - 丢枪 → 断言地面出现 pickup 节点、武器槽减少
  - 走到 pickup → 断言自动装填、耐久为丢出时的值
  - 3 槽满时走过 → 断言 pickup 未消失
