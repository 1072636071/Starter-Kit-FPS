# 09 — 换弹音效（每枪独立）

Status: needs-triage
Type: task
Refs: PRD.md, CONTEXT.md「Reload Sound」

## 描述

当前 `action_reload()` 完全静音。为 Weapon 资源新增 `sound_reload` 字段，换弹时播放对应音效。

## 验收标准

- Weapon 资源 `@export_subgroup("Sounds")` 下新增：
  - `@export var sound_reload: String = ""` — 换弹音效路径，空字符串 = 静音（向后兼容）
- `action_reload()` 中在 `is_reloading = true` 后：
  - `if not w.sound_reload.is_empty(): Audio.play(w.sound_reload)`
- 如果 15 把枪的 `.tres` 暂未配置 `sound_reload`：
  - v1 提供一个 fallback 默认音效 `sounds/reload_default.ogg`（通用换弹声）
  - 当 `sound_reload == ""` 时播放默认音效
- 换弹取消（`_cancel_reload()`）时不触发音效（已完成自然收尾）

## 技术要点

- `Audio.play()` 已支持多实例，换弹被切枪中断时新音效自然覆盖
- 音效时长需 ≤ `reload_time`（换弹音效通常 1–2 秒）
- **实施前置**：`sounds/reload_default.ogg` 需要先创建占位文件。如果音效资源尚未准备，可先用已有的 `sounds/weapon_change.ogg` 作为临时 fallback，或创建一个短的空白 ogg 文件避免 `Audio.play()` 报错
- 默认音效文件需准备（或从免费音效库获取）

## 评论

（无）
