# 07 — 修复 Issue 26 集成烟雾测试

Status: done
Type: task
Refs: issue 26, ADR 022
Blocked by: none

## 根因分析

Issue 26 标记为 `done`，但实际存在以下缺口：

### 缺口 1：test_smoke_waves.gd 编译错误（致命）

**文件**: `tests/test_smoke_waves.gd:39-41`

```gdscript
for wave_num in expected_budgets:         # wave_num 类型为 Variant
    var actual := rd.wave_budget(wave_num)
    var expected := expected_budgets[wave_num]  # ❌ Cannot infer type
```

**原因**: Godot 4 GDScript 对无类型标注的 Dictionary 迭代，`wave_num` 被推断为 Variant。`var expected :=` 无法从 `Dictionary[Variant]` 推断目标类型。

**修复**: `for wave_num: int in expected_budgets:` — 显式标注迭代变量类型。

### 缺口 2：交互烟雾测试未编写

Issue 26 验收标准第三条要求验证 TAB/商店/宝箱/G/X 五种交互不崩溃，但 `tests/` 下无对应测试脚本。

## 前置依赖

- [x] 无 — 测试脚本修复不需要等待 16-19

## 验收标准

### 修复 test_smoke_waves.gd 编译

- [ ] `for wave_num: int in expected_budgets:` 类型标注修复
- [ ] 运行 `godot --headless --path . res://tests/test_smoke_waves.tscn --quit-after 60` 通过
- [ ] 运行日志保存到 `.scratch/test_smoke_waves_run.log`

### 补跑 test_smoke_weapons.gd

- [ ] 运行 `godot --headless --path . res://tests/test_smoke_weapons.tscn --quit-after 30` 
- [ ] 确认 2 把现有武器 (.tres) 字段验证通过
- [ ] 运行日志保存到 `.scratch/test_smoke_weapons_run.log`

### 新增交互烟雾测试

- [ ] 创建 `tests/test_smoke_interactive.gd` + `.tscn`
- [ ] 覆盖验收项：
  - TAB 武器检视打开 → 三卡正常显示 → ESC 关闭
  - 商店打开 → 三区加载 → 购买武器/弹药/手雷
  - 宝箱打开 → 随机武器/手雷补给发放
  - G 投手雷 → 蓄力 → 投掷 → 引爆
  - X 丢枪 → pickup 生成 → 拾取
- [ ] 运行通过，日志保存到 `.scratch/test_smoke_interactive_run.log`

### 测试

- [ ] `tests/test_smoke_waves.gd` — 修复编译 + 通过
- [ ] `tests/test_smoke_weapons.gd` — 补跑 + 通过
- [ ] `tests/test_smoke_interactive.gd` — 新建 + 通过

## 评论

（暂无）
