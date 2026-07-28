# 05 — B 键背包 UI + T 键整理动画

Status: done
Type: task
Refs: PRD.md, ADR 023, CONTEXT.md「B Key / T Key / Backpack」

## 实现记录

- 新建 `scripts/backpack_ui.gd`：全屏背包 UI（`PROCESS_MODE_WHEN_PAUSED`），左侧物品列表按类型分组，右侧 10 备弹槽
- 点击分配流程：选背包弹药行 → 点目标备弹槽 → 从背包取 `capacity` 发子弹分配
- 目标槽已有不同弹种先清空退回背包；同弹种追加 `remaining`
- 关闭 UI → `_is_packing = true`，1.5s 整理动画（禁射击/换弹/背包，允许移动跳跃）
- `project.godot` 新增 `backpack` 输入动作（B 键，toggle 打开/关闭）+ `organize` 输入动作（T 键，整理并关闭）
- `player.gd`: `action_backpack()`、`_is_packing` 检查入 `action_shoot()` / `action_reload()`
- `hud.gd`: 托管创建背包 UI + 整理中"整理中…"提示
- 注：未创建 `scenes/backpack_ui.tscn`，改用 GDScript `script.new()` 实例化（区别于 `weapon_inspect_ui.tscn` 的 `.tscn` 加载模式）；与 `controls_help_ui.gd` 同模式。根 `Control` 必须在 `_ready()` 调用 `set_anchors_preset(Control.PRESET_FULL_RECT)`（见下文"背包 UI 场景"小节）

## 描述

实现 B 键触发的全屏背包管理界面（T 键作为"整理并关闭"语义快捷键）。左侧展示背包物品（按类型分组，含重量信息），右侧展示 10 个备弹槽。物品可拖拽或点击分配到备弹槽。关闭 UI 后进入 1.5s 整理动画（可移动不可射击）。

## 验收标准

### B/T 键输入

- `project.godot` 新增 `backpack` 输入动作（B 键，toggle 打开/关闭背包 UI）+ `organize` 输入动作（T 键，整理并关闭）
- `player.gd` `_unhandled_input` 处理 `backpack` 动作：打开背包 UI（关闭由 UI 自身处理）
- `backpack_ui.gd` `_unhandled_input` 处理 `backpack`/`organize`/`mouse_capture_exit` 三种关闭路径
- 暂停时（商店/升级/死亡）不可打开背包

### 背包 UI 场景

新建 `scripts/backpack_ui.gd`（无 `.tscn`，HUD 用 `script.new()` 实例化）：
- 继承 `Control`，`process_mode = PROCESS_MODE_WHEN_PAUSED`
- 根 Control 必须在 `_ready()` 中调用 `set_anchors_preset(Control.PRESET_FULL_RECT)` 铺满父节点（HUD），否则子节点（`_bg` 0..1 / `_panel` 0.15..0.85）的相对锚点会基于 0×0 父矩形计算，导致整个 UI 挤在屏幕左上角
- 加入 group `"backpack_ui"`

### 左侧：背包物品列表

- 按类型分组显示：弹药、枪械、血包
- 每行显示：物品名称 / 数量 / 总重量 / 单件重量
- 弹药按弹种再细分（手枪弹、步枪弹等），显示按"发"计数的原始数量
- 枪械显示 display_name + 重量
- 可点击选中一行（高亮）

### 右侧：10 个备弹槽

- 每个槽显示：槽位编号、当前分配的弹药类型图标/名称、`remaining/capacity`（如 "3/4" 表示还能换 3 次弹匣，总共 4 次）
- 空槽显示"空"
- 可点击选中一个槽（高亮）

### 分配操作

- 流程：点击背包中的弹药行 → 点击目标备弹槽 → 转移
- 转移逻辑：从背包中取出 `capacity` 发子弹 → 设到备弹槽中 `remaining = 1`（一弹匣量）
  - 若背包子弹不足 `capacity` 发：全部取出，按比例设置 `remaining`（向下取整）
  - 若目标槽已有不同弹种：先清空（子弹退回背包），再分配
  - 若目标槽同弹种：追加 `remaining`
- 备弹槽的 `remaining` 上限由对应弹种的 `magazine_size` 决定（一槽最多装一个弹匣量）

### 整理动画

- 关闭 UI 后，`player._is_packing = true`
- 1.5s 后 `_is_packing = false`
- 整理期间：禁止射击、禁止换弹、禁止再次打开背包；允许移动和跳跃
- HUD 可选显示"整理中…"提示

### 输入

- B 键 toggle 打开/关闭背包 UI（关闭路径同样启动整理动画）
- T 键在背包 UI 打开时触发"整理并关闭"（与 B/ESC 关闭等价的快捷键，语义是"整理物资"）
- ESC 关闭背包 UI（先关 UI 再进入整理动画）
- `_unhandled_input` 仅在 UI 打开时处理关闭路径（打开由 player.gd 处理）

### HUD 托管

- 背包 UI 由 HUD（`hud.gd`）托管创建，参照 `level_up.gd` / `chest_ui.gd` 模式
- 玩家按下 B 键时 HUD 负责显示背包 UI；关闭路径（B/T/ESC/关闭按钮）由 UI 自身处理
