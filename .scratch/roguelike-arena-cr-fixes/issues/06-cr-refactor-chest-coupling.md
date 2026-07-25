# 06 — chest_ui.gd 解耦（特性嫉妒 + 去重逻辑评估）

**Status:** done

**Blocked by:** 无——可立即开始

**构建内容：** 重构 `chest_ui.gd` 中 `_on_chest_weapon_replace_offered()` 对 player/run_director 的过度钻取，将逻辑下沉到职责归属方。同时审慎评估宝箱去重逻辑的取舍。

**验收标准：**

### 特性嫉妒修复

- [ ] `chest_ui.gd::_on_chest_weapon_replace_offered()` 不再直接访问 `player.weapons[i]`、`player.weapons.size()` 逐字段钻取
- [ ] 替代方案：run_director 提供封装方法返回"当前各槽武器名列表"（`Array[String]`），chest_ui 只负责渲染
- [ ] 替换确认/取消回调仍由 chest_ui 触发，但参数从 slot_idx 简化为 chest_ui 只需传回选择结果
- [ ] 重构后宝箱满槽替换对话框行为不变

### 审慎决策：宝箱去重逻辑

- [ ] **推荐保留**。当前已实现且 spec 标注为"可选优化"，提前做掉避免了未来重构
- [ ] 但需标记为有意为之的范围蔓延（非 bug），在代码注释中注明"issue 24 spec 可选优化，提前实现"
- [ ] 若决定移除，删除 `run_director.gd::_apply_random_weapon_reward()` 中 `owned_resources` 过滤逻辑

## 评论

（评论与对话历史追加于此，新内容置于最前。）
