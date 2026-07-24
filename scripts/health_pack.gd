extends Area3D
## issue 03：血包实体
## 拾取：玩家（"player" 组）body_entered → player.heal(heal_amount) 后自身销毁
## 过期：despawn_time 秒后自动 queue_free，最后 blink_warn 秒闪烁提示
## 暂停：默认 PROCESS_MODE_PAUSABLE，暂停期间计时冻结、不拾取（_process 不跑）
## 视觉：红色发光球体（SphereMesh + emission），layers = 1（进主相机；无 mesh 进小地图）

@export var heal_amount: int = 25
## 生成后存活时间（秒）
@export var despawn_time: float = 15.0
## 最后多少秒开始闪烁警告
@export var blink_warn: float = 3.0

var _elapsed: float = 0.0
var _blink_tween: Tween
@onready var _mesh: MeshInstance3D = $MeshInstance3D

func _ready():
	# 加入 health_pack 组，供 RunDirector 做同位置不堆叠检查
	add_to_group("health_pack")
	# 监听 body 进入
	body_entered.connect(_on_body_entered)

func _process(delta):
	_elapsed += delta
	if _elapsed >= despawn_time:
		queue_free()
		return
	# 进入闪烁窗口：启动一次性 Tween 循环闪烁（modulate 不可用于 MeshInstance3D，改用 visibility 周期切换）
	if _elapsed >= despawn_time - blink_warn and _blink_tween == null:
		_start_blink()

func _start_blink() -> void:
	if _mesh == null:
		return
	_blink_tween = create_tween()
	_blink_tween.set_loops()  # 持续到 queue_free
	_blink_tween.tween_property(_mesh, "visible", false, 0.12)
	_blink_tween.tween_property(_mesh, "visible", true, 0.12)

func _on_body_entered(body: Node3D) -> void:
	if not is_instance_valid(body):
		return
	if not body.is_in_group("player"):
		return
	if not body.has_method("heal"):
		return
	body.heal(heal_amount)
	queue_free()
