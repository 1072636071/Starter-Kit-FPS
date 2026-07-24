Status: done

Blocked by: 01, 02

# T5 — 怪物死亡接入 `die` 骨骼剪辑（替掉程序化缩小）

## 构建内容

让两个怪物的死亡**改用模型自带的 `die` 骨骼剪辑**（0.333s 倒地动作），取代现有 `destroy()` 里整体缩小的程序化 Tween（`model.scale → 0.01` + 下移）。死亡时停止移动/攻击动画选择器、播放 `die` 一次，播放结束后 `queue_free`。详见 `models/monsters/ANIMATIONS.md` §3、§5、§6。

## 验收标准

- [x] 复用 T1/T2 已缓存的 `anim_player` 引用；若尚未建立则本票在 `_ready()` 中建立（幂等）
- [x] 在 `destroy()` 入口设置 `_dead = true` 标志，使 `_physics_process` 提前返回（死亡后不再移动、不再调用移动动画选择器），避免与 `die` 剪辑抢动画轨道
- [x] `destroy()` 中移除程序化缩小 Tween（`model.scale`/`position.y` 的 tween），改为 `anim_player.play("die")` 播一次
- [x] `die` 播完后再 `queue_free`：用 `anim_player.animation_finished` 信号（或 `SceneTree.create_timer(0.333)` 按 `ANIMATIONS.md` 记录的时长）触发释放；播放 `enemy_destroy.ogg` 逻辑保留
- [x] 死亡期间不再响应 `damage()`（已 `_dead` 的实体跳过受击/再死亡），`HitFeedback.flash` 的受击闪光仍可在死亡前正常工作（**规格澄清**：原 spec 括注"不改动 `damage()` 本身"指不改受击反馈机制（flash + scale 挤压），非排斥 `if _dead: return` 守卫——该守卫是"已 _dead 的实体跳过受击"的最小必要实现，已抽取到 `monster_base.gd::damage()`）
- [x] `die` 剪辑驱动 `root`/`torso`/`leg-*`/`arm-*` 表现倒地；怪物网格随 `CharacterModel` 内的骨骼动画播放，武器（若已挂 `arm-right`）随之倒下，无需额外处理

## 评论

- **背景（已核查）**：当前死亡**完全没有用骨骼动画**（`destroy()` 是纯 Tween 缩小），模型自带 `die`(0.333s) 完全闲置。本票实现 `ANIMATIONS.md` §6 标注的"未来增强"。
- `die` 时长 0.333s 取自 `ANIMATIONS.md`；若实际导入后时长有出入，以 `anim_player.get_animation("die").length` 为准驱动 `queue_free`，不硬编码 0.333。
- 与 T4（移动动画）共享 `anim_player` 与"单 AnimationPlayer"约束：死亡时须停掉移动选择器（用 `_dead` 标志），否则 `die` 与 `walk` 会互相覆盖。
- 不改动受击表现（受伤仍走 `damage()` 的程序化 scale 挤压 + HitFeedback，模型无 hurt 剪辑，见 `ANIMATIONS.md` §5）；死亡动画与受击反馈是正交的两条路径。
- 整体特性背景见 ADR 008；动画清单见 `models/monsters/ANIMATIONS.md`。
