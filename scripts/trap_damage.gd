extends "res://scripts/trap_base.gd"
## 伤害陷阱：触发后立刻 AOE 爆炸，范围内玩家受到 explosion_damage 伤害

@export var explosion_radius: float = 2.5
@export var explosion_damage: int = 40


func activate(player: Node3D) -> void:
	_apply_aoe_explosion()
	queue_free()


func _apply_aoe_explosion() -> void:
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()

	var sphere := SphereShape3D.new()
	sphere.radius = explosion_radius
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collision_mask = 1  # 检测玩家层

	var results: Array = space_state.intersect_shape(query)
	var hit_players: Dictionary = {}  # 用 rid 去重

	for result in results:
		var collider: Node = result.get("collider")
		if collider and collider.is_in_group("player"):
			var rid := collider.get_rid()
			if not hit_players.has(rid):
				hit_players[rid] = collider

	for player_node in hit_players.values():
		if player_node.has_method("damage"):
			player_node.damage(explosion_damage)
