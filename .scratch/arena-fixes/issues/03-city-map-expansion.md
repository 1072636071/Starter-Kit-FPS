# 03 — 城市地图扩容至 160×160m

Status: ready-for-agent

## 父 issue

`.scratch/arena-fixes/PRD.md`

## 构建内容

城市地图从原始 122 格（~64×48m）扩展至 40×40 cells（160×160m），填满整个竞技场边界（±80m）。玩家在城市中战斗时有道路网格可机动、有中央广场可开阔交战、有建筑和公园可作掩体，走到地图边缘时被外圈建筑挡住而非坠入虚空。原始地图已备份可回退。

## 验收标准

- [ ] 原始 `scenes/city-level.tscn` 已备份为 `scenes/city-level-backup.tscn`
- [ ] `resources/city-map-data.json` 和 `city-builder/map-data.json` 同步更新为 40×40 布局
- [ ] 布局包含：主干道网格（每 5 格一条，坐标 -15/-10/-5/0/5/10/15）、中央 8×8 人行道广场（含喷泉）、街区混合建筑（structure 7-11）、散布公园（structure 12-14）
- [ ] 外圈（最外层 cell）为建筑（structure 7-11），作为天然视觉屏障
- [ ] 通过 `convert_map.gd` 转换管线重新生成 `scenes/city-level.tscn`
- [ ] MeshLibrary 缩放规格不变：`set_item_mesh_transform(i, Transform3D().scaled(CELL_SIZE))`，cell_size = Vector3(4,4,4)
- [ ] 生成的 GridMap 覆盖 40×40 cells（x∈[-20,19]、z∈[-20,19]）
- [ ] 运行游戏，玩家在城市内行走无虚空、无坠落
- [ ] 边界墙（±80m）与城市边缘重合，作为碰撞安全网保留
- [ ] NavMesh 运行时烘焙成功（怪物可正常寻路）

## 阻塞于

无——可立即开始。
