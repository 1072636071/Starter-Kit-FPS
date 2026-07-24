extends Area3D
## issue 04（ADR 013 / 015）：物理子弹商店摊位
##
## 玩家走入触发区 → 暂停 + 打开 ShopUI；玩家走出 / UI 关闭（ESC/关闭按钮）→ 恢复。
## ShopStation 负责暂停/恢复与 ShopUI 生命周期协调；购买逻辑在 ShopUI。
##
## 互斥（ADR 015）：进入前检查 get_tree().paused，已暂停（升级/死亡）则忽略本次进入。
##
## 视觉：发光柱（BoxMesh + emission），layers = 1（主相机 + 小地图皆可见，作地标）。
## ShopUI 挂在 HUD（CanvasLayer）下；本节点通过 group "shop_ui" 查找。

@export var shop_ui_scene: PackedScene = preload("res://scenes/shop_ui.tscn")

var _shop_ui: Control
var _run_director: Node
var _active := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# 查找 ShopUI（生产环境：挂在 HUD 下、属 "shop_ui" 组）
	call_deferred("_bind_shop_ui")
	# 查找 RunDirector（"run_director" 组）
	call_deferred("_bind_run_director")

# 测试 / 外部注入入口
func set_shop_ui(ui: Control) -> void:
	_shop_ui = ui
	# 监听关闭信号以恢复暂停
	if _shop_ui and not _shop_ui.closed.is_connected(_on_shop_ui_closed):
		_shop_ui.closed.connect(_on_shop_ui_closed)

func set_run_director(rd: Node) -> void:
	_run_director = rd

func _bind_shop_ui() -> void:
	if _shop_ui != null and is_instance_valid(_shop_ui):
		return
	for n in get_tree().get_nodes_in_group("shop_ui"):
		if n is Control:
			_shop_ui = n
			if not _shop_ui.closed.is_connected(_on_shop_ui_closed):
				_shop_ui.closed.connect(_on_shop_ui_closed)
			break

func _bind_run_director() -> void:
	if _run_director != null and is_instance_valid(_run_director):
		return
	for n in get_tree().get_nodes_in_group("run_director"):
		_run_director = n
		break

# ============================================================
# 触发区交互
# ============================================================

func _on_body_entered(body: Node3D) -> void:
	if _active:
		return
	if not is_instance_valid(body):
		return
	if not body.is_in_group("player"):
		return
	# 互斥：已暂停（升级/死亡）则忽略本次进入
	if get_tree().paused:
		return
	if _shop_ui == null or not is_instance_valid(_shop_ui):
		_bind_shop_ui()
	if _shop_ui == null:
		return
	_active = true
	get_tree().paused = true
	# open 内部会刷新 UI、切鼠标为 VISIBLE
	_shop_ui.open(body, _run_director)

func _on_body_exited(body: Node3D) -> void:
	if not _active:
		return
	if not is_instance_valid(body):
		return
	if not body.is_in_group("player"):
		return
	# 玩家走出 → 关闭 UI（UI.close 会 emit closed → _on_shop_ui_closed 恢复暂停）
	if _shop_ui and is_instance_valid(_shop_ui):
		_shop_ui.close()

## ShopUI 关闭信号处理：恢复游戏暂停 + 复位 _active
## 三个来源都汇入此：ESC / 关闭按钮 / body_exited
func _on_shop_ui_closed() -> void:
	_active = false
	if is_inside_tree() and get_tree().paused:
		get_tree().paused = false
