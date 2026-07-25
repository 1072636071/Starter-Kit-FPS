extends Area3D
## 陷阱场景基类：body_entered 检测 "player" 组 → 调用 activate(player)
## 子类覆盖 activate() 实现具体效果（毒/DOT、AOE 爆炸等）

@export var visible_on_ready: bool = false


func _ready() -> void:
	visible = visible_on_ready
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		activate(body)


## 子类覆盖：陷阱触发时对玩家执行的逻辑
func activate(player: Node3D) -> void:
	push_warning("trap_base: activate() not overridden by subclass")
	queue_free()
