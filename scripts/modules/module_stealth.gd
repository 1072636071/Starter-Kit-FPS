extends EnemyModule
## Stealth 模块：进入 ATTACK 状态时隐身 stealth_duration 秒
## 挂为任意 monster_base 子节点的子节点即可工作。

@export var stealth_duration: float = 0.5
@export var stealth_alpha: float = 0.4

var _enemy: Node3D
var _mesh_nodes: Array[MeshInstance3D] = []


func module_setup(enemy: Node3D) -> void:
	_enemy = enemy
	_mesh_nodes.clear()
	for child in enemy.find_children("*", "MeshInstance3D", true, false):
		_mesh_nodes.append(child)


func on_enter_state(state: int) -> void:
	# AIState.ATTACK = 2（monster_base.gd 中 AIState enum）
	if state != 2:
		return

	for mesh in _mesh_nodes:
		if is_instance_valid(mesh):
			mesh.transparency = stealth_alpha

	_enemy.get_tree().create_timer(stealth_duration).timeout.connect(_restore_transparency)


func _restore_transparency() -> void:
	for mesh in _mesh_nodes:
		if is_instance_valid(mesh):
			mesh.transparency = 0.0
