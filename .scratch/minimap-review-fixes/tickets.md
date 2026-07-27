# 工单：minimap-review-fixes

修复 `jxx-code-review` 在 HEAD 未提交 diff 中发现的问题。来源：2026-07-27 对 `.scratch/minimap/issues/05-player-centered-follow.md`（T5）与 `06-off-screen-indicators.md`（T6）实现的 review 报告。

按**前沿**推进：T1 可立即开始；T2 阻塞于 T1。

**注**：原 T3（拆分混入的无关变更）已删除——这些变更由另外修复处理（独立 bug 与后续计划）。

## 核查状态（2026-07-27）

所有 2 个工单问题已通过代码与 spec 核查，确认为真实问题（非误报）：

- **T1 已确认**：[scripts/minimap.gd:17](file:///g:/work/Starter-Kit-FPS/scripts/minimap.gd#L17) `view_radius=160.0` 与注释「半高 160m → ±160m」均错。证据链：
  - [ADR 026 行12/44/47](file:///g:/work/Starter-Kit-FPS/docs/adr/026-minimap-player-centered-follow.md) 明确「初值 80m」「v1 固定 80m」
  - [spec 05 行17](file:///g:/work/Starter-Kit-FPS/.scratch/minimap/issues/05-player-centered-follow.md#L17) 验收标准「初值 80」
  - [test_minimap_t1.gd:39-40](file:///g:/work/Starter-Kit-FPS/tests/test_minimap_t1.gd#L39-L40) 注释自相矛盾：「Godot 4 中 size 为视口**全高** → 半高 80m → 覆盖 ±80 世界」+ 断言 `cam.size == 160`
  - 即项目自身测试文件已确认 Godot 正交 size 语义（视口全高），minimap.gd 注释事实错误
- **T2 已确认**：[Glob `tests/test_minimap_t*.gd`](tests/) 仅返回 t1/t2/t3，无 t4。spec 06 行19 要求的独立测试文件缺失，[test_minimap_t3.gd:164-169](file:///g:/work/Starter-Kit-FPS/tests/test_minimap_t3.gd#L164-L169) 仅加方法存在断言（`has_method("_draw_edge_indicator")`），未验证方向/颜色/混合场景。
## T1 — 修复 view_radius 投影半径错误

**构建内容：** 让小地图 blip 投影范围与相机实际渲染范围对齐，使 spec 05/06 中「≤80m 圆点 / >80m 屏外箭头」的核心行为正确生效。当前 `view_radius=160.0` 基于对 Godot `Camera3D.size`（正交模式）语义的误解——`size` 是视口**全高**而非半高，故 size=160 → 半高 80m → 覆盖 ±80m；而 blip 投影按 ±160m 计算，导致 80–160m 敌人被画为圆点（违反 spec 05 行 13/14），屏外箭头仅在 >160m 触发（违反 spec 06 行 12）。

**阻塞于：** 无——可立即开始

- [ ] [scripts/minimap.gd:17](file:///g:/work/Starter-Kit-FPS/scripts/minimap.gd#L17) `view_radius` 改为 `80.0`
- [ ] 修正 [scripts/minimap.gd:15](file:///g:/work/Starter-Kit-FPS/scripts/minimap.gd#L15) 注释：明确 Godot `Camera3D.size`（正交模式）= 视口全高，size=160 → 半高 80m → 覆盖 ±80m
- [ ] [tests/test_minimap_t3.gd](file:///g:/work/Starter-Kit-FPS/tests/test_minimap_t3.gd) 还原 ±80m 投影断言（行 57/68/72/76/80 不再用 ±160m）
- [ ] `test_minimap_t1` 与 `test_minimap_t3` 全部通过
- [ ] 80–160m 敌人不再被画为圆点（修复 spec 05 行 13/14 违反）
- [ ] 屏外箭头在 >80m 时触发（修复 spec 06 行 12 违反）

## T2 — 新增 test_minimap_t4 屏外箭头测试

**构建内容：** T6 spec 行 19 要求的独立测试文件，验证屏外威胁指示器的方向、颜色与图内/图外混合场景行为。当前 diff 仅在 `test_minimap_t3.gd` 加了 `10a` 方法存在断言，未满足 spec 要求的独立测试文件。

**阻塞于：** T1（`view_radius` 必须正确才能验证箭头触发阈值）

- [ ] 新建 `tests/test_minimap_t4.gd`
- [ ] 验证图外敌人（距玩家 > view_radius）在圆形边缘对应方向画三角形箭头
- [ ] 验证近战敌人箭头=红色、远程敌人箭头=黄色（与图内圆点着色一致）
- [ ] 验证箭头指向离圆心方向（即"敌人在那边"）
- [ ] 验证图内敌人（≤ view_radius）仍画圆点，行为不变
- [ ] 验证零敌人=零箭头
- [ ] 验证图内/图外混合场景
- [ ] 测试通过

