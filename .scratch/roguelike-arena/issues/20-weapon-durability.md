# 20 — 耐久度系统（扣减 + 爆枪 + HUD）

Status: ready-for-agent
Type: task
Refs: ADR 022, issues 09/19

## 描述

在 `player.gd` 中实现武器耐久度生命周期：开火扣耐久 → 归零爆枪 → 自动切下一把。同时给 HUD 右下角弹药列表加耐久进度条。

## 前置依赖

- [x] issue 09（`Weapon.durability_max` 字段）
- [ ] issue 19（`.tres` 文件存在，含 `durability_max` 值）

## 验收标准

### 耐久度数据结构

- [ ] `player.gd` 新增 `weapon_durability: Array[int]`，与 `weapons` 数组同步维护
- [ ] 获取新武器时（商店购买 / 宝箱 / 地面拾取）：`weapon_durability.insert(slot, weapon.durability_max)`
- [ ] 丢弃武器时同步移除 `weapon_durability[slot]`

### 扣减逻辑

- [ ] 每次扣扳机（`_fire_bullet()` 方法末尾）：`weapon_durability[current_index] -= 1`
- [ ] 霰弹多弹丸齐射只减 1 次（与 `shot_count` 无关）
- [ ] 持续射线枪（`weapon_mode == "beam"`）：`_process` 中按 `tick_interval`（如 1s）减耐久

### 爆枪

- [ ] 耐久归零时触发 `_break_weapon(slot)`：
  - 播放一次性 `GPUParticles3D` 火花/碎片特效（在玩家枪模位置，0.3s）
  - 从 `weapons` + `weapon_durability` 数组中 `remove_at(slot)`
  - 从 `magazine` + `reserve` 数组中同步移除
  - 自动切下一把：`change_weapon(clampi(current_index, 0, weapons.size() - 1))`
  - 若全爆 → 空手，显示提示
- [ ] 空手时不触发扣减（无枪可爆）

### HUD 耐久显示

- [ ] `scripts/hud.gd` 的 `_build_list()` 中，每把武器名称下方新增耐久进度条：
  - 条宽同武器名，高 4px
  - 填充比例：`weapon_durability[i] / weapon.durability_max`
  - 颜色：`> 60%` 绿 → `≤ 60%` 黄 → `≤ 20%` 红
  - 当前武器高亮时进度条也稍亮
- [ ] `_on_ammo_updated` 中同步刷新耐久条

### 测试

- [ ] `tests/test_weapon_durability.gd`：
  - 初始化 player + 枪（durability_max = 5），连续开火 5 次 → 断言枪被移除、自动切槽
  - 霰弹枪（shot_count=6）开火 1 次 → 断言 durability 只减 1
  - 3 把枪全爆 → 断言 `weapons.size() == 0`、空手状态
  - 商店购买新枪 → 断言 `weapon_durability[slot] == weapon.durability_max`
