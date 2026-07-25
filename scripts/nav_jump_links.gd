extends Node
## 跳跃链接生成器：在 NavMesh 烘焙后自动生成 NavigationLink3D
## 连接地面与建筑顶部两个断开的 NavMesh 区域。
##
## 主策略：遍历 GridMap 找建筑顶部边缘 → 创建 NavigationLink3D
## 兜底策略：NavMesh 多边形分析（复杂度高，v1 暂不实现）
##
## 参见 ADR 021 与 CONTEXT.md「敌人跳跃导航系统」

## 生成跳跃链接
## gridmap: 已布局的 GridMap 节点
## nav_region: 已烘焙的 NavigationRegion3D（链接将挂在其下）
## jump_heights: Dictionary[StringName, float] — 怪物类型 → 跳跃高度
##   只取最大值作为链接生成的上限阈值
static func generate(gridmap: GridMap, nav_region: NavigationRegion3D, jump_heights: Dictionary) -> void:
	var used_cells: Array[Vector3i] = gridmap.get_used_cells()
	if used_cells.is_empty():
		return

	# 快速查找集合
	var cell_set: Dictionary = {}
	for cell in used_cells:
		cell_set[cell] = true

	# 取最大跳跃高度作为链接生成阈值
	var max_jump: float = 0.0
	for h in jump_heights.values():
		max_jump = max(max_jump, float(h))

	var cell_size := gridmap.cell_size
	if cell_size.y <= 0.0:
		return

	# 邻居方向：±X, ±Z
	var dirs: Array[Vector3i] = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	]

	for cell in used_cells:
		var above := Vector3i(cell.x, cell.y + 1, cell.z)
		if cell_set.has(above):
			continue  # 上方有 cell，不是顶部表面

		# 顶部表面：cell.y+1 层为空
		var top_y := float(cell.y + 1) * cell_size.y

		for dir in dirs:
			var neighbor := cell + dir
			if cell_set.has(neighbor):
				continue  # 该方向有 cell，不是边缘

			# 找该邻居列下方的地面高度
			var ground_y := _find_ground_y(cell_set, neighbor.x, neighbor.z, cell.y, cell_size.y)
			var height_diff := top_y - ground_y
			if height_diff <= 0.0 or height_diff > max_jump:
				continue

			# 计算边缘中心位置
			var edge_x := (float(cell.x) + 0.5 + float(dir.x) * 0.5) * cell_size.x
			var edge_z := (float(cell.z) + 0.5 + float(dir.z) * 0.5) * cell_size.z

			# 链接：地面边缘 → 建筑顶部边缘
			# 向空地方向偏移 0.3m（start），向建筑方向偏移 0.3m（end）
			# 确保点在各自 NavMesh 多边形内部
			var start := Vector3(edge_x + float(dir.x) * 0.3, ground_y + 0.05, edge_z + float(dir.z) * 0.3)
			var end := Vector3(edge_x - float(dir.x) * 0.3, top_y + 0.05, edge_z - float(dir.z) * 0.3)

			var link := NavigationLink3D.new()
			link.start_position = start
			link.end_position = end
			link.bidirectional = true
			link.enabled = true
			nav_region.add_child(link)


## 在 cell_set 中查找 (x, z) 列、max_y 以下的最高已用 cell 的顶部 y
static func _find_ground_y(cell_set: Dictionary, x: int, z: int, max_y: int, cell_size_y: float) -> float:
	var y := max_y - 1
	while y >= 0:
		if cell_set.has(Vector3i(x, y, z)):
			return float(y + 1) * cell_size_y
		y -= 1
	return 0.0