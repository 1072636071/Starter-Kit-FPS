# 04 — 命中标记系统

Status: needs-triage
Type: task
Refs: PRD.md, CONTEXT.md「Hit Marker」

## 描述

当前射击命中敌人后**无任何视觉/听觉确认**（除怪物受击泛红 Hit Flash 外）。补充命中标记：子弹命中时在准星位置短暂显示 × 形标记 + 短促"叮"音效。

## 验收标准

- 新增 `scripts/hit_marker.gd`（`extends Control`，独立场景或纯代码节点）：
  - 显示一个小 × 形（4 条短斜线），默认红色 `Color(1, 0.2, 0.2, 1)`
  - `trigger(color: Color = Color.RED)` 方法：显示 × → 200ms 内淡出 → 隐藏
  - `@export`：`marker_size: float = 8.0`，`line_thickness: float = 2.5`，`fade_duration: float = 0.2`
  - 用 `draw_line()` 绘制四条斜线
- HUD 挂载 `HitMarker` 实例于屏幕中心（准星位置）
- 弹体命中时触发命中标记——通过 Player 中转（选定方案 B）：
  - **Player** 新增公开方法 `hit_confirmed(global_position: Vector3)`，并发射信号 `hit_confirmed(pos: Vector3)`
  - **projectile.gd** 的 `_hit()` 方法中，在 `target.damage(damage)` 后新增：`if shooter and shooter.has_method("hit_confirmed"): shooter.hit_confirmed(impact_position)`
  - **HUD** 在 `_bind_player()` 中连接 `player.hit_confirmed.connect(_on_hit_confirmed)`，回调中调用 `hit_marker.trigger()` 和播放命中音效
  - beam 武器的射线命中（`_step_beam` 中的射线检测，当前第 920-922 行）也需要在 `collider.damage(...)` 后调用 `hit_confirmed(collision_point)`
- 音效：命中时播放短促音效 `sounds/hit_mark.ogg`（需准备或使用已有音效替代）
  - 音效在 HitMarker 中播，确保多连击时多个声音实例不互相打断（用 `AudioStreamPlayer` 池或 `Audio.play()` 多实例）
  - **实施前置**：`sounds/hit_mark.ogg` 需要先创建占位文件。临时方案：用已有的 `sounds/enemy_hurt.ogg` 作为 fallback（短促且主题相关），直到准备专用命中音效
- 可选：头部命中（如果未来实现）用金色 `Color(1, 0.8, 0.1, 1)`
- Hit Flash（现有怪物泛红）和 Hit Marker（新准星标记）同时触发，互补不冲突

## 技术要点

- HitMarker 是独立 Control，挂在 HUD CanvasLayer 下
- 利用 Godot 的 `create_tween()` 实现淡出动画
- 多连击：每个 `trigger()` 创建新 Tween，旧 Tween kill（显示最新命中标记）

## 评论

（无）
