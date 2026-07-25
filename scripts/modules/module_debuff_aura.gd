extends Node
## DebuffAura 模块：on_tick 检测 aura_radius 内玩家 → 减速×0.7 + 攻速×0.8
## 玩家离开范围时恢复；用 _active bool 防止每帧重复乘。

@export var aura_radius: float = 5.0
@export var debuff_speed_mult: float = 0.7
@export var debuff_damage_mult: float = 0.8

var _enemy: Node3D
var _active: bool = false
var _original_speed_bonus: float = 0.0
var _original_damage_multiplier: float = 1.0


func module_setup(enemy: Node3D) -> void:
	_enemy = enemy


func on_tick(_delta: float) -> void:
	if not _enemy:
		return

	var player: Node3D = _enemy.get("player")
	if not player:
		return

	var dist: float = _enemy.global_position.distance_to(player.global_position)
	var in_range: bool = dist <= aura_radius

	if in_range and not _active:
		_apply_debuff(player)
	elif not in_range and _active:
		_remove_debuff(player)


func _apply_debuff(player: Node3D) -> void:
	_active = true
	_original_speed_bonus = float(player.get("move_speed_bonus"))
	_original_damage_multiplier = float(player.get("damage_multiplier"))
	# 减速：调整 move_speed_bonus 使有效移速变为原有效移速 × debuff_speed_mult
	# 有效移速 = movement_speed + move_speed_bonus
	var base_speed: float = float(player.get("movement_speed"))
	var effective_original: float = base_speed + _original_speed_bonus
	var target_speed: float = effective_original * debuff_speed_mult
	player.set("move_speed_bonus", target_speed - base_speed)
	# 攻速 debuff
	player.set("damage_multiplier", _original_damage_multiplier * debuff_damage_mult)


func _remove_debuff(player: Node3D) -> void:
	_active = false
	player.set("move_speed_bonus", _original_speed_bonus)
	player.set("damage_multiplier", _original_damage_multiplier)


func on_death() -> void:
	if _active and _enemy:
		var player: Node3D = _enemy.get("player")
		if player:
			_remove_debuff(player)
