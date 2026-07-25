extends EnemyModule
## Dash 模块：进入 ATTACK 状态时向玩家方向瞬移 dash_distance 并造成伤害
## 挂为任意 monster_base 子节点的子节点即可工作。

@export var dash_distance: float = 5.0
@export var dash_duration: float = 0.15

var _enemy: Node3D


func module_setup(enemy: Node3D) -> void:
	_enemy = enemy


func on_enter_state(state: int) -> void:
	# AIState.ATTACK = 2（monster_base.gd 中 AIState enum）
	if state != 2:
		return

	var player: Node3D = _enemy.get("player")
	if not player:
		return

	var dir: Vector3 = player.global_position - _enemy.global_position
	dir.y = 0.0
	if dir.length_squared() < 0.001:
		return
	dir = dir.normalized()

	_enemy.global_position += dir * dash_distance

	# Dash 后立即调用 _deal_damage（复用 melee 距离判定）
	if _enemy.has_method("_deal_damage"):
		_enemy._deal_damage()
