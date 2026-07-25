extends "res://scripts/modules/module_place_trap_base.gd"
## PlaceTrap Damage 变体：放置伤害陷阱（AOE 立刻爆炸）


func _ready() -> void:
	trap_scene = preload("res://scenes/trap_damage.tscn")
	place_cooldown = 6.0
	max_traps = 3
