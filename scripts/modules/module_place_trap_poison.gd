extends "res://scripts/modules/module_place_trap_base.gd"
## PlaceTrap Poison 变体：放置毒陷阱（DOT 持续伤害）


func _ready() -> void:
	trap_scene = preload("res://scenes/trap_poison.tscn")
	place_cooldown = 5.0
	max_traps = 3
