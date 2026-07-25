## 近战挥砍过渡动画 测试（issue: melee-transitions）
## 运行：godot --headless --path . res://tests/test_melee_transitions.tscn --quit-after 900
## 判定：[TEST] PASS 即通过；任何 [TEST] FAIL 即失败（脚本自行 quit(1)）
extends Node

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
	var player_scene := preload("res://objects/player.tscn")
	var player: CharacterBody3D = player_scene.instantiate()
	add_child(player)

	# === 循环 1：常量契约（时序包2：windup/active/recover = 0.2/0.2/0.2）===
	# 来源：.scratch/melee-transitions/issue.md「时序契约」
	_check(abs(float(player.get("melee_cooldown")) - 0.7) < 0.001,
		"melee_cooldown default == 0.7 (got %f)" % float(player.get("melee_cooldown")))
	_check(float(player.SWING_DURATION) == 0.6,
		"SWING_DURATION == 0.6 (got %f)" % float(player.SWING_DURATION))
	_check(float(player.ACTIVE_START) == 0.2,
		"ACTIVE_START == 0.2 (got %f)" % float(player.ACTIVE_START))
	_check(float(player.ACTIVE_END) == 0.4,
		"ACTIVE_END == 0.4 (got %f)" % float(player.ACTIVE_END))

	# 等一帧让 _ready 中的 instantiate 完成
	await get_tree().process_frame

	# === 循环 2：冷却门禁 + hitbox monitoring 窗 ===
	# 来源：issue.md「测试决策」表
	var hitbox: Area3D = player.get("melee_hitbox")
	_check(hitbox != null, "melee_hitbox reference valid")
	_check(bool(hitbox.monitoring) == false, "hitbox monitoring initial false")

	# 记录挥砍前状态
	var tween_before = player.get("melee_swing_tween")

	# 触发挥砍（第一次）——应创建新 Tween 并设置冷却
	player.action_melee()
	var tween_after_first = player.get("melee_swing_tween")
	var cd_after_first = float(player.get("melee_cooldown_remaining"))
	_check(tween_after_first != null and tween_after_first.is_valid(),
		"first action_melee created valid tween (cooldown gate)")
	_check(tween_after_first != tween_before,
		"first action_melee created NEW tween (different from before)")
	_check(abs(cd_after_first - 0.7) < 0.001,
		"cooldown_remaining set to 0.7 after first call (got %f)" % cd_after_first)

	# 冷却门禁：t=0 立即再调一次应为 no-op（tween 引用不变、cd 不重置）
	player.action_melee()
	var tween_after_second_call = player.get("melee_swing_tween")
	var cd_after_second_call = float(player.get("melee_cooldown_remaining"))
	_check(tween_after_second_call == tween_after_first,
		"second action_melee at t=0 was no-op (tween unchanged, cooldown gate)")
	_check(abs(cd_after_second_call - 0.7) < 0.001,
		"cooldown_remaining NOT reset by blocked second call (still 0.7, got %f)" % cd_after_second_call)

	# hitbox monitoring 时序：t=0 / 0.1 / 0.25 / 0.45 / 0.7 → false / false / true / false / false
	_check(bool(hitbox.monitoring) == false, "hitbox monitoring at t=0 == false (got %s)" % str(hitbox.monitoring))

	await get_tree().create_timer(0.1).timeout
	_check(bool(hitbox.monitoring) == false, "hitbox monitoring at t=0.1 == false (got %s)" % str(hitbox.monitoring))

	await get_tree().create_timer(0.15).timeout  # 累计 0.25s
	_check(bool(hitbox.monitoring) == true, "hitbox monitoring at t=0.25 == true (active window) (got %s)" % str(hitbox.monitoring))

	await get_tree().create_timer(0.2).timeout  # 累计 0.45s
	_check(bool(hitbox.monitoring) == false, "hitbox monitoring at t=0.45 == false (active ended) (got %s)" % str(hitbox.monitoring))

	await get_tree().create_timer(0.25).timeout  # 累计 0.7s
	_check(bool(hitbox.monitoring) == false, "hitbox monitoring at t=0.7 == false (got %s)" % str(hitbox.monitoring))

	# === 冷却解锁断言（issue.md「测试决策」表）===
	# t=0.7：cooldown 应已归零，再次调用应创建新 Tween 并重置 cd 到 0.7
	var cd_at_0_7 := float(player.get("melee_cooldown_remaining"))
	_check(cd_at_0_7 < 0.05,
		"cooldown_remaining depleted at t=0.7 (got %f)" % cd_at_0_7)
	var old_tween = player.get("melee_swing_tween")
	player.action_melee()
	var new_tween = player.get("melee_swing_tween")
	var cd_after_unlock := float(player.get("melee_cooldown_remaining"))
	_check(new_tween != null and new_tween.is_valid(),
		"action_melee after cooldown expiry created valid tween")
	_check(new_tween != old_tween,
		"action_melee after cooldown expiry created NEW tween (different from previous)")
	_check(abs(cd_after_unlock - 0.7) < 0.001,
		"cooldown_remaining reset to 0.7 after unlock call (got %f)" % cd_after_unlock)
	# 等待第二次挥砍结束，避免 Tween 残留影响后续循环
	await get_tree().create_timer(0.7).timeout

	# === 循环 3：过渡动画发生 + 枪/剑复位 ===
	# 来源：issue.md「测试决策」+ 防伪绿：旧代码无过渡，t=0.7 也会复位，故加"过渡发生"行为断言
	var player3: CharacterBody3D = player_scene.instantiate()
	add_child(player3)
	# 冻结物理：阻止重力下落导致 velocity 干扰 container lerp（测试隔离）
	player3.set_physics_process(false)
	await get_tree().process_frame  # 让 _ready 的 instantiate 完成

	var container3: Node3D = player3.get("container")
	var sword3: Node3D = player3.get("melee_viewmodel_instance")
	_check(container3 != null, "player3 container reference valid")
	_check(sword3 != null, "player3 melee_viewmodel_instance reference valid")

	# 等 lerp 收敛到 container_offset（避免 init 基准偏移）
	await get_tree().create_timer(0.5).timeout

	# 缓存挥砍前初始变换（防漂移基准）
	var sword_init_pos: Vector3 = sword3.position
	var sword_init_rot: Vector3 = sword3.rotation_degrees
	var gun_init_y: float = container3.position.y

	# 触发挥砍
	player3.action_melee()

	# 过渡发生断言（行为证据，非精确数值）：
	# t=0.3（活跃帧中段）：枪应已下沉（y < gun_init_y - 0.5），剑应可见
	await get_tree().create_timer(0.3).timeout
	_check(float(container3.position.y) < gun_init_y - 0.5,
		"gun Container y dropped at t=0.3 (got %f, init %f) — transition happened" % [float(container3.position.y), gun_init_y])
	_check(bool(sword3.visible) == true,
		"sword visible at t=0.3 (got %s)" % str(sword3.visible))

	# 推进到 t=0.7（挥砍结束）
	await get_tree().create_timer(0.4).timeout  # 累计 0.7s

	# 复位断言（规格测试决策表）
	# 注：容差 0.05 而非 0.001——_melee_active=false 后 _process 的 container lerp
	# 会把 y 从 gun_start_pos 拉向 container_offset，0.1s 内偏移约 0.01，属正常 lerp 行为
	_check(abs(float(container3.position.y) - gun_init_y) < 0.05,
		"gun Container y restored at t=0.7 (got %f, init %f)" % [float(container3.position.y), gun_init_y])
	_check(bool(sword3.visible) == false,
		"sword hidden at t=0.7 (got %s)" % str(sword3.visible))
	_check(sword3.position.is_equal_approx(sword_init_pos),
		"sword position restored at t=0.7 (got %s, init %s)" % [str(sword3.position), str(sword_init_pos)])
	_check(sword3.rotation_degrees.is_equal_approx(sword_init_rot),
		"sword rotation restored at t=0.7 (got %s, init %s)" % [str(sword3.rotation_degrees), str(sword_init_rot)])

	# === 循环 4：连续挥砍无残留 ===
	# 来源：issue.md「连续挥砍处理」+「防漂移设计动机」
	# 场景：t=0 触发挥砍 → t=0.2（前摇结束，枪已下沉、剑在 windup 终点）再次触发
	#       旧 Tween 被 kill，入口强制重置枪/剑到初始值，新 Tween 从初始状态开始
	# 验证：t=0.9（第二次挥砍结束）枪/剑全部复位
	var player4: CharacterBody3D = player_scene.instantiate()
	add_child(player4)
	player4.set_physics_process(false)
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout  # 等 lerp 收敛

	var container4: Node3D = player4.get("container")
	var sword4: Node3D = player4.get("melee_viewmodel_instance")
	var sword4_init_pos: Vector3 = sword4.position
	var sword4_init_rot: Vector3 = sword4.rotation_degrees
	var gun4_init_y: float = container4.position.y

	# 第一次挥砍
	player4.action_melee()

	# t=0.2：前摇刚结束，枪已下沉、剑在 windup 终点——此时再次触发（kill 旧 Tween）
	await get_tree().create_timer(0.2).timeout
	# 断言此时确实在过渡中途（枪已下沉，证明旧 Tween 跑过）
	_check(float(container4.position.y) < gun4_init_y - 0.5,
		"cycle4: gun dropped at t=0.2 before 2nd swing (got %f, init %f)" % [float(container4.position.y), gun4_init_y])

	# 手动清零 cooldown 以触发第二次挥砍（绕过冷却门禁测残留处理）
	player4.set("melee_cooldown_remaining", 0.0)
	player4.action_melee()

	# 推进到第二次挥砍结束（t=0.2 + 0.7 = 0.9，但 cooldown 是 0.7s 含 0.6s 挥砍）
	await get_tree().create_timer(0.7).timeout

	# 验证第二次挥砍结束后全部复位（无残留）
	_check(abs(float(container4.position.y) - gun4_init_y) < 0.05,
		"cycle4: gun y restored after 2nd swing (got %f, init %f)" % [float(container4.position.y), gun4_init_y])
	_check(bool(sword4.visible) == false,
		"cycle4: sword hidden after 2nd swing (got %s)" % str(sword4.visible))
	_check(sword4.position.is_equal_approx(sword4_init_pos),
		"cycle4: sword position restored after 2nd swing (got %s, init %s)" % [str(sword4.position), str(sword4_init_pos)])
	_check(sword4.rotation_degrees.is_equal_approx(sword4_init_rot),
		"cycle4: sword rotation restored after 2nd swing (got %s, init %s)" % [str(sword4.rotation_degrees), str(sword4_init_rot)])

	if failures == 0:
		print("[TEST] PASS — melee-transitions cycle 4 (consecutive swing no residue)")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
