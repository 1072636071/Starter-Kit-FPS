# 02 — 动态 procedural 准星

Status: needs-triage
Type: task
Refs: PRD.md, CONTEXT.md「Crosshair」

## 描述

当前准星是纯静态 `TextureRect`（显示 Weapon 资源的 `.crosshair` 纹理）。替换为 procedural 四线准星，根据玩家移动速度、射击状态、后坐力累积动态扩张/收缩。

## 验收标准

- 新增 `scripts/dynamic_crosshair.gd`（`extends Control`）：
  - 用 `draw_line()` 绘制四条线：上、下、左、右，中心留空
  - `@export` 参数：`base_gap: float = 6.0`（最小间距），`max_gap: float = 40.0`（最大间距），`line_length: float = 12.0`，`line_thickness: float = 2.0`，`color: Color = Color.WHITE`
  - `current_gap: float` 运行时动态值，每帧 lerp 到 target_gap
  - 提供 `set_spread_factor(f: float)` 接口：0.0 = 完全收缩（ADS），1.0 = 最大扩张
  - 提供 `get_gap() -> float` 公开方法供测试读取当前 gap 值
- HUD 中新增 `DynamicCrosshair` 实例替换原有 `crosshair` TextureRect：
  - 默认隐藏静态跨线，显示动态跨线
  - v1 决策：完全忽略 `Weapon.crosshair` 纹理，统一使用四线准星（颜色/线长从 `DynamicCrosshair` 自身 `@export` 参数读取，默认白色）
- `_process()` 中根据以下输入计算 target_gap：
  - **移动速度**：`velocity.length() / movement_speed` 映射到 0.0–0.6 扩张因子
  - **射击中**：每发 +0.15 扩张，停止射击后缓慢恢复
  - **后坐力累积**：`_recoil_offset.length()` 映射到 0.0–0.4 额外扩张
  - **跳跃/空中**：直接 max（1.0）
  - **ADS**：强制因子 0.0（完全收缩，动态跨线隐藏 → 显示 ADS 专用小点）
- player.gd 中 `@export var crosshair` 类型从 `TextureRect` 改为 `Control`（兼容 `DynamicCrosshair`）：
  - 现有 3 处 `crosshair.texture = weapon.crosshair` / `crosshair.texture = null` 调用（第 943、1036、1114 行）改为带类型判断的防御写法：`if crosshair is TextureRect: crosshair.texture = ...`（v1 DynamicCrosshair 忽略纹理准星）
  - 每帧更新 `crosshair.set_spread_factor()`（从 player._process 传入）——如果 crosshair 没有 `set_spread_factor` 方法则跳过（`has_method` 防御）
- 过渡速度参数化：`crosshair_expand_speed = 12.0`（扩张快），`crosshair_contract_speed = 6.0`（收缩慢 — 更有重量感）

## 技术要点

- 独立 Control 节点，`draw_line()` 绘制，零额外纹理资源
- 因子计算在 player.gd 中完成，crosshair 只负责渲染
- ADS 时可选显示静态小圆点替代四线

## 评论

（无）
