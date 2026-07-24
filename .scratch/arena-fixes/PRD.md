# 竞技场可玩性修复（Arena Fixes）

Status: ready-for-agent

## 问题陈述

玩家进入游戏后遇到三个阻断性体验问题：

1. **按 F 开波后怪物不出现**：怪物确实被实例化，但出生点位于城市地图范围外（无地面），怪物直接坠入虚空。由于怪物脚本缺少坠落死亡判定，`alive_count` 永远不归零，波次永远无法清场推进。
2. **地图边缘无屏障**：城市地图仅覆盖约 64×48m，而竞技场边界墙在 ±80m（160×160m）。城市边缘到边界墙之间是大片虚空，玩家走出城市瓦片后直接坠落。无视觉围栏提示边界。
3. **玩家枪械无颜色**：两把枪的 GLB 模型引用外部纹理 `Textures/colormap.png`（相对路径），但在 commit `ea001c6`（monster-weapons 功能）中，武器 GLB 从 `models/` 移至 `models/weapons/` 时，纹理被移到了 `models/environment/Textures/` 而非 `models/weapons/Textures/`，导致纹理引用断裂，枪械显示为纯灰/白色。

## 解决方案

三管齐下修复竞技场核心可玩性：

1. **怪物系统加固**：将 8 个出生点移至城市地图有瓦片覆盖的区域内；在怪物基类（`monster_base.gd`）增加坠落死亡安全网（`position.y < -10` → `destroy()`），确保任何原因坠落的怪物都能正常结算奖励并推进波次。
2. **城市地图扩容**：将城市地图从 122 格（~64×48m）扩展至 40×40 cells（160×160m），填满整个竞技场边界。布局采用「道路网格 + 街区建筑 + 中央广场 + 散布公园」模式，提供有战术纵深的战斗空间。备份原始 `city-level.tscn`。
3. **武器纹理恢复**：将 `models/environment/Textures/colormap.png` 复制到 `models/weapons/Textures/colormap.png`，恢复武器 GLB 的纹理引用，重新导入后枪械恢复彩色。

## 用户故事

1. 作为玩家，我想要按 F 开波后看到怪物出现在地图上，以便我能开始战斗。
2. 作为玩家，我想要怪物刷在有地面的位置上，以便它们不会直接掉进虚空消失。
3. 作为玩家，我想要即使怪物因任何原因坠落，它也能正常死亡并给我奖励，以便波次能正常推进。
4. 作为玩家，我想要怪物坠落后波次能正常清场，以便我不会卡在"等待不存在的怪物"的死局中。
5. 作为玩家，我想要走到地图边缘时被建筑或围栏挡住，以便我不会毫无预警地掉进虚空。
6. 作为玩家，我想要城市地图覆盖整个竞技场，以便我有足够的空间探索和战斗。
7. 作为玩家，我想要城市里有宽阔的广场，以便我有开阔的战斗区域。
8. 作为玩家，我想要城市里有街道网络，以便我可以利用街道机动和绕路。
9. 作为玩家，我想要城市里有建筑和公园作为掩体，以便战斗有战术深度。
10. 作为玩家，我想要看到我的枪有正确的颜色和纹理，以便我能获得正常的视觉体验。
11. 作为玩家，我想要切换武器时两把枪都有颜色，以便视觉体验一致。
12. 作为玩家，我想要商店摊位在地图内可达，以便我能正常购买弹药。
13. 作为玩家，我想要出生点分布在城市各方向，以便怪物从多个方向来袭。
14. 作为玩家，我想要怪物坠落时正常播放死亡动画和音效，以便反馈一致。
15. 作为玩家，我想要原始城市地图被备份，以便将来可以回退。

## 实现决策

### 怪物坠落死亡（monster_base.gd）

- 在 `monster_base.gd` 的 `_physics_process` 中增加坠落检测：`position.y < -10` 时调用 `destroy()`
- 复用已有的 `destroy()` 管线：播放 `die` 动画 → 发射 `died(monster_type)` 信号 → `queue_free()`
- RunDirector 正常收到 `died` 信号 → 结算奖励（金币/经验/击杀）→ 递减 `alive_count` → 清场检测
- 坠落阈值 `-10` 与玩家侧一致（`player.gd` 的 `position.y < -10`）
- 飞行敌人 `enemy.gd`（非 `monster_base` 子类）需单独加同样的坠落检测

### 出生点修正（main.tscn）

- 8 个 SpawnPoints（Marker3D）全部移至城市地图有瓦片覆盖的区域内
- 新地图为 40×40 cells（坐标 -20 到 19），出生点分布在城市四角和边缘道路上
- 出生点 y 坐标保持 0.5（略高于地面，避免卡地板）
- 商店摊位（ShopStation）位置调整到城市内可达区域

### 城市地图扩容（map-data.json → city-level.tscn）

- 目标：40×40 cells（160×160m），填满竞技场边界（±80m）
- 布局模式：
  - 主干道网格：每 5 格一条（坐标 -15/-10/-5/0/5/10/15），使用 road-straight（structure 0）+ road-intersection（structure 4）
  - 中央广场：8×8 人行道区域（structure 5/6），含喷泉（structure 6）
  - 街区建筑：道路之间的区块填充混合建筑（structure 7-11）
  - 散布公园：部分区块为草地（structure 12-14）
  - 外圈边界：最外层为建筑（structure 7-11），作为天然视觉屏障
- 备份原始 `scenes/city-level.tscn` 为 `scenes/city-level-backup.tscn`
- 同步更新 `city-builder/map-data.json` 和 `resources/city-map-data.json`
- 通过 `convert_map.gd` 转换管线重新生成 `city-level.tscn`
- MeshLibrary 缩放规格不变：`set_item_mesh_transform(i, Transform3D().scaled(CELL_SIZE))`
- 边界墙（Boundaries）保持在 ±80m（与城市边缘重合），作为碰撞安全网

### 武器纹理恢复

- 创建 `models/weapons/Textures/` 目录
- 复制 `models/environment/Textures/colormap.png` → `models/weapons/Textures/colormap.png`
- 重新导入 `blaster.glb` 和 `blaster-repeater.glb`（Godot 编辑器自动检测纹理变化）
- 根因：commit `ea001c6` 移动 GLB 时未同步复制纹理到新的相对路径

### 边界墙调整

- 城市扩至 ±80m 后，原有隐形边界墙（±80m）与城市边缘重合
- 保留边界墙作为碰撞安全网（防止玩家穿过建筑缝隙掉出）
- 外圈建筑提供视觉屏障，玩家不再看到虚空

## 测试决策

### 什么是好测试

- 仅测试外部行为（信号发射、状态变化），不测内部实现细节
- 测试边界条件（恰好 y=-10、恰好 y=-9.9）
- 测试与已有系统的集成（died 信号 → RunDirector 奖励结算）

### 测试目标

1. **怪物坠落死亡**：
   - 设怪物 `position.y = -11` → 验证 `died` 信号发射、`_dead = true`
   - 设怪物 `position.y = -9` → 验证不触发死亡
   - 验证坠落后 RunDirector 的 `alive_count` 正确递减
   - 先例：`tests/test_monster_died_signal.gd`

2. **出生点位置**：
   - 验证所有 SpawnPoints 的 (x, z) 在城市 GridMap 覆盖范围内
   - 验证出生点 y > 0（不在地下）

3. **城市地图覆盖**：
   - 验证生成的 GridMap 覆盖 40×40 cells
   - 验证城市边缘有建筑（外圈 structure 7-11）

4. **武器纹理**：
   - 验证 `models/weapons/Textures/colormap.png` 存在
   - 视觉验证：枪械在 SubViewport 中显示彩色

### 测试先例

- `tests/test_monster_died_signal.gd` — 怪物 died 信号测试
- `tests/test_run_director.gd` — RunDirector 波次/奖励测试
- `tests/test_shoot_after_tree_exit.gd` — 射击系统测试

## 超出范围

- **城市地图美术设计**：本 spec 只定义布局结构（道路网格 + 建筑 + 广场），不定义具体每格放什么。具体布局由实现者按规则生成。
- **NavMesh 性能优化**：40×40 cells 的 NavMesh 烘焙可能较慢，但不在本 spec 范围内优化。
- **边界墙视觉美化**：外圈建筑已提供视觉屏障，不额外添加围栏模型。
- **新武器模型**：不替换现有武器 GLB，仅修复纹理引用。
- **怪物 AI 改进**：不改变怪物寻路/攻击逻辑，仅加坠落安全网。
- **City Builder 编辑器功能**：不修改 City Builder 项目本身，直接修改 JSON 数据。

## 补充说明

- 三个问题在 grill 会话中确认，详见 CONTEXT.md 中更新的术语条目：Spawn Point（布局约束）、Monster Fall Death（怪物坠落死亡）、GridMap（地图扩容决策）、Weapon（纹理依赖）
- 城市地图扩展后，出生点坐标和商店位置需要同步调整（依赖新地图布局）
- 转换管线（`convert_map.gd`）是 EditorScript，需在 Godot 编辑器中通过 File > Run 执行
- 武器纹理修复是最简单的 fix（文件复制），可优先实施
