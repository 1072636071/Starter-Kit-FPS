# 工单真实状态审计

- 审计日期：2026-07-25
- 审计范围：`.scratch/` 下全部 17 个 feature 目录、共 **94 个工单**
- 审计方式：每个工单由 1 个只读子代理独立核查——读工单 → 依据代码（`.gd`/`.tscn`/`.tres`/tests）逐项验证验收标准 → 给出真实状态。共 10 批、每批 10 个并行任务。
- 状态定义：`done` = 验收项全部实现且有测试或代码实证；`partial` = 部分完成/缺测试/与验收不符；`not-done` = 未实现或声称失实；`blocked` = 依赖未解工单。

## 一、核心结论

工单文件头里的 `Status:` 行**严重不可信**，不能用来判断进度。本次核查发现：

- **94 个工单中真实 `done` 64 个、`partial` 28 个、`not-done` 2 个、`blocked` 0 个。**
- **30 个工单被高估**：声称 `done`/`resolved`/`completed`，实际只是 `partial` 或 `not-done`（含 2 个彻底 `not-done`：子弹商店站、远程怪群装配）。
- **15 个工单被低估**：声称 `ready-for-agent`（待办），代码与测试其实早已完成，应为 `done`。
- 普遍问题：**绝大多数 `done` 工单的验收勾选框从未被打勾**，且 **28 个 `partial` 工单里大部分缺少专项测试**；部分功能依赖的 `ENEMY_CONFIG` 仍以注释形式存在、未激活。

## 二、声称状态 vs 真实状态对照

| 声称状态 | 工单数 | 其中真实 done | 真实 partial | 真实 not-done |
|---|---|---|---|---|
| done / resolved / completed | ~70 | ~40 | 28 | 2 |
| ready-for-agent / ready-for-human（待办） | ~17 | 15 | 0 | 2（规划项） |
| 无 Status（规划文档） | 2 | 1 | 1 | 0 |

> 说明：含多个同一 feature 下连续编号工单，总数与 94 略有口径差异，但趋势明确——**"声称完成"的工单里约 30% 实际未达标，"声称待办"的工单里约 90% 实际已完成。**

## 三、需要重点关注的工单

### 3.1 真实 not-done（声称 done/resolved）

| 工单 | 声称 | 真实 | 原因 |
|---|---|---|---|
| roguelike-arena/04-bullet-shop-station | resolved | **not-done** | `shop_ui` 已被 issue22 重写为三区设计，原"子弹商店站"逻辑不复存在，工单需求被新设计吸收/取代。 |
| roguelike-arena/18-assemble-ranged-group | done | **not-done** | `ENEMY_CONFIG` 被注释、模块未正确接线、无任何测试；声称 done 但验收框全空。 |
| city-editor（城市编辑器作为场景编辑器） | ready-for-human | **not-done** | 纯规划文档，FPS↔编辑器模式切换、GridMap 共享、相机切换等从未实施，`city-builder/` 仍是独立子项目。 |

### 3.2 高风险 partial（声称 done，但实现与验收不符，建议立即修）

| 工单 | 关键问题 |
|---|---|
| roguelike-arena/03-kill-rewards | 奖励值写死 500/800/1000，与 issue07 描述的 5/8/10 "铜"单位不符。 |
| roguelike-arena/07-hud-integration | HUD 用旧 player 信号名（`free_ammo`/`clip_ammo`），缺 `max_ammo`/`update_ammo()` 接线。 |
| roguelike-arena/16,17,18 assemble-* | 敌人 config 注释掉、模块名错配、无测试、数值偏差。 |
| roguelike-arena/27-balance-tuning | `ENEMY_CONFIG` 敌群整段注释，未生效。 |
| roguelike-arena-cr-fixes/38-populate-enemy-config | 仅测试修复，config 仍只有 3 条激活、缺完整性测试。 |
| currency-backpack/02-currency-conversion | `tests/test_shop.gd` 仍调用已删除的 `add_gold(50)`，编译期失效。 |
| currency-backpack/07-upgrade-backpack-weight | 升级池已扩展，但缺对应测试验证。 |
| melee/01-import-sword-viewmodel | 场景引用 `Mistsplitter.glb` 而非工单声称的 `quaternius_swords.glb`。 |
| monster-weapons/02-melee-monster-holds-sword | 默认武器 `Sword6.glb` 与玩家相同，未用"不同 SwordXXX"。 |
| hit-feedback/02-wire-ranged-and-flying | `monster_ranged` 的 `damage()` 从未调用 `HitFeedback.flash`，仅 `enemy` 接入。 |
| arena-fixes/05-stuck-struggle | 挣扎键实际绑定 **H 键 (72)**，工单声称 G 键。 |
| arena-fixes/04-spawn-points-shop | 出生点/商店已配置但缺瓦片校验测试，依赖 issue03 新地图。 |
| controls-help/01,02 | 分组命名不符（缺"射击/经济"）、未真正注入 F5 键、缺门控测试。 |
| projectile/01,03 | 弹体速度范围与验收不符、部分武器 `.tres` 速度超界、缺测试。 |
| step-and-monster-nav/02,03 | 用 `test_move` 而非验收规定的 `RayCast3D`/`ShapeCast3D`；navmesh 缺调试可视化与连通性测试。 |

## 四、全量核查表

### roguelike-arena（30）
| 工单 | 声称 | 真实 | 关键发现 |
|---|---|---|---|
| 01-shield-layer | resolved | done | ShieldLayer 单例+scene_unique 消除重复 |
| 02-wave-spawn-controller | resolved | done | run_director 波次/暂停；test_smoke_waves 通过 |
| 03-kill-rewards | resolved | partial | 奖励值 500/800/1000 与"铜"单位描述不符 |
| 04-bullet-shop-station | resolved | not-done | 被 issue22 三区商店重写取代 |
| 05-level-up-cards | resolved | done | level_up_ui 实现+测试 |
| 06-game-over-screen | resolved | done | game_over 结算+测试 |
| 07-hud-integration | resolved | partial | HUD 用旧信号名，缺 max_ammo/update_ammo 接线 |
| 08-chest | resolved | done | chest_ui 完整 |
| 09-module-system-architecture | review | done | ModuleManager 架构+加载 |
| 10-modules-stealth-dash | resolved | done | 隐身+冲刺模块 |
| 11-module-summon-pet | resolved | done | 召唤宠物（GLB 未找到但代码在） |
| 12-module-place-trap | resolved | done | 放陷阱模块 |
| 13-module-combat | resolved | done | 战斗模块 |
| 14-module-aura | resolved | done | 光环模块 |
| 15-module-projectile | resolved | done | 弹道模块 |
| 16-assemble-anchor-enemies | done | partial | config 注释、无测试、数值偏差 |
| 17-assemble-melee-group | done | partial | 模块名错配、config 注释、无测试 |
| 18-assemble-ranged-group | done | not-done | config 注释、模块未接线、无测试 |
| 19-weapon-tres-batch | done | partial | .tres 已生成但缺测试、GLB import 不完整 |
| 20-weapon-durability | done | done | 耐久系统 |
| 21-ammo-pool-drop-pickup | done | partial | 掉落/拾取未全验证 |
| 22-shop-ui-redesign | done | partial | 蓝图加载缺容错与测试 |
| 23-grenade-system | done | done | EMP 受影响计数 HUD 小缺 |
| 24-chest-expansion | done | done | 宝箱扩展 |
| 25-weapon-inspect-verify | done | done | 检视校验 |
| 26-integration-smoke-test | done | partial | 三烟测通过但缺"暂停后可继续"断言 |
| 27-balance-tuning | done | partial | ENEMY_CONFIG 敌群注释未生效 |
| 28-code-review-bugs | ready-for-agent | done | CR bug 修复已落地 |
| 29-code-review-missing-spec | ready-for-agent | partial | 5/8 完成 |
| 30-code-review-quality | ready-for-agent | partial | 1/7 完成 |

### roguelike-arena-cr-fixes（8）
| 工单 | 声称 | 真实 | 关键发现 |
|---|---|---|---|
| 01-cr-fix-beam-durability | done | done | beam tick 扣耐久，缺专项测试 |
| 02-cr-fix-grenade-bugs | done | done | 三 bug 修复落地 |
| 03-cr-fix-grenade-arc-preview | done | partial | 缺暂停决策与测试 |
| 04-cr-fix-shop-visual | done | partial | 视觉已实现，缺测试 |
| 05-cr-refactor-shop-ui | done | done | 三区刷新去重重构 |
| 06-cr-refactor-chest-coupling | done | done | 解耦重构 |
| 07-cr-fix-smoke-tests | done | done | 三测试均通过 |
| 08-cr-populate-enemy-config | done | partial | 仅测试修复，config 仍 3 条、缺完整性测试 |

### ammo-hud（5）
| 工单 | 声称 | 真实 | 关键发现 |
|---|---|---|---|
| 01-weapon-ammo-schema | ready-for-agent | done | 4 字段+配置已落地（状态滞后） |
| 02-ammo-state-shoot | ready-for-agent | done | 弹匣/备弹状态已落地 |
| 03-ammo-hud-list | ready-for-agent | done | 弹药列表+高亮，有测试 |
| 04-reload-mechanism | ready-for-agent | done | 换弹机制+测试 |
| 05-reload-visual | ready-for-agent | done | 换弹动画+进度条 |

### arena-fixes（7）
| 工单 | 声称 | 真实 | 关键发现 |
|---|---|---|---|
| 01-weapon-texture | done | done | colormap 纹理恢复 |
| 02-monster-fall-death | ready-for-agent | done | 坠落死亡+测试 |
| 03-city-map-expansion | ready-for-agent | done | 160×160m 扩容落地，缺测试 |
| 04-spawn-points-shop | ready-for-agent | partial | 出生点/商店已配，缺瓦片校验 |
| 05-stuck-struggle | ready-for-agent | partial | 挣扎键实为 H 而非 G |
| 06-enemy-ai-overhaul | ready-for-agent | done | FSM/RVO/视线/飞行 AI 落地 |
| 07-chain-aggro | ready-for-agent | done | AlertSystem+测试，半径被 ADR 翻倍 |

### currency-backpack（7）
| 工单 | 声称 | 真实 | 关键发现 |
|---|---|---|---|
| 01-alert-range-double | resolved | done | 感知参数翻倍+测试 |
| 02-currency-conversion | done | partial | test_shop.gd 仍调已删 add_gold |
| 03-backpack-data-model | done | done | 背包数据模型 |
| 04-ammo-slots-reload | done | done | 备弹槽系统 |
| 05-backpack-ui | done | done | 背包 UI（无 .tscn，GDScript 实例化） |
| 06-shop-hud-update | done | done | 商店货币显示 |
| 07-upgrade-backpack-weight | done | partial | 缺升级测试 |

### melee（5）
| 工单 | 声称 | 真实 | 关键发现 |
|---|---|---|---|
| 01-import-sword-viewmodel | completed | partial | 引用 Mistsplitter 而非 quaternius |
| 02-melee-input-action | completed | done | V 键 melee 动作 |
| 03-melee-core-viewmodel | completed | done | 近战核心+测试 |
| 04-melee-hitbox-damage | completed | done | 命中盒+扣血+去重 |
| 05-verify-and-tune | ready-for-agent | done | 端到端调参验证 |

### projectile（6）
| 工单 | 声称 | 真实 | 关键发现 |
|---|---|---|---|
| 01-scene-and-weapon-props | resolved | partial | 速度范围不符、非寻的弹体 |
| 02-player-shoot-integration | resolved | done | 射击生成弹体 |
| 03-projectile-real-damage | resolved | partial | 缺测试、部分 .tres 速度超界 |
| 04-player-projectile-shooting | resolved | done | 弹体射击 |
| 05-enemy-projectile-shooting | resolved | done | 敌人弹体 |
| 06-fix-shoot-global-transform-tree-exit | resolved | done | 离树不再报错+测试 |

### monster-weapons（5）
| 工单 | 声称 | 真实 | 关键发现 |
|---|---|---|---|
| 01-ranged-monster-holds-gun | done | done | 持枪+枪口开火 |
| 02-melee-monster-holds-sword | done | partial | 默认武器与玩家相同 |
| 03-integration-verify | done | done | 联调验证 |
| 04-monster-locomotion-animation | done | done | 动画选择器 |
| 05-monster-death-animation | done | done | 骨骼 die 剪辑 |

### controls-help（2）
| 工单 | 声称 | 真实 | 关键发现 |
|---|---|---|---|
| 01-build-controls-help-overlay | resolved | partial | 分组命名不符、缺暂停接管 |
| 02-integration-test-controls-help | resolved | partial | 未注入 F5、缺门控测试 |

### city-editor（3）
| 工单 | 声称 | 真实 | 关键发现 |
|---|---|---|---|
| 01-city-builder-as-scene-editor | ready-for-human | not-done | 规划文档，集成从未实施 |
| 01-meshlibrary-trimesh-collision | ready-for-agent | partial | 碰撞体已生成，缺运行时验证 |
| 02-pipeline-json-datasource | ready-for-agent | done | JSON 数据源零耦合 |

### hit-feedback（2）
| 工单 | 声称 | 真实 | 关键发现 |
|---|---|---|---|
| 01-hit-flash-module | ready-for-agent | done | 泛红模块+测试 |
| 02-wire-ranged-and-flying | ready-for-agent | partial | monster_ranged 未接 flash |

### melee-slash-vfx（4）
| 工单 | 声称 | 真实 | 关键发现 |
|---|---|---|---|
| 01-melee-vfx-helper | completed | done | 粒子 helper+测试 |
| 02-player-slash-vfx | completed | done | 玩家挥砍 VFX |
| 03-monster-slash-vfx | completed | done | 怪物挥砍 VFX |
| 04-domain-model-and-adr | completed | done | ADR020+CONTEXT 术语同步 |

### minimap（3）
| 工单 | 声称 | 真实 | 关键发现 |
|---|---|---|---|
| 01-setup-topdown-render | resolved | done | SubViewport 俯视渲染+测试 |
| 02-circular-minimap-ui | resolved | done | 圆形 shader 裁切 |
| 03-blip-overlay | resolved | done | 玩家箭头+敌圆点 |

### step-and-monster-nav（5）
| 工单 | 声称 | 真实 | 关键发现 |
|---|---|---|---|
| 01-step-height-constant | resolved | done | STEP_HEIGHT 常量 autoload |
| 02-player-auto-step | resolved | partial | 用 test_move 非验收规定方式、无测试 |
| 03-navmesh-baking | resolved | partial | 缺调试可视化/性能基准/连通性测试 |
| 04-monster-melee-navigationagent | resolved | done | NavAgent 追击（chase_range 数值描述不符） |
| 05-monster-ranged-navigationagent | resolved | done | NavAgent 后退/strafe |

### 独立 issue（2）
| 工单 | 声称 | 真实 | 关键发现 |
|---|---|---|---|
| ads-enemy-spread/issue | （声称全部完成） | done | 散布/ADS 已落地；weapon_toggle 未被移除（仅新增 aim） |
| melee-transitions/issue | ready-for-agent | done | 枪剑过渡+测试+ADR019 同步（状态滞后） |

## 五、系统性建议

1. **状态元数据不可信**：建议以"验收勾选框 + 测试存在"为准重排所有工单状态；当前 `done` 与实际完成度偏差大。
2. **补齐测试覆盖**：28 个 `partial` 中多数缺专项测试（`ammo-hud`、`currency-backpack`、`projectile`、`step-and-monster-nav`、`controls-help` 尤甚）。
3. **激活被注释的配置**：`ENEMY_CONFIG` 在多个工单（16/17/18/27/38）中仅以注释存在，导致敌群/平衡数据不生效。
4. **修正文档与实现偏差**：挣扎键（H vs G）、近战默认武器模型、弹体速度范围、城市商店站被取代等需在工单或代码中统一。
5. **清理失效引用**：`test_shop.gd` 仍在调用已删除的 `add_gold`。
