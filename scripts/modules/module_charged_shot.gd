extends Node
## ChargedShot 模块：on_enter_state(ATTACK) 时蓄力 charge_time 秒，
## 期间阻止移动（_desired_velocity = Vector3.ZERO），
## 蓄力完成后临时提升 attack_damage × charged_damage_mult → 发射一发 → 恢复。

@export var charge_time: float = 1.2
@export var charged_damage_mult: float = 3.0

var _enemy: Node3D
var _charging: bool = false
var _original_damage: float = 0.0


func module_setup(enemy: Node3D) -> void:
	_enemy = enemy


func on_enter_state(state: int) -> void:
	# AIState.ATTACK = 2
	if state != 2:
		return
	if _charging:
		return
	if not _enemy or not _enemy.has_method("_fire_projectile"):
		return

	_charging = true
	_original_damage = float(_enemy.get("attack_damage"))

	# 蓄力完成后发射
	_enemy.get_tree().create_timer(charge_time).timeout.connect(_fire_charged)


func on_tick(_delta: float) -> void:
	if _charging and _enemy and is_instance_valid(_enemy):
		_enemy.set("_desired_velocity", Vector3.ZERO)


func _fire_charged() -> void:
	if not _enemy or not is_instance_valid(_enemy):
		_charging = false
		return
	if not _charging:
		return

	# 临时提升伤害
	_enemy.set("attack_damage", _original_damage * charged_damage_mult)

	# 发射一发
	_enemy._fire_projectile()

	# 恢复原值
	_enemy.set("attack_damage", _original_damage)
	_charging = false


func on_death() -> void:
	# 死亡时如果正在蓄力，恢复原始伤害
	if _charging and _enemy and is_instance_valid(_enemy):
		_enemy.set("attack_damage", _original_damage)
	_charging = false
