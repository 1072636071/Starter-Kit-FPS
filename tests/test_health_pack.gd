## 竞技场 Issue 03 测试：血包实体（拾取 / 过期 / 非玩家不拾取）
## 运行：godot --headless --path . res://tests/test_health_pack.tscn --quit-after 600
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
	var pack_scene := preload("res://scenes/health_pack.tscn")
	var player_scene := preload("res://objects/player.tscn")

	# 1. 导出字段
	var pack0: Area3D = pack_scene.instantiate()
	add_child(pack0)
	_check(int(pack0.get("heal_amount")) == 25, "heal_amount default 25 (got %d)" % int(pack0.get("heal_amount")))
	_check(float(pack0.get("despawn_time")) == 15.0, "despawn_time default 15 (got %f)" % float(pack0.get("despawn_time")))
	pack0.queue_free()
	await get_tree().process_frame

	# 2. 拾取：玩家 body_entered → heal +25，血包销毁
	var player: CharacterBody3D = player_scene.instantiate()
	player.add_to_group("player")
	add_child(player)
	# 把血降到 70（damage 80：shield 0 overflow 30 → health 70）
	player.damage(80.0)
	_check(int(player.get("health")) == 70, "player pre-pickup health 70 (got %d)" % int(player.get("health")))

	var pack: Area3D = pack_scene.instantiate()
	add_child(pack)
	# 把血包放到玩家位置以触发 body_entered
	pack.global_position = player.global_position
	# 等若干物理帧让 Area3D 检测重叠
	for i in 5:
		await get_tree().physics_frame
	_check(int(player.get("health")) == 95, "player healed +25 → 95 (got %d)" % int(player.get("health")))
	_check(not is_instance_valid(pack), "health pack freed after pickup")
	player.queue_free()
	await get_tree().process_frame

	# 3. 非玩家 body 不拾取
	var pack2: Area3D = pack_scene.instantiate()
	pack2.set("despawn_time", 100.0)  # 避免过期干扰
	add_child(pack2)
	var stranger := CharacterBody3D.new()
	add_child(stranger)
	pack2.global_position = Vector3.ZERO
	stranger.global_position = Vector3.ZERO
	for i in 5:
		await get_tree().physics_frame
	_check(is_instance_valid(pack2), "health pack NOT freed by non-player body")
	stranger.queue_free()
	pack2.queue_free()
	await get_tree().process_frame

	# 4. 过期：despawn_time 到点自动 queue_free
	var pack3: Area3D = pack_scene.instantiate()
	pack3.set("despawn_time", 0.15)
	add_child(pack3)
	# 等超过 despawn_time
	await get_tree().create_timer(0.4).timeout
	_check(not is_instance_valid(pack3), "health pack freed after despawn_time")

	if failures == 0:
		print("[TEST] PASS — arena issue 03 health pack entity")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
