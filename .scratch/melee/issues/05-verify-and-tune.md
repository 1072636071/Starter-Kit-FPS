Status: ready-for-agent
Blocked by: 04

# T5 — 端到端验证与手感调参

## 构建内容

在 [scenes/main.tscn](file:///e:/work/sp/Starter-Kit-FPS/scenes/main.tscn) 中实测近战端到端链路，按以下场景逐项验证。根据实测手感按需微调 `@export` 的 `melee_damage`/`melee_cooldown`/`melee_reach` 及命中区宽高，确认与现有枪械系统（弹药、HUD、ADS、换弹）无任何冲突或回归。

## 测试场景

### 场景 1：基础挥砍链路

- 在 `scenes/main.tscn` 中确认 Player 节点的 `melee_viewmodel` 字段已指向 `objects/melee_viewmodel.tscn`
- 启动场景，按 V 应能发动挥砍：
  - 剑视图模型从右上→左下划过屏幕（下劈动画）
  - 0.4s 后剑收回隐藏
  - 0.5s 冷却期间重复按 V 无反应
- 视觉与节奏符合预期

### 场景 2：命中扣血与泛红

- 将 `monster_melee.tscn` 怪物放在玩家正前方 1.5m 处
- 按 V 挥砍，活跃帧期间应命中：
  - 怪物扣血 40（`monster_melee.health = 120`，3 次挥砍可击杀）
  - 怪物自动泛红（`HitFeedback.flash` 触发）
  - 同一次挥砍即使命中区重叠多帧也只扣一次血（`_melee_hit_targets` 去重生效）
- 重复挥砍 3 次击杀怪物，验证死亡动画播放

### 场景 3：命中区几何与朝向

- 玩家正前方 1.5m 处放置 `monster_melee`，按 V 应命中
- 玩家正前方 3m 处放置 `monster_melee`，按 V 不应命中（超出 `melee_reach = 2.0m`）
- 玩家正后方 1m 处放置 `monster_melee`，按 V 不应命中（命中区在身前）
- 玩家左侧 1m 处放置 `monster_melee`，按 V 不应命中（命中区宽 1.5m，半宽 0.75m 不够到 1m 外）
- 玩家上方 2m 处放置 `enemy` 飞行敌（看天时），按 V **不**应命中（命中区 yaw-only，不随 pitch 倾斜）——验证 Q2 决策

### 场景 4：多怪同框去重

- 玩家正前方 1m 处并排放 2 个 `monster_melee`（间距 0.5m，均在命中区内）
- 按 V 一次挥砍，**两个怪都应被扣血**（同一挥砍可命中多个敌人）
- 按 V 第二次挥砍（冷却后），两个怪再次被扣血

### 场景 5：近战-换弹并发

- 装备弹匣非满的武器，按 R 触发换弹（`reload_time` 期间）
- 换弹进行中按 V，**应能正常触发挥砍**（互不阻塞）
- 挥砍进行中按 R，**应能正常触发换弹**（互不阻塞）
- 验证换弹完成后弹匣正确填充、HUD 进度条正常消失

### 场景 6：远程武器无回归

- 装备枪械，按左键射击：弹体正常发射、弹药扣减、HUD 更新、ADS（右键）正常
- 按切枪键（E）：武器正常切换、近战 viewmodel 不受影响
- 同时按射击 + V：两者各自独立触发（不冲突）

### 场景 7：薄墙边缘情况（已知，仅记录）

- 在玩家与怪物之间放一堵 `wall_low.tscn`（薄墙），怪物在墙后 0.5m
- 按 V 挥砍：**预期会穿墙命中**（v1 已知边缘情况，见 CONTEXT.md「Melee Hitbox Wall Piercing」）
- 记录此行为，不在 v1 修复

## 调参范围

如手感不佳，可调整以下 `@export` 默认值（均在 `player.gd`）：

- `melee_damage`：40 → 范围 30–60（一刀斩杀小怪需 2–4 刀）
- `melee_cooldown`：0.5s → 范围 0.3–0.8s
- `melee_reach`（命中区深度）：2.0m → 范围 1.5–2.5m
- 命中区宽高：1.5m → 范围 1.0–2.0m（在 `player.tscn` 的 `BoxShape3D_melee.size` 调）

挥砍时序（`SWING_DURATION`/`ACTIVE_START`/`ACTIVE_END`）为 `const`，调参时不改——如确需调，须同步更新 CONTEXT.md 与 ADR 006。

## 验收标准

- [ ] 场景 1：按 V 可稳定发动近战，剑模型下劈显示/收回正常，0.5s 冷却节奏可接受
- [ ] 场景 2：命中 `monster_melee` 可扣血 40 并可见 Hit Flash 泛红；3 次挥砍可击杀；单次挥砍对同一敌人只扣一次血
- [ ] 场景 3：命中区几何符合预期（前方 1.5m 命中、3m 不命中、身后/侧方不命中、上方不命中）
- [ ] 场景 4：多怪同框单次挥砍均被命中
- [ ] 场景 5：近战-换弹互不阻塞，各自独立触发
- [ ] 场景 6：远程武器、弹药 HUD、ADS、换弹行为均不受近战影响（无回归）
- [ ] 场景 7：薄墙穿墙行为被记录为已知边缘情况，不在 v1 修复
- [ ] 调参结果以 `@export` 默认值固化，无需硬编码
- [ ] 挥砍时序常量（`SWING_DURATION`/`ACTIVE_START`/`ACTIVE_END`）未被修改

## 评论

- 本工单无代码改动，仅验证与调参
- 所有验收标准均对应 T1–T4 的具体决策，参见各工单「评论」中的 grill 会话引用
- 通过后近战系统 v1 完成；未来增强项：挥砍音效、RayCast 视线检查防穿墙、左右交替挥砍变体、AnimationPlayer 替代 Tween
