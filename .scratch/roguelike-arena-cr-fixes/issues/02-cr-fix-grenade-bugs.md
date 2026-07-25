# 02 — 手雷系统三 bug 修复

**Status:** done

**Blocked by:** 无——可立即开始

**构建内容：** 修复手雷系统（issue 23）三个已实现的 bug，使手雷投掷行为与 spec 一致。

**验收标准：**

### grenade_switch 按键修复

- [ ] `project.godot` 中 `grenade_switch` 输入动作从 `physical_keycode=4194306`（Tab）改为滚轮或 CapsLock
- [ ] 推荐方案：绑定鼠标滚轮上下（`physical_keycode` 对应滚轮），蓄力期间滚轮切换 EMP ↔ 破片
- [ ] 切换时 HUD 手雷区域即时高亮当前选中类型
- [ ] 确认不再与 Tab（武器检视）冲突

### EMP 引爆顺序修复

- [ ] 移动 `grenade_projectile.gd` 中 EMP 分支：先 `await get_tree().create_timer(0.5)` 再播放 `_spawn_explosion_vfx` + 施加效果
- [ ] 当前是"先播特效再等 0.5s"——视觉与逻辑不同步，玩家看到爆炸但效果延迟

### 投掷后 HUD 信号链

- [ ] `player.gd::_throw_grenade()` 扣减手雷数量后，发射信号或调用方法通知 HUD 刷新
- [ ] 移除 HUD 中 `_process` 每帧轮询 `_player.grenades` 的依赖——改为信号驱动
- [ ] 投掷后 HUD 手雷数量数字即时更新（无帧延迟）

## 评论

（评论与对话历史追加于此，新内容置于最前。）
