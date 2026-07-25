extends NavigationRegion3D

## 运行时烘焙整体 NavMesh 的容器节点。
##
## 在 _ready 中：
##   1. 配置 NavigationMesh 的 agent_max_climb = step_height（统一可通行阈值）
##   2. 调用 bake_navigation_mesh 同步烘焙——源几何来自本节点子树下的所有
##      collision shapes（GridMap cells、StaticBody3D 边界墙等）
##
## 怪物（monster_melee、monster_ranged）通过 NavigationAgent3D 引用此 navmesh 寻路。
##
## 参见：
##   - ADR 003
##   - CONTEXT.md "NavigationRegion3D"、"Runtime NavMesh Baking"、"Agent Max Climb"

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
