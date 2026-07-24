extends Node3D

const CombatUtils = preload("res://scripts/combat_utils.gd")

@export var player: Node3D
@export var enemy_spread: float = 0.08

@onready var muzzle_a = $MuzzleA
@onready var muzzle_b = $MuzzleB

var health := 100
var time := 0.0
var target_position: Vector3
var destroyed := false

# When ready, save the initial position

func _ready():
	target_position = position


func _process(delta):
	self.look_at(player.position + Vector3(0, 0.5, 0), Vector3.UP, true)  # Look at player
	target_position.y += (cos(time * 5) * 1) * delta  # Sine movement (up and down)

	time += delta

	position = target_position

# Take damage from player

func damage(amount):
	Audio.play("sounds/enemy_hurt.ogg")
	HitFeedback.flash(self)

	health -= amount

	if health <= 0 and !destroyed:
		destroy()

# Destroy the enemy when out of health

func destroy():
	Audio.play("sounds/enemy_destroy.ogg")

	destroyed = true
	queue_free()

# Shoot when timer hits 0

func _on_timer_timeout():
	# Play muzzle flash animation(s)
	
	muzzle_a.frame = 0
	muzzle_a.play("default")
	muzzle_a.rotation_degrees.z = randf_range(-45, 45)
	
	muzzle_b.frame = 0
	muzzle_b.play("default")
	muzzle_b.rotation_degrees.z = randf_range(-45, 45)
	
	Audio.play("sounds/enemy_attack.ogg")
	
	# Spawn projectile toward player
	var projectile = preload("res://objects/projectile.tscn")
	var projectile_instance = projectile.instantiate()
	
	var shoot_direction = (player.global_position + Vector3(0, 0.5, 0) - global_position).normalized()
	
	# Add spread with distance scaling
	shoot_direction = CombatUtils.apply_enemy_spread(shoot_direction, enemy_spread, global_position.distance_to(player.global_position))
	
	projectile_instance.direction = shoot_direction
	projectile_instance.speed = 30.0
	projectile_instance.damage = 5.0
	projectile_instance.max_distance = 30.0
	projectile_instance.color = Color(1, 0.2, 0.2) # Red enemy projectile
	projectile_instance.shooter = self
	
	get_tree().root.add_child(projectile_instance)
	projectile_instance.global_position = global_position
