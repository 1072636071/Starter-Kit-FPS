extends Area3D
## issue 08：清场宝箱实体（元气骑士式）
##
## Area3D 检测 "player" 组进入 / 离开；玩家按 interact（weapon_toggle/E）开启。
## 开启 → 暂停 + 打开 ChestUI（3 选 1）；选择后 queue_free。
## process_mode = PROCESS_MODE_PAUSABLE（默认）；开箱暂停期间自身冻结。
##
## 信号 chest_reward_selected(reward_id) 在 queue_free 前发射，
## 由 RunDirector 在 _maybe_spawn_chest 时连接并 apply 奖励。

## 玩家进入范围时由 RunDirector/HUD 监听（供测试与 HUD 提示）
signal chest_opened(choices: Array)
## 玩家选择奖励后发射（queue_free 前），RunDirector 监听以 apply 奖励
signal chest_reward_selected(reward_id: StringName)

var _player_in_range := false
var _opened := false
var _float_tween: Tween

func _ready() -> void:
	add_to_group("chest")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_start_float_animation()

func _start_float_animation() -> void:
	# 轻微浮动 Tween（视觉提示）
	_float_tween = create_tween().set_loops()
	_float_tween.tween_property(self, "position:y", position.y + 0.15, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_tween.tween_property(self, "position:y", position.y, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range or _opened:
		return
	if get_tree().paused:
		return  # 已暂停（shop/level-up）时不触发开箱
	# interact 复用 weapon_toggle 动作（E 键）；暂停后 Player._process 冻结，切枪不会执行
	if event.is_action_pressed("weapon_toggle"):
		_open_chest()
		get_viewport().set_input_as_handled()

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_range = true
	_set_hud_chest_prompt(true)

func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_range = false
	_set_hud_chest_prompt(false)

func _set_hud_chest_prompt(show: bool) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_chest_prompt"):
		hud.show_chest_prompt(show)

func _open_chest() -> void:
	_opened = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_hud_chest_prompt(false)
	# 从 RunDirector 取奖励选项（用本局 rng 抽 3 不重复）
	var run_director := get_tree().get_first_node_in_group("run_director")
	if run_director == null or not run_director.has_method("pick_chest_rewards"):
		get_tree().paused = false
		queue_free()
		return
	var choices: Array = run_director.pick_chest_rewards()
	chest_opened.emit(choices)
	# 找 ChestUI（挂在 HUD 下，属 "chest_ui" 组）
	var chest_ui := get_tree().get_first_node_in_group("chest_ui")
	if chest_ui and chest_ui.has_method("open"):
		chest_ui.open(choices, self)
	else:
		# 无 UI 时直接恢复（测试环境）
		get_tree().paused = false

## 由 ChestUI 调用：玩家选择奖励后回调
## 发 chest_reward_selected 信号（RunDirector 监听 apply）
## 非随机武器奖励：立即 queue_free
## 随机武器奖励：延迟销毁，由 chest_ui 在替换流程结束后调用 finish_reward()
func apply_reward_selected(reward_id: StringName) -> void:
	chest_reward_selected.emit(reward_id)
	if reward_id != &"random_weapon":
		queue_free()
	# random_weapon: chest_ui 处理替换对话框后调用 finish_reward()

## 由 chest_ui 在替换对话框关闭后调用，确认宝箱可安全销毁
func finish_reward() -> void:
	if is_instance_valid(self) and is_inside_tree():
		queue_free()
