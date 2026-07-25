# 15 — 武器系统（20 把枪 + 耐久度 + 丢弃拾取 + 弹药商店 + 宝箱扩展 + 手雷）

Status: planning
Type: task
Refs: ADR 022, issues 04/08/09

## 描述

实现完整的武器扩展系统：导入全部 20 把枪的 GLB，创建 `.tres` 文件，实现耐久度+丢弃拾取机制，重构商店为三区 UI（武器/弹药/手雷），更新宝箱奖励池，实现手雷投掷逻辑。

## 前置依赖

- [ ] issue 09（Weapon Resource `ammo_type`/`weapon_cost`/`durability_max` 字段 + 弹药池 + 手雷槽 + 键位调整）
- [ ] issue 04（商店物理摊位）
- [ ] issue 08（宝箱系统）

## 验收标准

### 武器导入与 .tres 创建

- [ ] 从 `G:\work\游戏蔬菜\3D\武器\kenney_blaster-kit_2.1\Models\GLB format\` 导入全部 18 把新枪 GLB 到 `models/weapons/`
- [ ] 创建对应 `.tres` 文件到 `weapons/`，按 ADR 022 武器参数表填入全部 `@export` 值（含 `durability_max`）
- [ ] 持续射线枪 `.tres` 标记特殊行为类型（新增 `weapon_mode: StringName = "projectile" | "beam"`）
- [ ] 短柄榴弹发射器弹体需爆炸逻辑：弹体命中时 AOE 伤害

### 耐久度系统

- [ ] `player.gd` 中 `weapon_durability: Array[int]` 随 `weapons` 同步维护
- [ ] 每次扣扳机（含霰弹多弹丸齐射）`weapon_durability[current_index] -= 1`
- [ ] 持续射线枪按每秒消耗（`_process` 中每 `tick_interval` 减耐久）
- [ ] 耐久归零 → 枪**爆掉**：
  - 播放火花/碎片粒子特效（`GPUParticles3D`，一次性 0.3s）
  - 自动从 `weapons` + `weapon_durability` 移除该枪
  - 自动切下一把（或空手）
- [ ] 商店/宝箱获得的新枪耐久设为 `durability_max`（满）
- [ ] HUD 每把武器图标下方显示耐久进度条（≤20% 变红）

### 丢弃与拾取

- [ ] `drop_weapon`（X 键）触发逻辑：
  - 当前手持武器在玩家脚下位置 spawn 一个拾取物节点（`scenes/weapon_pickup.tscn`）
  - 拾取物：`Area3D` + 该枪模型（缩小/旋转）+ 发光粒子
  - 保留耐久度数据在拾取物上（`pickup.durability_current`）
  - 从 `weapons` 和 `weapon_durability` 数组中移除该枪
  - 若还有其余槽位的枪 → 自动切到下一把；若全丢了 → 空手
- [ ] 拾取逻辑：拾取物 `body_entered` 检测 `"player"` 组
  - 有空槽 → 自动装填到第一个空槽、`weapon_durability` 同步设置、`queue_free()`（**允许重复武器**——不检查是否已持有同款枪）
  - 3 槽全满 → 不拾取（武器留在地上）
- [ ] 空手时无法丢枪（什么都不发生）

### 弹药池集成

- [ ] 所有武器 `ammo_type` 正确设置
- [ ] 开火消耗 `ammo_reserve[ammo_type]`（若为 0 无法射击，提示"弹药耗尽"）
- [ ] 换弹从 `ammo_reserve[ammo_type]` 取出填弹匣
- [ ] 商店买弹药捆 → `ammo_reserve[ammo_type] += bundle_amount`

### 商店 UI 三区设计

- [ ] 武器区：随机展示 3 把枪，显示模型预览 + 名称 + 价格 + 弹药类型 + 耐久度
  - 有空槽 → "购买"按钮
  - 3 槽全满 → "购买并替换"按钮，弹出 3 槽选择对话框
  - 购买的枪耐久度 = `durability_max`（全新）
- [ ] 弹药区：随机展示 3–4 种弹药捆（6 种中不重复抽），按 ADR 022 价格表：
  - 手枪弹捆 24 发/**1 金**、步枪弹捆 20/**2 金**、霰弹捆 8/**3 金**、狙击弹捆 4/**4 金**、能量电池捆 12/**3 金**、榴弹捆 2/**5 金**
- [ ] 手雷区：随机展示 1–2 种手雷（EMP 25 金/破片 20 金）
- [ ] 购买后金币扣减、UI 即时更新
- [ ] UI 为 `PROCESS_MODE_WHEN_PAUSED`

### 手雷投掷系统

- [ ] 新增 `player.gd` 手雷投掷逻辑：
  - 按 G（`throw_grenade`）开始蓄力/瞄准（显示抛物线预览）
  - 释放 G 投掷当前选中手雷类型
  - 按住 G + 滚轮/caps 切换手雷类型
- [ ] EMP 手雷：落地后 0.5s 引爆，`radius = 6.0m`，范围内敌人减速（移速×0.3）持续 3s、沉默（禁用 ATTACK 状态）持续 3s
- [ ] 破片手雷：落地后 0.8s 引爆，`radius = 5.0m`，`damage = 40`，抛物线衰减
- [ ] 手雷投掷后 `grenades[type] -= 1`，归零不可选

### 宝箱扩展

- [ ] 宝箱奖励池扩展条目（在 issue 08 `CHEST_REWARD_POOL` 中追加）：
  - `random_weapon`：从 20 把枪池中按稀有度加权抽 1 把（低档 60%：cost ≤ 70；中档 25%：cost 71–120；高档 15%：cost > 120），满耐久
  - `grenade_supply`：EMP +1、破片 +1
- [ ] `apply_chest_reward("random_weapon")` 逻辑：若玩家有空槽则直接装；满则弹替换对话框
- [ ] `apply_chest_reward("grenade_supply")` 逻辑：不超过 `max_grenades`

### 测试

- [ ] `tests/test_weapon_ammo_pool.gd`：验证购物前后 `ammo_reserve` 正确增减
- [ ] `tests/test_weapon_durability.gd`：验证耐久消耗、归零禁火、HUD 变化
- [ ] `tests/test_weapon_drop_pickup.gd`：验证丢枪 spawn、拾取装填、满槽不拾取
- [ ] `tests/test_weapon_shop.gd`：验证商店商品随机性、购买装填/替换流程、新枪满耐久
- [ ] `tests/test_grenade.gd`：验证投掷距离、EMP 减速/沉默、破片伤害范围
