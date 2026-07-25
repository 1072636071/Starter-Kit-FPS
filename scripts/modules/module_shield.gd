extends Node
## Shield 模块：shield_max=60，on_damage 先扣盾，盾破发 shield_broken 信号
##
## 与 monster_base.damage() 的协作：
##   damage(amount) → _run_module_hook("on_damage", [amount]) → health -= amount
## 因此 Shield 在 on_damage 中吸收盾能挡的部分后，
## 把 enemy.health 加回 absorbed 量，抵消基类后续的 health -= amount，
## 净效果 = 只扣溢出（盾没挡住的）部分。

signal shield_broken()

@export var shield_max: int = 60

var _enemy: Node3D
var shield_current: int = 0


func module_setup(enemy: Node3D) -> void:
	_enemy = enemy
	shield_current = shield_max
	shield_broken.connect(_on_shield_broken)


func on_damage(amount: float) -> void:
	if not _enemy:
		return

	if shield_current > 0:
		var absorbed := mini(shield_current, int(amount))
		shield_current -= absorbed

		# 补偿：基类 damage() 在 hook 之后会 health -= amount，
		# 我们把盾吸收的部分加回去，净效果只扣溢出量
		var current_health := float(_enemy.get("health"))
		_enemy.set("health", current_health + absorbed)

		if shield_current <= 0:
			shield_current = 0
			shield_broken.emit()


## 子类可覆盖此虚方法响应盾破事件
func _on_shield_broken() -> void:
	pass
