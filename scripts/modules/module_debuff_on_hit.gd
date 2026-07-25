extends Node
## DebuffOnHit 模块：module_setup 时连接 enemy.projectile_hit_player 信号，
## 弹体命中玩家后：玩家 damage_multiplier *= debuff_mult，持续 debuff_duration 秒后恢复。

@export var debuff_mult: float = 0.7
@export var debuff_duration: float = 2.0

var _enemy: Node3D
var _debuff_active: bool = false
var _original_damage_multiplier: float = 1.0
var _debuff_player: Node3D = null


func module_setup(enemy: Node3D) -> void:
	_enemy = enemy
	if _enemy.has_signal("projectile_hit_player"):
		if not _enemy.projectile_hit_player.is_connected(_on_projectile_hit_player):
			_enemy.projectile_hit_player.connect(_on_projectile_hit_player)


func _on_projectile_hit_player(player: Node3D) -> void:
	if not player:
		return

	# 记录原始值（如果尚未在 debuff 中）
	if not _debuff_active:
		_original_damage_multiplier = float(player.get("damage_multiplier"))
		_debuff_active = true
		_debuff_player = player
		player.set("damage_multiplier", _original_damage_multiplier * debuff_mult)
		_enemy.get_tree().create_timer(debuff_duration).timeout.connect(_restore_debuff)
	else:
		# 已在 debuff 中，刷新计时器（重置 duration）
		player.set("damage_multiplier", _original_damage_multiplier * debuff_mult)
		_enemy.get_tree().create_timer(debuff_duration).timeout.connect(_restore_debuff)


func _restore_debuff() -> void:
	if not _debuff_active:
		return
	if _debuff_player and is_instance_valid(_debuff_player):
		_debuff_player.set("damage_multiplier", _original_damage_multiplier)
	_debuff_active = false
	_debuff_player = null


func on_death() -> void:
	# 断开信号并恢复 debuff
	if _enemy and _enemy.has_signal("projectile_hit_player"):
		if _enemy.projectile_hit_player.is_connected(_on_projectile_hit_player):
			_enemy.projectile_hit_player.disconnect(_on_projectile_hit_player)
	if _debuff_active:
		_restore_debuff()
