extends EnemyModule
## SummonPet 模块：进入 CHASE 状态时在宿主周围随机位置召唤 CubePet
## 死亡时清理所有存活的 pets。
## 挂为任意 monster_base 子节点的子节点即可工作。

@export var pet_scene: PackedScene
@export var pet_count: int = 3
@export var pet_cooldown: float = 8.0
@export var spawn_radius: float = 3.0

var _enemy: Node3D
var _active_pets: Array[Node3D] = []
var _cooldown_remaining: float = 0.0
var _last_spawn_time: float = -9999.0


func module_setup(enemy: Node3D) -> void:
	_enemy = enemy
	if pet_scene == null:
		# 默认加载 pet_cube.tscn
		pet_scene = load("res://objects/pet_cube.tscn")


func on_enter_state(state: int) -> void:
	# AIState.CHASE = 1（monster_base.gd 中 AIState enum）
	if state != 1:
		return

	if not _cooldown_ready():
		return

	_spawn_pets()


func on_death() -> void:
	for pet in _active_pets:
		if is_instance_valid(pet):
			pet.queue_free()
	_active_pets.clear()


func _cooldown_ready() -> bool:
	if _enemy == null:
		return false
	var elapsed := Time.get_ticks_msec() / 1000.0 - _last_spawn_time
	return elapsed >= pet_cooldown


func _spawn_pets() -> void:
	if pet_scene == null:
		return

	var root := _enemy.get_tree().root if _enemy.is_inside_tree() else null
	if root == null:
		return

	for i in range(pet_count):
		var pet: Node3D = pet_scene.instantiate()
		root.add_child(pet)

		# 随机偏移：宿主周围 2–3m 范围内
		var angle := randf() * TAU
		var radius := randf_range(2.0, spawn_radius)
		var offset := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		pet.global_position = _enemy.global_position + offset

		# 设置 pet 的目标玩家（与宿主相同）
		if pet.has_method("set_target"):
			var player: Node3D = _enemy.get("player")
			if player:
				pet.set_target(player)

		_active_pets.append(pet)

	_last_spawn_time = Time.get_ticks_msec() / 1000.0
