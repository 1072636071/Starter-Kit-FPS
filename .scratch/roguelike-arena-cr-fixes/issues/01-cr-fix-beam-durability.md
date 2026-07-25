# 01 — 能量武器耐久扣减修复

**Status:** done

**Blocked by:** 无——可立即开始

**构建内容：** 能量武器（`weapon_mode == "beam"`）开火时按 `tick_interval` 扣耐久，归零后正常触发爆枪。当前 beam 武器在 `_fire_bullet()` 末尾扣减耐久，但持续射线不走该路径——导致能量武器永不爆枪，破坏耐久度系统的经济平衡。

**验收标准：**

- [ ] `player.gd` 的 `_process` 或 beam 开火逻辑中，按 `tick_interval`（如 1s）递减 `weapon_durability[current_index]`
- [ ] 耐久归零时触发与普通武器相同的爆枪流程（粒子特效 → 从数组移除 → 自动切下一把 → 全空则空手）
- [ ] 空手时不触发扣减
- [ ] 爆枪后 beam 持续效果立即终止（不残留隐形射线）

## 评论

（评论与对话历史追加于此，新内容置于最前。）
