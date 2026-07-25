extends Node
## ExplodeOnDeath 模块：on_death 时 AOE 爆炸 40
## 与 SelfDestruct 共存时：SelfDestruct 先 destroy() → on_death() 被调用，
## 但 _already_exploded 标志避免重复爆炸

@export var explosion_radius: float = 4.0
@export var explosion_damage: int = 40

var _enemy: Node3D
## 供 SelfDestruct 模块设置，防止重复爆炸
var _already_exploded: bool = false


func module_setup(enemy: Node3D) -> void:
	_enemy = enemy
	_already_exploded = false


func on_death() -> void:
	if _already_exploded:
		return
	_already_exploded = true

	# 通知同宿主上的 SelfDestruct 模块避免重复爆炸
	if is_instance_valid(_enemy):
		for child in _enemy.get_children():
			if child is Node and child != self and child.has_method(&"on_tick") and child.get(&"_already_exploded") != null:
				child.set(&"_already_exploded", true)

	# AOE 爆炸
	_apply_aoe_damage()


func _apply_aoe_damage() -> void:
	if not is_instance_valid(_enemy):
		return

	var space_state := _enemy.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()

	var sphere := SphereShape3D.new()
	sphere.radius = explosion_radius
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, _enemy.global_position)
	query.collision_mask = 1

	var results: Array = space_state.intersect_shape(query)
	var hit_players: Dictionary = {}

	for result in results:
		var collider: Node = result.get("collider")
		if collider and collider.is_in_group("player"):
			var rid := collider.get_rid()
			if not hit_players.has(rid):
				hit_players[rid] = collider

	for player_node in hit_players.values():
		if player_node.has_method("damage"):
			player_node.damage(explosion_damage)
