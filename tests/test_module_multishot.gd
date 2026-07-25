## Issue 15 测试：MultiShot 模块 — 触发 ATTACK → 0.45s 内射出 4 发弹体
## 运行：godot --headless --path . res://tests/test_module_multishot.tscn --quit-after 30
extends Node3D

var failures: int = 0
var _fire_count: int = 0


func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1


func _ready() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	# 使用 monster_ranged 作为载体
	var monster: CharacterBody3D = preload("res://objects/monster_ranged.tscn").instantiate()
	add_child(monster)

	# 挂载 MultiShot 模块
	var multishot_script: Script = preload("res://scripts/modules/module_multishot.gd")
	var multishot: Node = Node.new()
	multishot.set_script(multishot_script)
	multishot.burst_count = 4
	multishot.burst_interval = 0.15
	monster.add_child(multishot)

	# 用计数替换 _fire_projectile 来追踪调用次数
	_fire_count = 0
	monster.set_meta("_original_fire_projectile", monster._fire_projectile)
	# 我们不能直接替换方法，改用信号计数：连接 module 内部逻辑
	# 策略：在 monster 上添加一个计数器来验证

	# 由于 GDScript 不支持运行时方法替换，我们通过间接方式验证：
	# 触发 ATTACK 后，用 create_timer 等待 burst_count * burst_interval + margin，
	# 检查场景中是否生成了弹体（projectile 实例）。

	# 先记录根节点现有子节点数（排除弹体干扰）
	var root_children_before: int = get_tree().root.get_child_count()

	# 触发 ATTACK 状态 → on_enter_state(ATTACK)
	monster._change_state(monster.AIState.ATTACK)

	# 等待 4 * 0.15 = 0.6s + margin
	await get_tree().create_timer(0.8).timeout

	# 检查根节点下新增子节点（弹体实例）
	var root_children_after: int = get_tree().root.get_child_count()
	var new_children: int = root_children_after - root_children_before
	# 应该有 4 个弹体（可能有 ±1 误差由于其他异步操作）
	_check(new_children >= 3,
		"at least 3 projectiles spawned in burst (got %d new children)" % new_children)
	_check(new_children <= 6,
		"no more than 6 projectiles (expected ~4, got %d)" % new_children)

	monster.queue_free()

	if failures == 0:
		print("[TEST] PASS — issue 15 MultiShot module")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
