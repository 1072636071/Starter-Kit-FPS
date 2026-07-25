extends Node
## Issue 12：PlaceTrap 模块基类测试
## 验证：倒计时放陷阱、max_traps 上限、on_death 清理

var failures: int = 0


func _ready() -> void:
	call_deferred("_run_tests")


func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1


func _run_tests() -> void:
	# 创建一个假的 enemy（monster_base），挂 Poison 模块
	var enemy := _make_fake_enemy()
	add_child(enemy)

	var mod := load("res://scripts/modules/module_place_trap_poison.gd").new()
	mod.name = "PlaceTrapPoison"
	enemy.add_child(mod)

	# 需要手动调用 module_setup（因为 _collect_modules 只在 _ready 运行一次）
	mod.module_setup(enemy)

	# 检查初始状态
	_check(mod._cooldown_remaining == 0.0, "initial cooldown remaining = 0")
	_check(mod._active_traps.size() == 0, "initial active traps = 0")

	# 模拟 16s 推进（3 个 5s 冷却 + 1s buffer）
	# 每次 tick 1s 以简化
	for i in range(16):
		mod.on_tick(1.0)

	# 清理无效引用后计数
	mod._cleanup_traps()
	var trap_count := mod._active_traps.size()
	_check(trap_count == 3, "max_traps=3 limit: spawned exactly 3 (got %d)" % trap_count)

	# 验证第 4 个冷却周期没有产生额外陷阱
	_check(trap_count == 3, "no 4th trap (max_traps enforced)")

	# 调用 on_death → 断言所有陷阱 queue_free()
	var freed_count := 0
	for t in mod._active_traps:
		if is_instance_valid(t):
			t.tree_exiting.connect(func(): freed_count += 1)
	mod.on_death()

	# on_death 后 _active_traps 应已清空
	_check(mod._active_traps.size() == 0, "active traps cleared after on_death (got %d)" % mod._active_traps.size())

	# 清理
	enemy.queue_free()
	await get_tree().process_frame

	if failures == 0:
		print("[TEST] PASS — module_place_trap")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)


func _make_fake_enemy() -> Node3D:
	var enemy := CharacterBody3D.new()
	enemy.name = "FakeEnemy_PlaceTrap"
	enemy.add_to_group("enemy")
	return enemy
