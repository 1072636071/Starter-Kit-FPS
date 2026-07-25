extends Node
## PlaceTrap 模块基类：on_tick 倒计时 → 放陷阱，on_death 清陷阱
## 子类覆盖 trap_scene / place_cooldown / max_traps 等参数实现变体

@export var trap_scene: PackedScene
@export var place_cooldown: float = 5.0
@export var max_traps: int = 3

var _enemy: Node3D
var _cooldown_remaining: float = 0.0
var _active_traps: Array[Node] = []


func module_setup(enemy: Node3D) -> void:
	_enemy = enemy
	_cooldown_remaining = 0.0


func on_tick(delta: float) -> void:
	if not _enemy:
		return

	_cooldown_remaining -= delta
	if _cooldown_remaining <= 0.0:
		# 清理已释放的陷阱引用
		_cleanup_traps()
		if _active_traps.size() < max_traps:
			_place_trap()
		_cooldown_remaining = place_cooldown


func _place_trap() -> void:
	if not trap_scene or not _enemy:
		return

	var trap: Node = trap_scene.instantiate()
	_enemy.get_tree().root.add_child(trap)
	if trap is Node3D:
		trap.global_position = _enemy.global_position
	_active_traps.append(trap)


func _cleanup_traps() -> void:
	var valid: Array[Node] = []
	for t in _active_traps:
		if is_instance_valid(t):
			valid.append(t)
	_active_traps = valid


func on_death() -> void:
	for t in _active_traps:
		if is_instance_valid(t):
			t.queue_free()
	_active_traps.clear()
