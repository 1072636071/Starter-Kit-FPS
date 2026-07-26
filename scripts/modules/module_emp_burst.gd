extends Node
## EMPBurst 模块：每 12s 向周围 5m 释放 EMP 脉冲
## 清空玩家备弹槽中随机 3 格并短暂禁用武器 1.5s

var host: CharacterBody3D
var _timer: float = 0.0
const COOLDOWN := 12.0
const RADIUS := 5.0
const SLOTS_TO_EMPTY := 3
const DISABLE_DURATION := 1.5


func module_setup(h: CharacterBody3D) -> void:
	host = h


func on_tick(delta: float) -> void:
	if not host or host._dead:
		return
	var player: Node3D = host.player
	if not player:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	# 距离检测
	var dist := (player.global_position - host.global_position).length()
	if dist > RADIUS:
		return
	_timer = COOLDOWN
	# EMP 效果
	if player.has_method("emp_disable"):
		player.emp_disable(DISABLE_DURATION)
	if player.has_method("empty_random_ammo_slots"):
		player.empty_random_ammo_slots(SLOTS_TO_EMPTY)
