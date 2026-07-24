Status: ready-for-agent
Blocked by: 无

# 修复 MeshLibrary trimesh 碰撞生成

## 构建内容

重新运行转换管线后，MeshLibrary 中每个网格项都包含 trimesh 碰撞体，玩家能在建筑和路面上行走、利用掩体。

## 验收标准

- [x] 转换脚本生成的 MeshLibrary 中，15 个网格项的 shapes 均包含 ConcavePolygonShape3D
- [x] 重新运行转换管线后，city-level.tscn 中 GridMap 的 MeshLibrary 包含碰撞体
- [ ] 游戏运行时，玩家角色能站在建筑/路面上，不穿过地面

## 评论
