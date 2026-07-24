extends Resource
class_name Weapon

@export_subgroup("Model")
@export var model: PackedScene # Model of the weapon
@export var position: Vector3 # On-screen position
@export var rotation: Vector3 # On-screen rotation
@export var muzzle_position: Vector3 # On-screen position of muzzle flash

@export_subgroup("Properties")
@export_range(0.1, 1) var cooldown: float = 0.1 # Firerate
@export_range(1, 1000) var max_distance: int = 1000 # Fire distance
@export_range(0, 100) var damage: float = 25 # Damage per hit
@export_range(0, 5) var spread: float = 0 # Spread of each shot
@export_range(1, 5) var shot_count: int = 1 # Amount of shots
@export_range(0, 50) var knockback: int = 20 # Amount of knockback

@export var min_knockback: Vector2 = Vector2(0.001, 0.001) # x for vertical knockback, y for horizontal knockback
@export var max_knockback: Vector2 = Vector2(0.0025, 0.002) # x for vertical knockback, y for horizontal knockback

@export_subgroup("Sounds")
@export var sound_shoot: String # Sound path

@export_subgroup("Crosshair")
@export var crosshair: Texture2D # Image of crosshair on-screen

@export_subgroup("Projectile")
@export var projectile_color: Color = Color(1.0, 0.6, 0.1) # Bullet glow color
@export var projectile_size: Vector3 = Vector3(1, 1, 1) # Bullet scale
@export_range(30, 50) var projectile_speed: float = 40.0 # Bullet flight speed (m/s)

@export_subgroup("Ammo")
@export var display_name: String = "Weapon" # 中文显示名
@export_range(1, 999) var magazine_size: int = 8 # 弹匣容量
@export_range(0, 9999) var max_reserve: int = 40 # 备弹上限
@export_range(0.1, 10) var reload_time: float = 1.5 # 换弹时间（秒）
