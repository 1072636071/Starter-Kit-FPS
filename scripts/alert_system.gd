extends Node
## 连锁 Aggro 警觉传播系统（autoload）
## 参见 .scratch/arena-fixes/issues/07-chain-aggro.md
##
## 缓存 alert 事件（world_pos, radius, expire_time），存活 alert_lifetime 秒后自动丢弃。
## 怪物在 IDLE 态下调用 has_alert_nearby() 判断是否被惊动。

## alert 缓存存活时间（秒）
const ALERT_LIFETIME := 0.5

# 内部 alert 条目：{position: Vector3, radius: float, expire_at: float}
var _alerts: Array = []

## 发出一个 alert 事件。半径仅用于查询时判断是否在范围内（不影响其他 alert）。
func emit_alert(world_pos: Vector3, radius: float) -> void:
	_alerts.append({
		"position": world_pos,
		"radius": radius,
		"expire_at": Time.get_ticks_msec() / 1000.0 + ALERT_LIFETIME,
	})

## 查询 world_pos 的 check_radius 范围内是否有存活的 alert。
## 判定条件：alert.position 到 world_pos 的水平距离 ≤ alert.radius 且 ≤ check_radius
## （alert 半径 = 声音传播半径，check_radius = 怪物感知半径，两者都满足才感知到）
func has_alert_nearby(world_pos: Vector3, check_radius: float) -> bool:
	_purge_expired()
	var now := Time.get_ticks_msec() / 1000.0
	for a in _alerts:
		if a["expire_at"] <= now:
			continue
		var pos: Vector3 = a["position"]
		var dx: float = pos.x - world_pos.x
		var dz: float = pos.z - world_pos.z
		var dist := Vector2(dx, dz).length()
		var alert_radius: float = a["radius"]
		if dist <= alert_radius and dist <= check_radius:
			return true
	return false

## 清空所有 alert（测试用）
func clear() -> void:
	_alerts.clear()

func _purge_expired() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var i := _alerts.size() - 1
	while i >= 0:
		if _alerts[i]["expire_at"] <= now:
			_alerts.remove_at(i)
		i -= 1
