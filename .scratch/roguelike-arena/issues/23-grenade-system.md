# 23 — 手雷投掷系统（G 键 + EMP + 破片）

Status: ready-for-agent
Type: task
Refs: ADR 022, issues 09

## 描述

实现手雷投掷机制：G 键蓄力瞄准 → 释放投掷 → 落地引爆。两种手雷：EMP（减速+沉默）和破片（AOE 伤害）。

## 前置依赖

- [x] issue 09（`Player.grenades` 字典 + `max_grenades` + `throw_grenade` 输入动作 + `grenade_switch` 滚轮切换）

## 验收标准

### 投掷机制

- [ ] `player.gd` 新增手雷投掷状态机：
  - 按 G（`throw_grenade`）开始蓄力 → 显示抛物线预览（`LineRenderer` 或 `MeshInstance3D` 点线，白色）
  - 释放 G → 投掷当前选中手雷类型，`grenades[type] -= 1`
  - 按住 G + 滚轮/caps → 切换手雷类型（EMP ↔ 破片），HUD 提示当前选中类型
  - 投掷后 HUD 更新手雷数量
- [ ] 新建 `scenes/grenade_projectile.tscn` + `scripts/grenade_projectile.gd`：
  - `RigidBody3D` 抛物线飞行（初速度 + 重力）
  - 落地后 `body_entered` 触发引爆
  - 子类化：`grenade_emp.tscn` / `grenade_frag.tscn`

### EMP 手雷

- [ ] 落地后 `yield(get_tree().create_timer(0.5), "timeout")` → 引爆
- [ ] `radius = 6.0m`（`Area3D` 一次性检测范围内所有怪物）
- [ ] 效果持续 3s：移速 ×0.3 + 禁用 ATTACK 状态（模块在怪物 FSM 中拦截）
- [ ] 视觉：蓝色球形粒子扩张 + 收缩
- [ ] HUD 提示被 EMP 影响的敌人数量

### 破片手雷

- [ ] 落地后 `yield(get_tree().create_timer(0.8), "timeout")` → 引爆
- [ ] `radius = 5.0m`，`damage = 40`，抛物线衰减（中心 40 → 边缘 10）
- [ ] 视觉：橙红色球形粒子爆炸

### HUD 显示

- [ ] `scripts/hud.gd` 新增手雷槽显示（图标 + 数量），位于弹药列表旁边
- [ ] 切换手雷类型时图标高亮/边框变化

### 测试

- [ ] `tests/test_grenade_throw.gd`：
  - 手雷抛物线飞行 → 断言落地距离在预期范围内
  - 投掷后 → 断言 `grenades[type]` 减 1
- [ ] `tests/test_grenade_emp.gd`：
  - 在怪物 5m 处引爆 EMP → 断言怪物移速变为 0.3 倍，3s 后恢复
  - 断言 ATTACK 状态被禁用 3s
- [ ] `tests/test_grenade_frag.gd`：
  - 在怪物 3m 处引爆破片 → 断言伤害 ≈ 40（中心）
  - 在怪物 5m 边缘 → 断言伤害 ≈ 10
