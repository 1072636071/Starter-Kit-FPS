# 07 — 烟雾测试 + 文档收尾

**Status:** ready-for-agent

**Blocked by:** 02, 03, 04, 05, 06

## 父 PRD

`.scratch/ui-modernization/PRD.md` — UI 现代化设计系统

## 构建内容

全量回归所有 UI 测试，新增 `test_ui_smoke.gd` 走通完整游戏流程，多分辨率验证，更新 ADR 027 与 CONTEXT.md 最终版，更新 `.scratch/tickets.md` 索引。

## 验收标准

- [ ] 全量测试回归：`test_arena_shield` / `test_shop_ui_redesign` / `test_weapon_inspect_ui` / `test_controls_help` / `test_chest_expansion` / `test_ammo_system` / `test_run_director` 全部通过
- [ ] 新增测试通过：`test_ui_theme` / `test_ui_motion` / `test_ui_card` / `test_hud_layout`
- [ ] 烟雾测试通过：`test_ui_smoke` 加载 main.tscn → 模拟出生 → 波次 → 受击 → 升级 → 商店 → 宝箱 → 死亡，每个阶段断言对应 UI 挂树且未被销毁
- [ ] 多分辨率验证：1280×720 / 1920×1080 / 2560×1440 下 HUD 无溢出、无遮挡
- [ ] ADR 027 最终版：含背景、决策、被否决的替代、后果、已决议的 8 项设计决策
- [ ] CONTEXT.md 最终版：新增 "UI 设计系统" 章节，含 UITheme / UIMotion / UICard / Color Token / Lucide Icons / Rajdhani / JetBrains Mono / Canvas Items Stretch / Tactical Realism Style / UI Modernization Phases 共 10 个术语
- [ ] 关联 ADR 交叉引用：022 / 024 / 014 / 011 中追加 "参见 ADR 027"

## 阻塞于

- 02 — HUD 全面现代化
- 03 — UICard 组件 + 升级/宝箱三选一 UI
- 04 — 商店 UI 现代化
- 05 — 武器检视 + 背包 UI 现代化
- 06 — 按键说明 + 游戏结束 UI 现代化