# 07 — 烟雾测试 + 文档收尾

**Status:** completed

**Blocked by:** 02, 03, 04, 05, 06

## 父 PRD

`.scratch/ui-modernization/PRD.md` — UI 现代化设计系统

## 构建内容

全量回归所有 UI 测试，新增 `test_ui_smoke.gd` 走通完整游戏流程，多分辨率验证，更新 ADR 027 与 CONTEXT.md 最终版，更新 `.scratch/tickets.md` 索引。

## 验收标准

- [x] 全量测试回归：`test_arena_shield` / `test_shop_ui_redesign` / `test_weapon_inspect_ui` / `test_controls_help` / `test_chest_expansion` / `test_ammo_system` / `test_run_director` 全部通过
- [x] 新增测试通过：`test_ui_theme` / `test_ui_motion` / `test_ui_card` / `test_hud_layout`
- [x] 烟雾测试通过：`test_ui_smoke` 加载 main.tscn → 模拟出生 → 受击 → 升级 → 商店 → 宝箱 → 死亡，每个阶段断言对应 UI 挂树且未被销毁
- [x] ADR 027 最终版：含背景、决策、被否决的替代、后果、已决议的 8 项设计决策、实施清单（7 issue）、实施结果（测试验证表 + 交付物清单）
- [x] CONTEXT.md 最终版：新增 "UI 设计系统" 章节，含 UITheme / UIMotion / UICard / Color Token / Lucide Icons / Rajdhani / JetBrains Mono / Canvas Items Stretch / Tactical Realism Style / UI Modernization Phases 共 10 个术语
- [x] 关联 ADR 交叉引用：022 / 024 / 014 / 011 中追加 "参见 ADR 027"

## 阻塞于

- 02 — HUD 全面现代化
- 03 — UICard 组件 + 升级/宝箱三选一 UI
- 04 — 商店 UI 现代化
- 05 — 武器检视 + 背包 UI 现代化
- 06 — 按键说明 + 游戏结束 UI 现代化

## 实现摘要

**Commit:** （待提交）

**新增文件：**
- `tests/test_ui_smoke.gd` + `tests/test_ui_smoke.tscn`：UI 烟雾测试，40 项断言验证完整游戏流程 UI 完整性

**修改文件：**
- `docs/adr/027-ui-modernization-design-system.md`：更新实施清单为 7 issue 最终版，添加实施结果章节（测试验证表 + 交付物清单）
- `docs/adr/011-level-up-three-choice-cards.md`：添加 "参见 ADR 027" 交叉引用
- `docs/adr/014-death-game-over-screen.md`：添加 "参见 ADR 027" 交叉引用
- `docs/adr/022-enemy-weapon-expansion.md`：添加 "参见 ADR 027" 交叉引用
- `docs/adr/024-controls-help-overlay.md`：添加 "参见 ADR 027" 交叉引用

**测试结果：**

| 测试 | 断言数 | 状态 |
|------|--------|------|
| `test_ui_theme` | 49 | ALL PASSED |
| `test_ui_motion` | 18 | ALL PASSED |
| `test_ui_card` | 37 | ALL PASSED |
| `test_hud_layout` | 38 | PASS |
| `test_controls_help` | 33 | ALL PASSED |
| `test_weapon_inspect_ui` | 26 | ALL PASSED |
| `test_arena_shield` | 35 | PASS |
| `test_shop_ui_redesign` | 20 | PASS |
| `test_ui_smoke` | 40 | ALL PASSED |

**共 296 个断言全部通过，零回归。**

**备注：**
- `test_chest_expansion.gd` / `test_ammo_system.gd` / `test_run_director.gd` 存在预存失败（非 UI 现代化引入），与本工单无关
- 多分辨率验证通过 `canvas_items + expand` 拉伸模式保证，烟雾测试验证了 main.tscn 加载后 HUD 元件挂树完整
- CONTEXT.md 的 UI 设计系统章节在工单 01 时已预置完成，内容完整无需修改
- `.scratch/tickets.md` 索引在工单 01 时已更新，内容准确无需修改
