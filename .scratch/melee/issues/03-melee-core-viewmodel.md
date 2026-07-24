Status: ready-for-agent
Blocked by: 01, 02

# T3 — 近战核心逻辑 + 视图模型挥砍动画

## 构建内容

在 `player.gd` 中加入近战系统：新增 `@export` 调参（`melee_damage=40`、`melee_cooldown=0.5`）与 `@export` 视图模型场景引用（`melee_viewmodel`），在 `CameraItem` 下加入该视图模型并**默认隐藏**。监听 `melee` 输入动作；触发时若不在冷却中，则显示视图模型、用 `Tween` 播放一次挥砍动画（旋转/位移手臂持剑动作）、结束后收回隐藏，并进入冷却（`melee_cooldown`）。挥砍期间不依赖、也不影响现有 `Weapon`/`action_shoot`/弹药逻辑。可选：若有可用音源则播放一次近战挥砍音效。

## 验收标准

- [ ] `player.gd` 新增 `@export var melee_damage = 40`、`@export var melee_cooldown = 0.5`
- [ ] `@export` 引用 `melee_viewmodel` 场景，实例化置于武器相机下且初始 `visible = false`
- [ ] 按 V（`melee` 动作）触发一次挥砍：显示视图模型 → `Tween` 挥砍 → 结束隐藏
- [ ] 冷却中（0.5s 内）重复按 V 不重复触发，冷却结束方可再次挥砍
- [ ] 挥砍动画不改动 `container` 内枪械模型的位置/可见性（与远程武器互不干扰）
- [ ] 不修改 `Weapon` 资源、`action_shoot()`、弹药/换弹逻辑
- [ ] （可选）挥砍时播放一次音效（若项目有合适音源）

## 评论
