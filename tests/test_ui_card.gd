## 测试 UICard 共享卡片组件：构造、pinned 高亮、delta 差异指示、标签访问器。
## 运行：godot --headless --path . res://tests/test_ui_card.tscn --quit-after 300
extends Node3D

var failures: int = 0


func _ready():
	call_deferred("_run_tests")


func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1


func _run_tests() -> void:
	var icon: Texture2D = UITheme.get_icon(UITheme.ICON_HEART)
	var accent := UITheme.COLOR_ACCENT_PRIMARY

	# === 1. UICard 创建成功（_init 构造） ===
	var card := UICard.new("测试标题", "测试描述", icon, accent)
	add_child(card)
	_check(card != null, "UICard 创建成功")
	_check(card is UICard, "UICard 类型正确")
	_check(card is PanelContainer, "UICard 继承 PanelContainer")

	# === 2. 卡片视觉：bg_panel 背景 + 4px 圆角 + 2px accent 描边 ===
	_check(card._stylebox.bg_color == UITheme.COLOR_BG_PANEL, "背景色 = COLOR_BG_PANEL")
	_check(card._stylebox.corner_radius_top_left == 4, "圆角 = 4px")
	_check(card._stylebox.corner_radius_top_right == 4, "圆角 = 4px")
	_check(card._stylebox.corner_radius_bottom_left == 4, "圆角 = 4px")
	_check(card._stylebox.corner_radius_bottom_right == 4, "圆角 = 4px")
	_check(card._stylebox.border_width_left == 2, "描边宽度 = 2px")
	_check(card._stylebox.border_width_right == 2, "描边宽度 = 2px")
	_check(card._stylebox.border_width_top == 2, "描边宽度 = 2px")
	_check(card._stylebox.border_width_bottom == 2, "描边宽度 = 2px")
	_check(card._stylebox.border_color == accent, "初始描边色 = accent")

	# === 3. set_pinned(true/false) 修改边框颜色 ===
	# set_pinned(true)：边框 = COLOR_ACCENT_PRIMARY 蓝色
	card.set_pinned(true)
	_check(card._stylebox.border_color == UITheme.COLOR_ACCENT_PRIMARY, "set_pinned(true) 边框 = COLOR_ACCENT_PRIMARY")
	# set_pinned(false)：边框恢复 = accent
	card.set_pinned(false)
	_check(card._stylebox.border_color == accent, "set_pinned(false) 边框恢复 = accent")

	# === 4. set_delta("DPS", true) 添加 ▲ 标签 ===
	card.set_delta("DPS", true)
	_check(card._delta_label.visible, "set_delta(true) 后标签可见")
	_check(card._delta_label.text.contains("▲"), "set_delta(true) 显示 ▲")
	_check(card._delta_label.text.contains("DPS"), "set_delta(true) 文本包含 label_text")
	var better_color: Color = card._delta_label.get_theme_color("font_color")
	_check(better_color == UITheme.COLOR_ACCENT_PRIMARY, "set_delta(true) 颜色 = COLOR_ACCENT_PRIMARY")

	# === 5. set_delta("DPS", false) 添加 ▼ 标签 ===
	card.set_delta("DPS", false)
	_check(card._delta_label.visible, "set_delta(false) 后标签可见")
	_check(card._delta_label.text.contains("▼"), "set_delta(false) 显示 ▼")
	_check(card._delta_label.text.contains("DPS"), "set_delta(false) 文本包含 label_text")
	var worse_color: Color = card._delta_label.get_theme_color("font_color")
	_check(worse_color == UITheme.COLOR_ACCENT_DANGER, "set_delta(false) 颜色 = COLOR_ACCENT_DANGER")

	# === 6. get_title_label / get_description_label 返回有效 Label ===
	var title_label: Label = card.get_title_label()
	_check(title_label != null, "get_title_label 返回非空")
	_check(title_label is Label, "get_title_label 返回 Label 类型")
	_check(title_label.text == "测试标题", "title_label 文本正确")

	var desc_label: Label = card.get_description_label()
	_check(desc_label != null, "get_description_label 返回非空")
	_check(desc_label is Label, "get_description_label 返回 Label 类型")
	_check(desc_label.text == "测试描述", "description_label 文本正确")

	# === 7. get_title_label / get_description_label 可外部更新文本 ===
	title_label.text = "新标题"
	_check(card.get_title_label().text == "新标题", "title_label 可外部更新")
	desc_label.text = "新描述"
	_check(card.get_description_label().text == "新描述", "description_label 可外部更新")

	# === 8. 内部布局：VBox [TextureRect icon, Label title, Label description, Label delta] ===
	var vbox := card.get_child(0) as VBoxContainer
	_check(vbox != null, "首个子节点为 VBoxContainer")
	if vbox:
		_check(vbox.get_child_count() == 4, "VBox 包含 4 个子节点（icon/title/desc/delta）")
		_check(vbox.get_child(0) is TextureRect, "VBox[0] = TextureRect (icon)")
		_check(vbox.get_child(1) is Label, "VBox[1] = Label (title)")
		_check(vbox.get_child(2) is Label, "VBox[2] = Label (description)")
		_check(vbox.get_child(3) is Label, "VBox[3] = Label (delta)")

	# === 报告 ===
	if failures == 0:
		print("[TEST] ALL PASSED")
	else:
		print("[TEST] %d FAILURES" % failures)

	# === 清理 ===
	card.queue_free()
