extends NavigationRegion3D

## 运行时烘焙整体 NavMesh 的容器节点。
##
## 在 _ready 中：
##   1. 配置 NavigationMesh 的 agent_max_climb = step_height（统一可通行阈值）
##   2. 调用 bake_navigation_mesh 同步烘焙——源几何来自本节点子树下的所有
##      collision shapes（GridMap cells、StaticBody3D 边界墙等）
##   3. 调用 NavJumpLinks.generate() 生成跳跃链接（ADR 021）
##
## 怪物（monster_melee、monster_ranged）通过 NavigationAgent3D 引用此 navmesh 寻路。
##
## 参见：
##   - ADR 003
##   - ADR 021
##   - CONTEXT.md "NavigationRegion3D"、"Runtime NavMesh Baking"、"Agent Max Climb"

const NavJumpLinks = preload("res://scripts/nav_jump_links.gd")

## 怪物类型 → 跳跃高度（m），供 NavJumpLinks 生成链接时使用
const JUMP_HEIGHTS := {
	&"monster_melee": 5.0,
	&"monster_ranged": 2.0,
}

func _ready() -> void:
	if navigation_mesh == null:
		navigation_mesh = NavigationMesh.new()
	# ADR 017：NavMesh 参数优化
	navigation_mesh.agent_radius = 0.5       # 与怪物碰撞体匹配 + 缓冲
	navigation_mesh.agent_height = 1.5       # 怪物模型高度
	navigation_mesh.cell_size = 0.25         # 精度提升（默认 0.3 太粗），路径更贴合墙壁
	navigation_mesh.agent_max_climb = StepConstants.STEP_HEIGHT  # 统一可通行阈值
	navigation_mesh.agent_max_slope = 45.0   # 最大斜坡角度
	# 同步烘焙（false = 不在后台线程，确保怪物 _ready 前 navmesh 就绪）
	bake_navigation_mesh(false)

	# ADR 021：烘焙后生成跳跃链接
	var gridmap := _find_gridmap()
	if gridmap:
		NavJumpLinks.generate(gridmap, self, JUMP_HEIGHTS)


## 在子节点中查找 GridMap
func _find_gridmap() -> GridMap:
	for child in get_children():
		if child is GridMap:
			return child
	return null
