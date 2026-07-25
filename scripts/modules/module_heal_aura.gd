extends Node
## HealAura 模块：on_tick 遍历场景中所有 monster_base 实例（group "enemy"），
## 检测 aura_radius 内友方非满血敌人，每帧回复 heal_per_second * delta HP。
## 治疗量不超过各敌人的 max_health。

@export var aura_radius: float = 8.0
@export var heal_per_second: float = 3.0

var _enemy: Node3D
## key = instance_id (int), value = max_health 缓存 (float)
var _max_health_cache: Dictionary = {}


func module_setup(enemy: Node3D) -> void:
	_enemy = enemy


func on_tick(delta: float) -> void:
	if not _enemy or not _enemy.is_inside_tree():
		return

	var enemies: Array = get_tree().get_nodes_in_group("enemy")
	var my_pos: Vector3 = _enemy.global_position

	for other in enemies:
		if other == _enemy:
			continue
		if not is_instance_valid(other):
			continue
		if not other.has_method("damage"):
			continue
		var dist: float = my_pos.distance_to(other.global_position)
		if dist > aura_radius:
			continue

		var id: int = other.get_instance_id()
		var max_hp: float
		if _max_health_cache.has(id):
			max_hp = float(_max_health_cache[id])
		else:
			max_hp = float(other.get("health"))
			_max_health_cache[id] = max_hp

		var current_health: float = float(other.get("health"))
		if current_health < max_hp:
			var heal_amount: float = heal_per_second * delta
			var new_health: float = minf(current_health + heal_amount, max_hp)
			other.set("health", new_health)


func on_death() -> void:
	_max_health_cache.clear()
