## Issue 10 测试：Stealth 模块
## 运行：godot --headless --path . res://tests/test_module_stealth.tscn --quit-after 600
extends Node3D

var failures: int = 0


func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1


func _ready():
	call_deferred("_run_tests")


func _run_tests() -> void:
	var monster_scene: PackedScene = load("res://objects/monster_melee.tscn")
	var monster: Node3D = monster_scene.instantiate()
	add_child(monster)

	# 等待一帧让 _ready 执行完毕
	await get_tree().process_frame

	var stealth := preload("res://scripts/modules/module_stealth.gd").new()
	stealth.stealth_duration = 0.5
	stealth.stealth_alpha = 0.4
	monster.add_child(stealth)
	# 手动调 module_setup（已通过 monster_base._collect_modules 自动调用，
	# 但我们是在 _ready 之后添加的，需手动调用）
	stealth.module_setup(monster)

	# 收集所有 mesh
	var meshes: Array[MeshInstance3D] = []
	for child in monster.find_children("*", "MeshInstance3D", true, false):
		meshes.append(child)

	# 触发 ATTACK 状态（AIState.ATTACK = 2）
	monster._change_state(2)  # AIState.ATTACK

	# 立即检查 transparency 是否设为 0.4
	await get_tree().process_frame
	for mesh in meshes:
		_check(mesh.transparency == 0.4,
			"mesh transparency == 0.4 after ATTACK (got %.2f)" % mesh.transparency)

	# 0.6s 后检查 transparency 恢复为 0
	await get_tree().create_timer(0.6).timeout
	for mesh in meshes:
		_check(mesh.transparency == 0.0,
			"mesh transparency restored to 0 after 0.6s (got %.2f)" % mesh.transparency)

	# 清理
	monster.queue_free()

	if failures == 0:
		print("[TEST] PASS — issue 10 module_stealth")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
