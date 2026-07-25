extends Node
## SpeedAura 模块：on_tick 遍历场景中所有 monster_base 实例（group "enemy"），
## 检测 aura_radius 内友方 → 移速×1.2；离开时恢复。
## 维护 _buffed_enemies: Dictionary（key=instance_id, value=原始 speed）避免叠加。

@export var aura_radius: float = 10.0
@export var speed_mult: float = 1.2

var _enemy: Node3D
## key = instance_id (int), value = 原始 move_speed (float)
var _buffed_enemies: Dictionary = {}


func module_setup(enemy: Node3D) -> void:
	_enemy = enemy


func on_tick(_delta: float) -> void:
	if not _enemy or not _enemy.is_inside_tree():
		return

	var enemies: Array = get_tree().get_nodes_in_group("enemy")
	var my_pos: Vector3 = _enemy.global_position

	# 当前帧在范围内的敌人 id 集合
	var in_range_ids: Array = []

	for other in enemies:
		if other == _enemy:
			continue
		if not is_instance_valid(other):
			continue
		if not other.has_method("damage"):
			continue
		var dist: float = my_pos.distance_to(other.global_position)
		if dist <= aura_radius:
			var id: int = other.get_instance_id()
			in_range_ids.append(id)
			if not _buffed_enemies.has(id):
				# 首次进入范围：记录原始 speed 并施加 buff
				var original_speed: float = float(other.get("move_speed"))
				_buffed_enemies[id] = original_speed
				other.set("move_speed", original_speed * speed_mult)

	# 离开范围的敌人恢复原速
	var to_remove: Array = []
	for id in _buffed_enemies.keys():
		if not in_range_ids.has(id):
			var enemy_obj: Object = instance_from_id(id)
			if is_instance_valid(enemy_obj):
				enemy_obj.set("move_speed", _buffed_enemies[id])
			to_remove.append(id)

	for id in to_remove:
		_buffed_enemies.erase(id)


func on_death() -> void:
	# 恢复所有被 buff 的敌人
	for id in _buffed_enemies.keys():
		var enemy_obj: Object = instance_from_id(id)
		if is_instance_valid(enemy_obj):
			enemy_obj.set("move_speed", _buffed_enemies[id])
	_buffed_enemies.clear()
