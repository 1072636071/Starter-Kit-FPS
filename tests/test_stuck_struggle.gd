## 竞技场 Issue 05 测试：卡住状态机（Stuck & Struggle）
## 运行：godot --headless --path . res://tests/test_stuck_struggle.tscn --quit-after 600
extends Node3D

var failures: int = 0
var _player: CharacterBody3D

func _ready():
	call_deferred("_run_tests")

func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1

func _run_tests() -> void:
	_player = $Player

	# 等待玩家缓降完成（_dropping = false）
	_wait_for_drop()

	# === 1. 初始状态为 NORMAL ===
	_check(_player.stuck_state == 0, "initial stuck_state == NORMAL (got %d)" % _player.stuck_state)

	# === 2. 状态变迁：NORMAL → STUCK ===
	_player._set_stuck_state(1)  # StuckState.STUCK = 1
	_check(_player.stuck_state == 1, "_set_stuck_state(STUCK) → stuck_state == 1 (got %d)" % _player.stuck_state)

	# === 3. STUCK 状态下 _start_escape → ESCAPING ===
	_player._last_move_dir = Vector3.FORWARD  # 模拟进入方向
	_player._start_escape()
	_check(_player.stuck_state == 2, "_start_escape() → stuck_state == ESCAPING (got %d)" % _player.stuck_state)
	_check(_player._escape_distance == 0.0, "_escape_distance reset to 0 on ESCAPING entry")

	# === 4. ESCAPING 期间位置变化（推回方向 = -FORWARD = BACK）===
	var pos_before := _player.global_position.z
	# 手动执行几帧推回
	for i in range(10):
		_player._physics_process(1.0 / 60.0)
	var pos_after := _player.global_position.z
	_check(pos_after > pos_before, "ESCAPING pushes player in +z (back): before=%.3f after=%.3f" % [pos_before, pos_after])

	# === 5. 推出后回到 NORMAL（test_move 无碰撞或距离超限）===
	# 由于测试场景中缝隙很窄，推出几帧后应该脱离
	# 强制多跑几帧确保脱离
	for i in range(600):
		if _player.stuck_state == 0:
			break
		_player._physics_process(1.0 / 60.0)
	_check(_player.stuck_state == 0, "after escape push, stuck_state returns to NORMAL (got %d)" % _player.stuck_state)

	# === 6. 正常状态不触发 STUCK（无夹缝时）===
	# 把玩家移到空旷位置
	_player.global_position = Vector3(5, 1, 5)
	_player._stuck_timer = 0.0
	_player._set_stuck_state(0)  # 确保 NORMAL
	# 模拟几帧 _detect_stuck（无输入时不应触发）
	for i in range(60):
		_player._detect_stuck(1.0 / 60.0)
	_check(_player.stuck_state == 0, "no input → no stuck trigger (got %d)" % _player.stuck_state)

	# === 7. 缓降中不触发 STUCK ===
	_player._dropping = true
	_player._stuck_timer = 0.0
	for i in range(60):
		_player._detect_stuck(1.0 / 60.0)
	_check(_player.stuck_state == 0, "_dropping=true → no stuck trigger (got %d)" % _player.stuck_state)
	_player._dropping = false

	# === 8. 死亡优先：STUCK 状态下 damage 致死 → 回到 NORMAL ===
	_player._set_stuck_state(1)  # STUCK
	_check(_player.stuck_state == 1, "pre-condition: stuck_state == STUCK")
	_player.health = 1
	_player.shield = 0.0
	_player.damage(10.0)  # 致死伤害
	_check(_player._dead == true, "damage(10) with health=1 → _dead == true")
	_check(_player.stuck_state == 0, "death resets stuck_state to NORMAL (got %d)" % _player.stuck_state)

	# === 9. stuck_state_changed 信号发射 ===
	# 重置玩家（新实例太重，直接验证信号是否可连接）
	var signal_received := [false]
	var lambda = func(_s): signal_received[0] = true
	_player.stuck_state_changed.connect(lambda)
	_player._dead = false
	_player._set_stuck_state(1)
	_check(signal_received[0], "stuck_state_changed signal emitted on state change")
	_player.stuck_state_changed.disconnect(lambda)

	# === 结果 ===
	print("")
	if failures == 0:
		print("[TEST] ALL PASSED")
	else:
		print("[TEST] %d FAILURES" % failures)
	get_tree().quit(failures)

func _wait_for_drop() -> void:
	# 等待缓降完成（最多 5 秒）
	var elapsed := 0.0
	while _player._dropping and elapsed < 5.0:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	# 额外等几帧让物理稳定
	for i in range(10):
		await get_tree().physics_frame
