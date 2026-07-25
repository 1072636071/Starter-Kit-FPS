# 25 — 武器检视 UI 验证

Status: ready-for-agent
Type: task
Refs: ADR 022, issues 19/20/21

## 描述

武器检视 UI 代码已在本会话中实现（`scripts/weapon_inspect_ui.gd` + `scenes/weapon_inspect_ui.tscn` + `scripts/hud.gd` 集成）。本工单为**验证 + 适配**：确认与 issue 19–21 的兼容性，补测试。

## 前置依赖

- [ ] issue 19（`.tres` 文件存在，含全部身份字段）
- [ ] issue 20（耐久度系统，`weapon_durability` 数组存在）
- [ ] issue 21（弹药池重构，`ammo_reserve` 字典 + 丢弃拾取）

## 验收标准

### 适配验证

- [ ] 确认 `weapon_inspect_ui.gd::_build_filled_card` 中弹药状态读数改用 `ammo_reserve`（若 issue 21 已移除旧 `reserve` 数组）
- [ ] 确认 TAB 键在 issue 21 新增 `drop_weapon`（X 键）后不冲突
- [ ] 确认 `.tres` 全部身份字段正确显示（`ammo_type` / `weapon_cost` / `durability_max` / `role_title` / `reliability_stars`）
- [ ] 确认 `refresh_ammo()` 在弹药池模式下正常工作

### 交互验证

- [ ] TAB 打开 → 三张卡片完整显示（有枪的槽）或显示"（空槽）"
- [ ] 当前装备武器金边正确
- [ ] 点击卡片固定为对比参考 → 其余卡片显示 ▲▼ 差异
- [ ] 再次点击固定卡片 → 取消对比
- [ ] ESC 关闭 → 鼠标恢复捕获
- [ ] 商店/升级/死亡 UI 打开时 → 武器检视自动关闭
- [ ] 武器切换（Q / 滚轮）→ 检视 UI 中边框和"当前装备"标记同步更新
- [ ] 开火 → 弹药数字实时刷新
- [ ] 耐久归零爆枪 → 卡片消失（空槽显示）

### 边界情况

- [ ] 3 槽全空 → 三张"（空槽）"卡片，空槽不可点击对比
- [ ] 1 把枪时 → 1 张填充 + 2 张空槽
- [ ] 同枪 3 把 → 每张卡片显示相同属性，对比模式正常运作

### 测试

- [ ] `tests/test_weapon_inspect_ui.gd`：
  - 构造 mock player（3 把不同枪）→ `open()` → 断言卡片数 3、标签正确
  - 点击第 2 张 → 断言 `_pinned_index == 1`、边框变为蓝色
  - 断言第 1/3 张卡片 DPS 标签含 ▲ 或 ▼
  - `close()` → 断言 `visible == false`
  - `get_tree().paused = true` → 断言 UI 自动 close
