## EMP 手雷测试（issue 23）
## 运行：godot --headless --path . res://tests/test_grenade_emp.tscn --quit-after 30
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
	# 加载 grenade_projectile 场景并验证 EMP 参数
	var scene: PackedScene = load("res://scenes/grenade_projectile.tscn")
	_check(scene != null, "grenade_projectile.tscn loads")

	var grenade: RigidBody3D = scene.instantiate()
	add_child(grenade)

	# 验证脚本存在且有 grenade_type 属性
	_check(grenade.get_script() != null, "grenade_projectile has script attached")
	_check("grenade_type" in grenade, "grenade_projectile has grenade_type property")

	# EMP 常量验证
	_check(grenade.EMP_DELAY == 0.5, "EMP delay = 0.5s")
	_check(grenade.EMP_RADIUS == 6.0, "EMP radius = 6.0m")
	_check(grenade.EMP_DURATION == 3.0, "EMP duration = 3s")
	_check(grenade.EMP_SLOW_FACTOR == 0.3, "EMP slow factor = 0.3 (speed ×0.3)")

	# _get_monsters_in_radius 方法存在
	_check(grenade.has_method("_get_monsters_in_radius"), "has _get_monsters_in_radius method")
	_check(grenade.has_method("_apply_emp_effect"), "has _apply_emp_effect method")
	_check(grenade.has_method("_detonate_emp"), "has _detonate_emp method")

	# 碰撞检测连接
	_check(grenade.body_entered.is_connected(grenade._on_body_entered),
		"body_entered signal connected")

	grenade.queue_free()

	if failures == 0:
		print("[TEST] PASS — grenade EMP")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
