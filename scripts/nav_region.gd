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
	# agent_max_climb 决定 navmesh 在 ≤step_height 高差处连通，≥step_height 处断开
	# 引用工单 01 的全局常量，保证与玩家 Auto-Step 共用同一阈值
	navigation_mesh.agent_max_climb = StepConstants.STEP_HEIGHT
	# 同步烘焙（false = 不在后台线程，确保怪物 _ready 前 navmesh 就绪）
	# bake_navigation_mesh() 返回 void，无法捕获错误码；若烘焙失败，navmesh 数据为空，
	# 怪物寻路时会显现为不可达，可在运行时观察。
	bake_navigation_mesh(false)
