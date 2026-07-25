## 破片手雷测试（issue 23）
## 运行：godot --headless --path . res://tests/test_grenade_frag.tscn --quit-after 30
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
	var scene: PackedScene = load("res://scenes/grenade_projectile.tscn")
	_check(scene != null, "grenade_projectile.tscn loads")

	var grenade: RigidBody3D = scene.instantiate()
	add_child(grenade)

	# 破片参数验证
	_check(grenade.FRAG_DELAY == 0.8, "frag delay = 0.8s")
	_check(grenade.FRAG_RADIUS == 5.0, "frag radius = 5.0m")
	_check(grenade.FRAG_DAMAGE_CENTER == 40.0, "frag damage center = 40")
	_check(grenade.FRAG_DAMAGE_EDGE == 10.0, "frag damage edge = 10")

	# 线性衰减验证：距离 0 → ratio=1 → dmg≈40
	var dist_center := 0.0
	var ratio_center := clampf(1.0 - (dist_center / grenade.FRAG_RADIUS), 0.0, 1.0)
	var dmg_center := lerpf(grenade.FRAG_DAMAGE_EDGE, grenade.FRAG_DAMAGE_CENTER, ratio_center)
	_check(abs(dmg_center - 40.0) < 0.01, "center damage ≈ 40 (got %.1f)" % dmg_center)

	# 距离 3m → ratio≈0.4 → dmg≈22
	var dist_mid := 3.0
	var ratio_mid := clampf(1.0 - (dist_mid / grenade.FRAG_RADIUS), 0.0, 1.0)
	var dmg_mid := lerpf(grenade.FRAG_DAMAGE_EDGE, grenade.FRAG_DAMAGE_CENTER, ratio_mid)
	_check(abs(dmg_mid - 22.0) < 1.0, "mid distance damage ≈ 22 (got %.1f)" % dmg_mid)

	# 距离 5m（边缘）→ ratio≈0 → dmg≈10
	var dist_edge := 5.0
	var ratio_edge := clampf(1.0 - (dist_edge / grenade.FRAG_RADIUS), 0.0, 1.0)
	var dmg_edge := lerpf(grenade.FRAG_DAMAGE_EDGE, grenade.FRAG_DAMAGE_CENTER, ratio_edge)
	_check(abs(dmg_edge - 10.0) < 0.01, "edge damage ≈ 10 (got %.1f)" % dmg_edge)

	# 超出范围 → ratio=0 → dmg=10（但不会命中，因为物理检测只查半径内）
	var dist_far := 6.0
	var ratio_far := clampf(1.0 - (dist_far / grenade.FRAG_RADIUS), 0.0, 1.0)
	_check(ratio_far == 0.0, "beyond radius → ratio clamped to 0")

	grenade.queue_free()

	if failures == 0:
		print("[TEST] PASS — grenade frag")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
