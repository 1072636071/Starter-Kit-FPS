Status: done

Blocked by: 01, 02

# T4 — 怪物移动/待机接入骨骼动画（替掉程序化 bob）

## 构建内容

让两个怪物（`monster_ranged`、`monster_melee`）的移动与待机**改用模型自带的骨骼剪辑**（`walk` / `run` / `sprint` / `idle`），取代现有 `_animate_walk` / `_animate_idle` 对 `Model` 父节点做的程序化 `rotation.x` / `position.y` 摆动。由一个轻量"动画选择器"按状态切换：移动中按速度选 `walk`/`run`/`sprint`，静止时近战怪播 `idle`、远程怪播 `holding-right`（保持持枪瞄准姿态）；攻击 one-shot 期间让位给攻击剪辑、结束后自动回到移动/待机。详见 `models/monsters/ANIMATIONS.md` §3、§6。

## 验收标准

- [x] 复用 T1/T2 已缓存的 `anim_player` 引用（`character_model.find_child("AnimationPlayer", true, false)`）；若 T1/T2 尚未合并，则本票在 `_ready()` 中自行建立该缓存（幂等，不与 T1/T2 重复声明冲突）
- [x] `_ready()` 中将移动/待机剪辑设为循环：`for n in ["walk","run","sprint","idle"]: anim_player.get_animation(n).loop = true`（这些 GLB 剪辑默认不循环，必须开启才能连续播放）
- [x] 删除 `_animate_walk` / `_animate_idle` 内的程序化 `model.rotation.x` / `model.position.y` 摆动（否则与骨骼动画在两层叠加产生双重抖动）
- [x] 新增动画选择器（每帧在 `_physics_process` 中调用），规则：
  - 若 `_is_attacking` 为真：不干预（攻击 one-shot 控制动画）
  - elif 实际移动速度 > 阈值：按速度选 `walk`（慢，strafe 半速）/ `run`（快，chase 全速）循环播放（**规格澄清**：原 spec 含 `sprint` 档，但怪物速度被钳制在 `move_speed`，`> move_speed * 1.3` 的 sprint 阈值永不可达——怪物无 sprint 速度源。已改为 walk/run 两档，`sprint` 剪辑保留循环设置但不选取）
  - else（静止）：近战怪播 `idle`；远程怪播 `holding-right`（瞄准姿态）
- [x] 仅在选择的目标剪辑**发生变化**时调用 `anim_player.play(name)`（用 `current_anim` 字符串记录上一帧选择，避免每帧重启动画）
- [x] 近战怪静止可见 `idle`、移动可见 `walk`/`run`；远程怪静止可见 `holding-right`（枪仍在 `arm-right` 手中）、移动可见 `walk`/`run` 等，无双重抖动
- [x] 攻击 one-shot（`attack-melee-right` / 远程开火反馈）期间选择器让位，攻击结束后自动恢复移动/待机剪辑

## 评论

- **背景（已核查）**：当前移动/待机**完全没有用骨骼动画**（`objects/monster_*.gd` 的 `_animate_walk`/`_animate_idle` 是纯 Tween），模型自带的 `walk`(0.667s)/`run`(0.500s)/`sprint`(0.500s)/`idle`(1.333s) 均闲置。本票实现 `ANIMATIONS.md` §6 标注的"未来增强"。
- **单 AnimationPlayer 约束**：导入场景只有一个 `AnimationPlayer`，同一时刻只能播一个主剪辑。故须用"选择器 + 仅在切换时 `play()`"的轻量状态机，而非每帧重播；攻击 one-shot 靠 `_is_attacking` 标志让位。不要用 `AnimationTree`（v1 过度设计）。
- 远程怪静止用 `holding-right` 而非 `idle`，以保留 T1 的"常驻持枪瞄准"语义；其 `walk` 等剪辑手臂不在瞄准位，但枪仍挂在 `arm-right` 随手臂摆动，可接受。
- 远程攻击本身不播独立攻击剪辑（T1 仅加后坐/闪光/音效并保留 `holding-right`），故攻击期间选择器让位时 `holding-right` 自然保持，符合"边瞄准边开火"。
- 不改动 `damage()` 的受击反馈（HitFeedback flash + 程序化 scale 挤压）与 `destroy()`（死亡动画见 T5）。
- 动画清单与时长见 `models/monsters/ANIMATIONS.md`；整体特性背景见 ADR 008。
