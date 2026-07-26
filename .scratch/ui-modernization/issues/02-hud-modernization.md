# 02 — HUD 全面现代化

**Status:** ready-for-agent

**Blocked by:** 01

## 父 PRD

`.scratch/ui-modernization/PRD.md` — UI 现代化设计系统

## 构建内容

重构 `hud.gd` 全部 6 个 HUD 元件（左上信息条 / 左下护盾 / 右下弹药 / 右下手雷 / 中下提示词 / 右上小地图框）。引用 UITheme token 取代硬编码颜色，emoji 替换为 SVG 图标，锚点+容器布局取代像素硬编码，引入 UIMotion 动效（出现/数值变化/低血脉冲）。玩家进入游戏即可看到全新 Valorant 风格 HUD。

## 验收标准

- [ ] 左上信息条：4 个图标-数值对（coins / Lv / 波次 / 击杀），JetBrains Mono 数字 + Rajdhani 标签，锚定左上角
- [ ] 左下护盾条：shield 图标 + 数值 + 充能速率 + ProgressBar，冷却中变橙色倒计时，归零脉冲警示
- [ ] 右下弹药列表：当前武器 `accent_primary` 左边竖条高亮，JetBrains Mono 数字，空弹脉冲警示，换弹进度条 + 耐久度条
- [ ] 右下手雷：zap/flame 图标区分 EMP/破片，选中态高亮
- [ ] 中下提示词群：波次/宝箱/卡住/整理中提示，Rajdhani SemiBold，滑入/滑出动效 120ms
- [ ] 右上小地图：描边外框 + 坐标信息条 + 屏外敌人指示器
- [ ] 所有 emoji（🪙⚡💥●◆▬）已移除，全部替换为 SVG 图标
- [ ] 所有 `offset_left = -220` 等绝对像素坐标已移除，改为锚点+容器
- [ ] 测试通过：`test_arena_shield` 信号断言保持；`test_hud_layout` 验证元件挂树且无 emoji

## 阻塞于

- 01 — UI 基础设施