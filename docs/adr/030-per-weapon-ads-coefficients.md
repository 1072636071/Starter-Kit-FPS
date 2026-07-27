# ADR 030：按武器差异化的右键 ADS 系数

- **日期**：2026-07-27
- **状态**：✅ 已采纳
- **决策者**：Grill with Docs 会话
- **取代**：ADR 003 中"FOV 75→60、spread×0.5、speed×0.7 全武器统一"部分（ADR 003 的输入映射变更与敌人散布部分仍有效）

## 上下文

ADR 003 为统一入门体验，将 ADS 三参数（FOV 缩放、散布系数、移速系数）硬编码在 `player.gd` 中：
- `AIM_FOV := 60.0`（默认 75° → 60°，视觉变焦 1.25×）
- `ADS_SPREAD_FACTOR := 0.5`（散布减半）
- `ADS_SPEED_FACTOR := 0.7`（移速×0.7）

15 把武器（ADR 022 武器扩展）共用这套系数，导致：

1. **狙击步枪缺乏"开镜"震撼感**——重型狙击 ADS 仅 1.25×（fov 60°），无法发挥远程精确射击的战术价值
2. **霰弹枪 ADS 价值虚高**——近战武器 ADS 后散布仍减半（12.0→6.0），与"近战泼水"定位冲突，且 1.25× zoom 对近战无意义
3. **武器辨识度扁平**——所有武器右键手感一致，无法通过 ADS 差异化武器个性
4. **配置不可调**——系数在 `player.gd` 硬编码，调参需改代码而非资源

## 决策

### 1. 在 `Weapon` 资源新增 4 个 ADS 字段（subgroup `"ADS"`）

```gdscript
@export_subgroup("ADS")
@export var ads_zoom_factor: float = 1.25       # 视觉放大倍率，DEFAULT_FOV / 此值 = ADS fov
@export var ads_fov_override: float = 0.0       # >0 时优先使用此 fov 度数（狙击类用绝对值更精确）
@export var ads_spread_factor: float = 0.5      # ADS 时散布乘以 this
@export var ads_speed_factor: float = 0.7       # ADS 时移速乘以 this
```

**默认值对齐 ADR 003 现状**（1.25 / 0.0 / 0.5 / 0.7），保证旧 `.tres` 资源未配置时行为不变（向后兼容）。

### 2. 混合语义：zoom_factor + fov_override 共存

`player.gd` 计算 ADS fov 的逻辑：

```gdscript
var ads_fov: float = weapon.ads_fov_override if weapon.ads_fov_override > 0.0 else DEFAULT_FOV / weapon.ads_zoom_factor
```

- **普通武器**配 `ads_zoom_factor`（语义直观："放大 1.5 倍"）
- **精确狙击类**配 `ads_fov_override`（绝对度数更精确："开镜到 18°"）
- 两字段互斥：`ads_fov_override > 0` 时 zoom_factor 被忽略

### 3. 三系数全部按武器差异化

不再有"全武器统一"的 ADS 系数。每把武器的（zoom/fov、spread、speed）三元组独立配置，体现武器个性。

### 4. 15 把武器系数表

| 武器 | ammo_type | spread | role | zoom_factor | fov_override | spread_factor | speed_factor | 实际 ADS fov |
|------|-----------|--------|------|-------------|--------------|---------------|--------------|--------------|
| 手托手枪-小口径 | 手枪弹 | 1.5 | 入门可靠型 | 1.3 | 0 | 0.6 | 0.8 | 57.7° |
| 微型冲锋枪 | 手枪弹 | 3.5 | 近战泼水型 | 1.2 | 0 | 0.7 | 0.85 | 62.5° |
| 微型冲锋枪-双枪口 | 手枪弹 | 4.0 | 双管泼水型 | 1.2 | 0 | 0.75 | 0.85 | 62.5° |
| 短突击步枪-双枪口 | 步枪弹 | 2.5 | 双管突击型 | 1.5 | 0 | 0.5 | 0.75 | 50° |
| 机枪 | 步枪弹 | 4.0 | 重火力压制型 | 1.4 | 0 | 0.65 | 0.7 | 53.6° |
| 4管霰弹枪 | 霰弹 | 12.0 | 毁灭近战型 | 1.1 | 0 | 0.85 | 0.85 | 68.2° |
| 半自动霰弹枪 | 霰弹 | 10.0 | 近战连喷型 | 1.15 | 0 | 0.8 | 0.85 | 65.2° |
| 狙击步枪 | 狙击弹 | 0.3 | 精准远射型 | 1.25（fallback） | 30.0 | 0.2 | 0.4 | 30° |
| 狙击步枪-重型 | 狙击弹 | 0.2 | 终极远射型 | 1.25（fallback） | 18.0 | 0.1 | 0.35 | 18° |
| blaster | 能量电池 | 1.0 | 能量爆能型 | 1.4 | 0 | 0.5 | 0.7 | 53.6° |
| blaster-repeater | 能量电池 | 0.5 | 连发压制型 | 1.5 | 0 | 0.5 | 0.7 | 50° |
| 双管能量枪 | 能量电池 | 2.0 | 能量双发型 | 1.4 | 0 | 0.55 | 0.75 | 53.6° |
| 上下双枪口能量枪 | 能量电池 | 2.5 | 能量纵列型 | 1.4 | 0 | 0.55 | 0.75 | 53.6° |
| 持续射线枪 | 能量电池 | 0.5 | 光束持续型 | 1.6 | 0 | 0.4 | 0.7 | 46.9° |
| 短柄榴弹发射器 | 榴弹 | 3.0 | AOE爆破型 | 1.3 | 0 | 0.7 | 0.75 | 57.7° |

### 5. 设计原则

- **远射高精度武器**（狙击）：大 zoom + 小 spread_factor（精度极大提升）+ 小 speed_factor（更慢更稳）
- **近战泼水武器**（霰弹/冲锋）：小 zoom + 大 spread_factor（ADS 仍保留较多散布）+ 大 speed_factor（保留机动）
- **中距离突击武器**（步枪/能量）：中 zoom + 中系数
- **AOE 武器**（榴弹）：中 zoom（看落点）+ 大 spread_factor（不需精度）+ 中 speed_factor
- **光束武器**（持续射线枪）：中大 zoom（持续命中需对准）+ 小 spread_factor + 中 speed_factor
- **狙击类用 fov_override 绝对值**：30° 对标 Valorant Operator、18° 对标 CS 重狙开镜，比 zoom_factor 倍率更精确

## 否决的替代方案

### 方案 A：单一 zoom_factor 字段（无 override）

否决原因：狙击镜 4.0× 倍率换算 fov=18.75°，但设计师直觉是"开镜到 18°"而非"放大 4 倍"。绝对度数配置更贴近狙击武器的设计语言。两字段共存成本极低（一个 if 判断），但配置心智显著降低。

### 方案 B：仅差异化 FOV，spread/speed 仍统一

否决原因：用户在 grill 会话明确选择"spread 与 speed 全部按武器差异化"。若霰弹 ADS 仍 spread×0.5，12.0 散布降到 6.0 仍过紧，与近战定位冲突；若狙击 ADS 仍 speed×0.7，开镜时仍能较快移动，破坏"狙击镜稳重"语义。

### 方案 C：硬编码按 ammo_type 分组的系数表

否决原因：同弹种武器角色差异大（如手枪弹的"手托手枪"与"微型冲锋枪"zoom 应不同；能量电池的"blaster"与"持续射线枪"语义完全不同）。硬编码失去 `.tres` 配置灵活性，违背 ADR 022 数据驱动原则。

### 方案 D：保留 AIM_FOV=60 全局兜底常量

否决原因：保留会引入"字段未配置时用 60°、配置时用字段值"的双轨逻辑，测试与文档复杂度上升。`ads_zoom_factor` 默认 1.25 已等价 60°（75/1.25=60），单轨字段+默认值即可覆盖。

## 影响范围

### 代码变更
- `scripts/weapon.gd` — 新增 `@export_subgroup("ADS")` + 4 个 `@export` 字段
- `objects/player.gd` — 移除 `AIM_FOV` / `ADS_SPREAD_FACTOR` / `ADS_SPEED_FACTOR` 三常量，改为读 `weapon.ads_*` 字段
  - FOV 计算：`ads_fov_override > 0 ? override : DEFAULT_FOV / ads_zoom_factor`
  - 散布计算：`weapon.spread * weapon.ads_spread_factor`（替换 `* ADS_SPREAD_FACTOR`）
  - 移速计算：`speed_multiplier = weapon.ads_speed_factor if is_aiming else 1.0`

### 资源变更
- `weapons/*.tres`（15 个文件）— 每个追加 4 个 ADS 字段值

### 文档变更
- `CONTEXT.md` — 在"后坐力与精度"章节更新 ADS 术语定义，新增 4 个字段术语
- `docs/adr/003a-ads-and-enemy-spread.md` — 顶部追加“部分被 ADR 030 取代”标注

### 测试
- 新增 `tests/test_per_weapon_ads.gd` — 断言每把武器的 4 个 ADS 字段在合理范围、fov 计算正确、ADS 行为差异化

## 验收标准

- [ ] 15 把武器 `.tres` 均含 4 个 ADS 字段
- [ ] `player.gd` 无 `AIM_FOV` / `ADS_SPREAD_FACTOR` / `ADS_SPEED_FACTOR` 常量
- [ ] 狙击步枪-重型 ADS 时 fov=18°、散布×0.1、移速×0.35
- [ ] 4管霰弹枪 ADS 时 fov≈68°、散布×0.85、移速×0.85
- [ ] 旧 `.tres`（未配 ADS 字段）加载后行为不变（默认值 = ADR 003 现状）
- [ ] 回归测试通过
