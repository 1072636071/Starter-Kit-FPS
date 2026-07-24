Status: ready-for-agent
Blocked by: 无

# T2 — 注册 `melee` 输入动作（V 键）

## 构建内容

在 `project.godot` 的 `[input]` 段新增独立输入动作 `melee`，默认绑定 **V 键**（`physical_keycode = 86`）。已核查现有输入占用 W=87/A=65/S=83/D=68（移动）、Space=32（跳）、E=69（切枪）、R=82（换弹）、Esc=4194305（鼠标释放）、鼠标左键（射击）、鼠标右键（瞄准），**V=86 空闲无冲突**。该动作与 `shoot`/`aim`/`reload`/`weapon_toggle` 完全解耦，单独触发近战挥砍。

## 输入条目格式

参照现有 `reload` 条目格式（仅键盘，无手柄映射）：

```
melee={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":86,"key_label":0,"unicode":118,"location":0,"echo":false,"script":null)
]
}
```

## 验收标准

- [ ] `project.godot` 的 `[input]` 段出现 `"melee"` 输入动作定义
- [ ] 默认事件为 V 键（`physical_keycode = 86`，`unicode = 118`，无修饰键）
- [ ] 现有 `shoot`/`aim`/`reload`/`weapon_toggle`/`jump`/`move_*`/`camera_*`/`mouse_capture*` 等动作**不被改动**
- [ ] 在编辑器中按 V 可触发 `Input.is_action_just_pressed("melee")`

## 评论

- 不绑手柄按钮——近战为快节奏副攻击，键盘足够；手柄玩家可后续在编辑器手动加映射
- 与 `reload`（R 键）格式一致：仅键盘 + `physical_keycode`，便于跨键盘布局兼容
