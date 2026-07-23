# 06 - 修复射击时 get_global_transform 离树错误

Status: resolved
Type: task

## 问题描述

玩家射击时 `player.gd:201` 调用 `camera.global_transform`，当节点已离开场景树时产生大量运行时错误：

```
ERROR: Condition "!is_inside_tree()" is true. Returning: Transform3D()
   at: get_global_transform (scene/3d/node_3d.cpp:649)
   GDScript backtrace:
       [0] action_shoot (res://objects/player.gd:201)
       [1] handle_controls (res://objects/player.gd:126)
       [2] _process (res://objects/player.gd:55)
```

触发场景：玩家持续射击（鼠标按住）时坠落（y < -10）或死亡（health < 0），`reload_current_scene()` 导致节点离树，但 `_process` 在过渡帧仍被调用。

## 根因

两个缺陷叠加：

1. **无离树保护**：`_process()` 和 `action_shoot()` 未检查 `is_inside_tree()`，场景重载过渡期仍执行射击逻辑
2. **global_position 时序错误**：`projectile_instance.global_position = ...` 在 `add_child()` 之前调用，弹体尚未入树时设置全局坐标触发同类错误

## 修复内容

| 文件 | 修改 |
|------|------|
| `objects/player.gd` | `_process` 顶部加 `if not is_inside_tree(): return` |
| `objects/player.gd` | `action_shoot` 加 `if not camera.is_inside_tree(): return` |
| `objects/player.gd` | 弹体生成：先 `add_child`，再设 `global_position` |
| `objects/enemy.gd` | 同上：先 `add_child`，再设 `global_position` |

## 验收标准

- [x] 玩家射击中坠落/死亡不再产生 `!is_inside_tree()` 运行时错误
- [x] 正常射击功能不受影响（弹体方向、生成位置正确）
- [x] 敌人射击同样修复
- [x] 无 headless 测试中零 `is_inside_tree` 错误

## Regression 测试

```bash
godot --headless --path . res://tests/test_shoot_after_tree_exit.tscn --quit-after 20
```

stderr 出现 `is_inside_tree` = 回归；无 = 通过。

## 阻塞于

无
