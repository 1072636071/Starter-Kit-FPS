extends Node
## SelfDestruct 模块：玩家 < 3m 时 0.8s 前摇 → AOE 爆炸 60 → destroy()

@export var detonate_range: float = 3.0
@export var fuse_time: float = 0.8
@export var explosion_radius: float = 5.0
@export var explosion_damage: int = 60

var _enemy: Node3D
var _detonating: bool = false
var _already_exploded: bool = false


func module_setup(enemy: Node3D) -> void:
	_enemy = enemy
	_detonating = false
	_already_exploded = false


func on_tick(_delta: float) -> void:
	if _detonating or _already_exploded:
		return
	if not _enemy:
		return

	var player := _get_player()
	if not player:
		return

	var dist := _enemy.global_position.distance_to(player.global_position)
	if dist < detonate_range:
		_detonate_sequence()


func _get_player() -> Node3D:
	if _enemy.get("player") != null:
		return _enemy.get("player")
	return get_tree().get_first_node_in_group("player")


func _detonate_sequence() -> void:
	_detonating = true

	# 蜂鸣闪烁前摇：modulate 红白交替
	if _enemy is Node3D:
		_flash_red_white()

	# fuse_time 后爆炸
	_enemy.get_tree().create_timer(fuse_time).timeout.connect(_explode)


func _flash_red_white() -> void:
	if not is_instance_valid(_enemy):
		return

	var tween := _enemy.create_tween()
	tween.set_loops()
	tween.tween_property(_enemy, "modulate", Color.RED, 0.1)
	tween.tween_property(_enemy, "modulate", Color.WHITE, 0.1)


func _explode() -> void:
	if _already_exploded:
		return
	_already_exploded = true

	# 通知同宿主上的 ExplodeOnDeath 模块避免重复爆炸
	if is_instance_valid(_enemy):
		for child in _enemy.get_children():
			if child is Node and child != self and child.has_method(&"on_death") and child.get(&"_already_exploded") != null:
				child.set(&"_already_exploded", true)

	# AOE 爆炸
	_apply_aoe_damage()

	# 调用宿主 destroy() → on_death → ExplodeOnDeath.on_death() 检查 _already_exploded 跳过
	if is_instance_valid(_enemy) and _enemy.has_method("destroy"):
		_enemy.destroy()


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
