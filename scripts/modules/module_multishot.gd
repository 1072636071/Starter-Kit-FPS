extends Node
## MultiShot 模块：on_enter_state(ATTACK) 时在 burst_interval 间隔内
## 连续调用 enemy._fire_projectile() 共 burst_count 次。
## 用 create_timer 链式调度；非 ATTACK 进入不触发。

@export var burst_count: int = 4
@export var burst_interval: float = 0.15

var _enemy: Node3D
var _firing: bool = false


func module_setup(enemy: Node3D) -> void:
	_enemy = enemy


func on_enter_state(state: int) -> void:
	# AIState.ATTACK = 2
	if state != 2:
		return
	if _firing:
		return
	if not _enemy or not _enemy.has_method("_fire_projectile"):
		return

	_firing = true
	_do_burst(0)


func _do_burst(idx: int) -> void:
	if not _enemy or not is_instance_valid(_enemy):
		_firing = false
		return
	if idx >= burst_count:
		_firing = false
		return

	_enemy._fire_projectile()

	if idx < burst_count - 1:
		_enemy.get_tree().create_timer(burst_interval).timeout.connect(
			_do_burst.bind(idx + 1)
		)
	else:
		_firing = false
