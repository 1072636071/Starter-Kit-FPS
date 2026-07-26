# 按键说明面板集成测试

**Status:** resolved

**Blocked by:** 01

**构建内容：** 自动化集成测试验证按键说明面板的端到端行为——F5 打开/关闭、暂停状态正确切换、门控逻辑不误触发。测试模式对齐 `test_shop.gd` / `test_chest_expansion.gd`。

**验收标准：**

- [ ] 创建测试场景 `tests/test_controls_help.tscn`，含 HUD + Player mock + ControlsHelpUi
- [ ] 通过 `Input.parse_input_event()` 注入 F5 按键事件
- [ ] 断言 F5 按下后：`get_tree().paused == true`、面板 `visible == true`、鼠标 `MOUSE_MODE_VISIBLE`
- [ ] 断言再次 F5 后：`get_tree().paused == false`、面板 `visible == false`、鼠标 `MOUSE_MODE_CAPTURED`
- [ ] 门控测试：先手动设 `get_tree().paused = true`，再注入 F5 → 断言面板不出现
- [ ] 点击背景关闭测试：面板打开时模拟 `gui_input` 背景点击 → 断言面板关闭、游戏恢复
- [ ] 测试文件命名：`tests/test_controls_help.gd` + `tests/test_controls_help.tscn`

## 评论
