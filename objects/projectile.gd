extends Area3D

var speed: float = 40.0
var direction: Vector3 = Vector3.FORWARD
var damage: float = 25.0
var color: Color = Color(1, 0.6, 0.1)
var max_distance: float = 20.0
var distance_traveled: float = 0.0
var shooter: Node3D = null # Ignore collision with shooter

var _prev_position: Vector3
var _has_hit: bool = false # Prevent double-hit in same frame

@onready var mesh: MeshInstance3D = $Mesh

func _ready():
	# Make material unique per instance and apply color
	var mat = mesh.get_surface_override_material(0).duplicate()
	mat.emission = color
	mesh.set_surface_override_material(0, mat)
	
	# Orient capsule along flight direction
	if direction != Vector3.ZERO and abs(direction.dot(Vector3.UP)) < 0.99:
		look_at(global_position + direction, Vector3.UP)
		rotate_x(deg_to_rad(90))
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _process(delta):
	var move_distance = speed * delta
	_prev_position = global_position
	global_position += direction * move_distance
	distance_traveled += move_distance
	
	if distance_traveled >= max_distance:
		queue_free()
		return
	
	# Raycast from previous to current position to prevent tunneling
	_raycast_check()

func _on_body_entered(body):
	_hit(body, global_position)

func _on_area_entered(area):
	_hit(area, global_position)

func _raycast_check():
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(_prev_position, global_position)
	query.collision_mask = collision_mask
	if shooter:
		query.exclude = [shooter.get_rid()]
	var result = space_state.intersect_ray(query)
	if result:
		var collider = result["collider"]
		if collider == shooter:
			return
		_hit(collider, result["position"])

func _hit(target, impact_position: Vector3):
	# Ignore collision with shooter
	if target == shooter:
		return
	
	# Prevent double-hit (raycast + body_entered in same frame)
	if _has_hit:
		return
	_has_hit = true
	
	# Deal damage if the target has a damage method
	if target.has_method("damage"):
		target.damage(damage)
	
	# Spawn impact effect at hit position
	var impact = preload("res://objects/impact.tscn")
	var impact_instance = impact.instantiate()
	get_tree().root.add_child(impact_instance)
	impact_instance.global_position = impact_position
	impact_instance.play("shot")
	
	# Destroy self
	queue_free()
