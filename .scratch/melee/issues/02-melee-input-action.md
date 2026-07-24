Status: ready-for-agent
Blocked by: 无

# T2 — 注册 `melee` 输入动作（V 键）

## 构建内容

在 `project.godot` 的 `[input]` 段新增独立输入动作 `melee`，默认绑定 **V 键**（`physical_keycode = 86`）。已核查现有输入占用 W/A/S/D、Space、E、R 及鼠标键，V 空闲无冲突。该动作与 `shoot`/`aim`/`reload`/`weapon_toggle` 完全解耦，单独触发近战挥砍。

## 验收标准

- [ ] `project.godot` 出现 `"melee"` 输入动作定义
- [ ] 默认事件为 V 键（`physical_keycode` 86，无修饰键）
- [ ] 现有 `shoot`/`aim`/`reload`/`weapon_toggle`/`jump`/`mouse_capture*` 等动作不被改动
- [ ] 在编辑器中按 V 可触发 `Input.is_action_just_pressed("melee")`

## 评论
