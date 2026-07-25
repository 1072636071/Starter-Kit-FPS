extends Node
## BerserkOnDamage 模块：on_damage 触发狂暴 3s（damage×1.5, speed×1.3），冷却 8s

@export var berserk_damage_mult: float = 1.5
@export var berserk_speed_mult: float = 1.3
@export var berserk_duration: float = 3.0
@export var berserk_cooldown: float = 8.0

var _enemy: Node3D
var _berserk_active: bool = false
var _on_cooldown: bool = false
var _original_damage_mult: float = 1.0
var _original_speed: float = 3.0


func module_setup(enemy: Node3D) -> void:
	_enemy = enemy
	# 缓存原始值（若 enemy 有这些属性）
	_original_speed = float(enemy.get("move_speed")) if enemy.get("move_speed") != null else 3.0
	_original_damage_mult = float(enemy.get("damage_multiplier")) if enemy.get("damage_multiplier") != null else 1.0


func on_damage(_amount: float) -> void:
	if _berserk_active or _on_cooldown:
		return
	if not _enemy:
		return

	_berserk_active = true
	_on_cooldown = true

	# 修改宿主属性
	_enemy.set("damage_multiplier", _original_damage_mult * berserk_damage_mult)
	_enemy.set("move_speed", _original_speed * berserk_speed_mult)

	# 狂暴持续时间结束后恢复
	_enemy.get_tree().create_timer(berserk_duration).timeout.connect(_end_berserk)

	# 冷却计时器
	_enemy.get_tree().create_timer(berserk_cooldown).timeout.connect(func(): _on_cooldown = false)


func _end_berserk() -> void:
	_berserk_active = false
	if is_instance_valid(_enemy):
		_enemy.set("damage_multiplier", _original_damage_mult)
		_enemy.set("move_speed", _original_speed)
