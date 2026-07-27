extends Control
## 小地图 blip 叠加层（T3）
##
## 挂在 HUD/Minimap 下的 Blips 子 Control 上（Background 的兄弟）。
## 每帧把玩家与敌人世界 (x,z) 线性投影为小地图局部像素坐标，
## 用 _draw() 直接绘制：
##   - 玩家：朝向箭头（三角形），随玩家 yaw 旋转
##   - 敌人：圆点，melee=红 / ranged=黄（深浅区分）
##
## 投影：北朝上、全图固定正交相机 → 线性映射，无需透视除法
## （见 CONTEXT.md「Minimap Projection」、ADR 007「图层过滤」）。
## 不按视线/距离过滤（见 CONTEXT.md「Enemy Blip」）。

# 小地图视图半径（m）—— 玩家中心跟随的覆盖半径
# 与 MinimapCamera.size=160 对齐：Godot 正交 size 为视口全高，
# size=160 → 半高 80m → 世界覆盖 ±80m（即 view_radius=80）
# 可在运行时按需调整（如缩放）
var view_radius: float = 80.0

# blip 视觉参数
const PLAYER_COLOR := Color(0.85, 1.0, 0.95, 1.0) # 亮青白
const PLAYER_ARROW_SIZE := 7.0 # 箭头三角形外接半径（px）
const MELEE_COLOR := Color(1.0, 0.32, 0.28, 1.0) # 红
const RANGED_COLOR := Color(1.0, 0.78, 0.25, 1.0) # 暖黄
const ENEMY_RADIUS := 4.0 # 圆点半径（px）

# 边框视觉参数
const BORDER_COLOR := Color(1.0, 1.0, 1.0, 0.9) # 白色边框
const BORDER_WIDTH := 2.0 # 边框线宽（px）
const BORDER_INSET := 1.0 # 边框相对控件边缘的内缩（px），避免被裁剪

# 敌人计数显示参数
const ENEMY_COUNT_COLOR := Color(1.0, 1.0, 1.0, 1.0) # 白色文字
const ENEMY_COUNT_OUTLINE := Color(0, 0, 0, 0.85) # 黑色描边
const ENEMY_COUNT_FONT_SIZE := 18
const ENEMY_COUNT_MARGIN := 6.0 # 文字距顶边距离（px）

# 怪物脚本资源路径（用于区分 melee / ranged）
const MELEE_SCRIPT_PATH := "res://objects/monster_melee.gd"
const RANGED_SCRIPT_PATH := "res://objects/monster_ranged.gd"

var _player: Node3D = null
var _monsters: Array = [] # Array[CharacterBody3D]
var _count_font: Font = null # 敌人计数文字字体（用默认主题字体）
var _minimap_camera: Camera3D = null # MinimapViewport 的俯视正交相机

func _ready() -> void:
	# 玩家：经 "player" group 查找（main.tscn 中 Player 节点 groups=["player"]）
	_player = get_tree().get_first_node_in_group("player")
	# MinimapCamera：/root/Main/MinimapViewport/MinimapCamera
	_minimap_camera = get_node_or_null("/root/Main/MinimapViewport/MinimapCamera")
	if not _minimap_camera:
		push_warning("[minimap] MinimapCamera not found at /root/Main/MinimapViewport/MinimapCamera — camera-follow disabled")
	# 怪物：Monsters 节点的直接子节点（main.tscn 中 Main/Monsters/{MeleeA,...}）
	# 用延迟一帧查找，确保场景树已完全实例化
	call_deferred("_refresh_monsters")
	# 监听 RunDirector 波次开始信号，动态刷新怪物列表（F 键开波后新怪物入列）
	var run_director := get_tree().get_first_node_in_group("run_director")
	if run_director and run_director.has_signal("wave_started"):
		run_director.wave_started.connect(_on_wave_started)
	# 取默认主题字体用于绘制敌人计数
	_count_font = get_theme_default_font()

## 波次开始后延迟刷新怪物列表（等怪物实例化并加入场景树）
func _on_wave_started(_wave_number: int) -> void:
	call_deferred("_refresh_monsters")

func _refresh_monsters() -> void:
	_monsters.clear()
	# 优先从 /root/Main/Monsters 查找（main.tscn 中 Main/Monsters/{MeleeA, MeleeB, RangedA, RangedB}）
	var monsters_node := get_node_or_null("/root/Main/Monsters")
	if monsters_node:
		for c in monsters_node.get_children():
			if c is CharacterBody3D:
				_monsters.append(c)
		return
	# 兜底：扫描全树 CharacterBody3D，按脚本路径过滤 melee/ranged
	_scan_character_bodies(get_tree().root)

func _scan_character_bodies(root: Node) -> void:
	for c in root.get_children():
		if c is CharacterBody3D and c != _player:
			var script: Script = c.get_script()
			if script and script.resource_path in [MELEE_SCRIPT_PATH, RANGED_SCRIPT_PATH]:
				_monsters.append(c)
		_scan_character_bodies(c)

func _process(_delta: float) -> void:
	# 相机跟随玩家 x/z（y 保持 80 俯视高度，朝向不变 north-up）
	if _minimap_camera and is_instance_valid(_minimap_camera) and _player and is_instance_valid(_player):
		var ppos := _player.global_position
		_minimap_camera.global_position.x = ppos.x
		_minimap_camera.global_position.z = ppos.z
	# 每帧重绘 blip（位置/朝向随玩家与敌人移动）
	queue_redraw()

## 世界 (x,z) → 本 Control 局部像素坐标（相对玩家）
## 北朝上：world -Z → 图像上方（pixel.y = 0）
## 东朝右：world +X → 图像右方（pixel.x = size.x）
## 投影以玩家位置为中心：uv = (world - player + view_radius) / (2 × view_radius)
func _world_to_pixel(world_x: float, world_z: float) -> Vector2:
	# is_instance_valid 必须：Godot 4 中 queue_free() 后引用不为 null
	var player_valid := _player != null and is_instance_valid(_player)
	var player_x := _player.global_position.x if player_valid else 0.0
	var player_z := _player.global_position.z if player_valid else 0.0
	var uv_x := (world_x - player_x + view_radius) / (view_radius * 2.0)
	var uv_y := (world_z - player_z + view_radius) / (view_radius * 2.0)
	return Vector2(uv_x * size.x, uv_y * size.y)

func _draw() -> void:
	if not is_inside_tree():
		return
	if size.x <= 1.0 or size.y <= 1.0:
		return

	var center := Vector2(size.x * 0.5, size.y * 0.5)
	var radius: float = min(size.x, size.y) * 0.5 - BORDER_INSET
	var clip_r: float = radius - ENEMY_RADIUS # blip 圆形裁剪半径（留 ENEMY_RADIUS 余量避免硬切）

	# 1. 玩家箭头（圆形裁剪：超出 clip_r 不画）
	if _player and is_instance_valid(_player):
		var ppos := _player.global_position
		var pixel := _world_to_pixel(ppos.x, ppos.z)
		if pixel.distance_to(center) <= clip_r:
			var fwd := horizontal_forward(_player)
			if fwd == Vector3.ZERO:
				# 退化：无法判定朝向（forward 退化为零向量），画一个小圆点占位
				draw_circle(pixel, PLAYER_ARROW_SIZE * 0.6, PLAYER_COLOR)
			else:
				var yaw_rad: float = arrow_yaw_from_forward(fwd)
				_draw_arrow(pixel, yaw_rad, PLAYER_ARROW_SIZE, PLAYER_COLOR)

	# 2. 敌人圆点（同时统计有效敌人数量；圆形裁剪：超出 clip_r 不画）
	var alive_count := 0
	for m in _monsters:
		if not is_instance_valid(m):
			continue
		alive_count += 1
		var mpos: Vector3 = m.global_position
		var pixel := _world_to_pixel(mpos.x, mpos.z)
		var dist_to_center := pixel.distance_to(center)
		var color := enemy_color(m)
		if dist_to_center > clip_r:
			# 屏外敌人：在圆形边缘画方向箭头，指向敌人所在方向
			var angle: float = atan2(pixel.y - center.y, pixel.x - center.x)
			var edge_pos := center + Vector2(cos(angle), sin(angle)) * (radius - ENEMY_RADIUS - 1)
			_draw_edge_indicator(edge_pos, angle, color)
			continue
		draw_circle(pixel, ENEMY_RADIUS, color)

	# 3. 圆形边框（draw_arc 沿圆周画线，不受 shader 裁剪影响）
	draw_arc(center, radius, 0.0, TAU, 64, BORDER_COLOR, BORDER_WIDTH)

	# 4. 剩余敌人计数（顶部居中文字）
	if _count_font:
		var text := "敌人: %d" % alive_count
		var text_size := _count_font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, ENEMY_COUNT_FONT_SIZE)
		var text_pos := Vector2(center.x - text_size.x * 0.5, ENEMY_COUNT_MARGIN + text_size.y)
		# 黑色描边（先画一圈偏移的黑色再画白色正文，简单 outline）
		for offs in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			_count_font.draw_string(get_canvas_item(), text_pos + offs, text, HORIZONTAL_ALIGNMENT_CENTER, -1, ENEMY_COUNT_FONT_SIZE, ENEMY_COUNT_OUTLINE)
		_count_font.draw_string(get_canvas_item(), text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, ENEMY_COUNT_FONT_SIZE, ENEMY_COUNT_COLOR)

## 取玩家水平前向（XZ 平面、归一化）。
## forward 退化为零向量时返回 Vector3.ZERO（调用方负责占位渲染）。
func horizontal_forward(player: Node3D) -> Vector3:
	var fwd := -player.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() <= 0.0001:
		return Vector3.ZERO
	return fwd.normalized()

## 由水平前向换算小地图箭头旋转（弧度）。
## 北 (fwd.z<0) → 0；东 (fwd.x>0) → +π/2；南 → ±π；西 → -π/2。
static func arrow_yaw_from_forward(fwd: Vector3) -> float:
	return atan2(fwd.x, -fwd.z)

## 区分 melee / ranged：按脚本资源路径
func enemy_color(node: Node) -> Color:
	var script: Script = node.get_script()
	if script:
		var path: String = script.resource_path
		if path == MELEE_SCRIPT_PATH:
			return MELEE_COLOR
		if path == RANGED_SCRIPT_PATH:
			return RANGED_COLOR
	# 未知敌人类型 → 默认 melee 色
	return MELEE_COLOR

## 绘制朝向箭头（指向上方的等腰三角形，绕中心旋转 yaw_rad）
## 顶点（指向上方）：(0, -size)
## 底边两点：(±size*0.6, +size*0.5)
func _draw_arrow(center: Vector2, yaw_rad: float, arrow_size: float, color: Color) -> void:
	var tip := Vector2(0.0, -arrow_size).rotated(yaw_rad) + center
	var bl := Vector2(-arrow_size * 0.6, arrow_size * 0.5).rotated(yaw_rad) + center
	var br := Vector2(arrow_size * 0.6, arrow_size * 0.5).rotated(yaw_rad) + center
	var pts := PackedVector2Array([tip, br, bl])
	draw_colored_polygon(pts, color)

## 绘制屏外威胁指示器 —— 小三角形箭头，位于边缘 edge_pos，指向 angle 方向（离圆心）
## 尺寸约 ENEMY_RADIUS*1.5 外接半径，比玩家箭头小
func _draw_edge_indicator(edge_pos: Vector2, angle: float, color: Color) -> void:
	const EDGE_ARROW_SIZE: float = 6.0
	var tip := edge_pos + Vector2(cos(angle), sin(angle)) * EDGE_ARROW_SIZE
	var bl := edge_pos + Vector2(cos(angle + PI * 0.65), sin(angle + PI * 0.65)) * EDGE_ARROW_SIZE * 0.6
	var br := edge_pos + Vector2(cos(angle - PI * 0.65), sin(angle - PI * 0.65)) * EDGE_ARROW_SIZE * 0.6
	var pts := PackedVector2Array([tip, br, bl])
	draw_colored_polygon(pts, color)
