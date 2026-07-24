# ADR 005: 受击反馈逻辑放入独立模块 hit_feedback.gd

## 决策

怪物受击视觉反馈（Hit Flash，命中变色）的逻辑放入**新建的独立静态类脚本** `scripts/hit_feedback.gd`，对外暴露 `HitFeedback.flash(target)` 静态方法，由三种怪物的 `damage()` 调用。**不**放入现有 `combat_utils.gd`，也**不**在各 `damage()` 内联。

## 背景

现有三种怪物的受击反馈极弱且不一致：

- `monster_melee` / `monster_ranged`：`damage()` 仅有一次幅度 ~10%、时长 0.15s 的 `model.scale` 压扁形变 + 音效 `enemy_hurt.ogg`，无变色。
- `enemy`（飞行）：`damage()` 只有音效，无任何视觉反馈，且没有 `Model` 子节点。

玩家反馈"打中没感觉"。决定新增唯一反馈通道 **Hit Flash**：受击瞬间模型材质临时染红、~0.12s 内淡出，统一接入三种怪物（不含击退、不含受击硬直）。

需要为这段逻辑找一个归属位置。`combat_utils.gd` 已存在，定位是"player 与 enemy 共享的战斗计算工具"（目前仅有 `apply_enemy_spread` 这类纯数学函数）。

## 替代方案

| 方案 | 描述 | 否决原因 |
|------|------|----------|
| A. 独立模块 `hit_feedback.gd`（**选中**） | 新建静态类脚本，`HitFeedback.flash(target)` | — |
| B. 放入 `combat_utils.gd` | 在现有共享工具里加 `flash_hit` | `combat_utils` 当前只承载纯计算函数（弹道散布等），混入"遍历网格、改材质"的可视化逻辑会模糊其职责边界；且 Hit Flash 是敌人专属视觉关注点，与"player 共享"的定位不符 |
| C. 各 `damage()` 内联 | 三处各写一份变色逻辑 | 三处重复，后续调色/调参要同步改三处，易漂移 |
| D. autoload 单例 / 挂载组件节点 | 注册全局单例或给每个怪物场景挂 HitFlash 子节点 | 为单一静态方法付出的注册/场景改造成本过重，不如静态类脚本轻量 |

## 影响

- 新增 `scripts/hit_feedback.gd`（及对应 `.uid`）。
- `flash(target)` 需兼容两种模型结构：优先取 `target.get_node_or_null("Model")`，否则回退到 `target` 自身的 `MeshInstance3D`；遍历其下所有 `MeshInstance3D`，对材质做 `.duplicate()`（避免 GLB 共享材质被染红后影响同类怪物）后临时改色，`Tween` 在 ~0.12s 内淡出。
- `monster_melee.gd` / `monster_ranged.gd` / `enemy.gd` 的 `damage()` 各增加一行 `HitFeedback.flash(self)` 调用（现有音效与 melee/ranged 的微弱 scale 形变保留不动）。
- `combat_utils.gd` 保持不变，二者平级、互不依赖。
