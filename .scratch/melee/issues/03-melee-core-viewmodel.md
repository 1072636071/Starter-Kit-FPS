Status: ready-for-agent
Blocked by: 01, 02

# T3 — 近战核心逻辑 + 视图模型挥砍动画

## 构建内容

在 [player.gd](file:///e:/work/sp/Starter-Kit-FPS/objects/player.gd) 中加入近战系统。本工单只管**视觉与冷却**——命中检测由 T4 处理。

### 1. `@export` 调参与引用

```gdscript
@export_subgroup("Melee")
@export var melee_damage: float = 40.0
@export var melee_cooldown: float = 0.5
@export var melee_viewmodel: PackedScene   # 引用 T1 产出的 objects/melee_viewmodel.tscn
```

### 2. 内部状态

```gdscript
# 近战状态
var melee_viewmodel_instance: Node3D
var melee_cooldown_remaining: float = 0.0
var melee_swing_tween: Tween
const SWING_DURATION := 0.4          # 总挥砍时长，必须 ≤ melee_cooldown
const ACTIVE_START := 0.1            # monitoring 开启时机（前摇结束）
const ACTIVE_END := 0.3              # monitoring 关闭时机（后摇开始）
```

### 3. 视图模型生命周期（实例化一次、复用）

在 `_ready()` 末尾（现有逻辑之后）：

```gdscript
# 近战视图模型：实例化一次，挂 CameraItem 下（与 Container 平级，不在 Container 内
# 否则会被 change_weapon() 的 remove_child() 清掉）。初始隐藏。
if melee_viewmodel:
    melee_viewmodel_instance = melee_viewmodel.instantiate()
    camera_item.add_child(melee_viewmodel_instance)   # camera_item = $Head/Camera/SubViewportContainer/SubViewport/CameraItem
    melee_viewmodel_instance.visible = false
    # 设置 layer 2，与 change_weapon() 中枪械模型一致
    for child in melee_viewmodel_instance.find_children("*", "MeshInstance3D"):
        child.layers = 2
```

**注意：** 需新增 `@onready var camera_item = $Head/Camera/SubViewportContainer/SubViewport/CameraItem`（当前 player.gd 未引用此节点，只引用了其下的 `Container`）。

### 4. 冷却推进

在 `_process(delta)` 中（与 `_step_reload(delta)` 同位置）：

```gdscript
if melee_cooldown_remaining > 0.0:
    melee_cooldown_remaining = maxf(0.0, melee_cooldown_remaining - delta)
```

### 5. 触发挥砍

在 `handle_controls(delta)` 末尾（与其他 action_* 同模式）：

```gdscript
if Input.is_action_just_pressed("melee"):
    action_melee()
```

```gdscript
func action_melee() -> void:
    # 冷却中：拒绝触发（不查 is_reloading——近战与换弹互不阻塞，见 ADR 006）
    if melee_cooldown_remaining > 0.0:
        return
    if melee_viewmodel_instance == null:
        return

    melee_cooldown_remaining = melee_cooldown

    # 显示 viewmodel
    melee_viewmodel_instance.visible = true

    # 杀掉旧 Tween（防连续挥砍叠加）
    if melee_swing_tween and melee_swing_tween.is_valid():
        melee_swing_tween.kill()

    # 下劈动画：剑从右上→左下，分三段对应前摇/活跃帧/后摇
    # 锚点起始位置由 melee_viewmodel.tscn 预设；此处用相对偏移做 Tween
    var tween := get_tree().create_tween()
    melee_swing_tween = tween

    # 前摇 0.1s：从锚点举到右上（蓄力）
    tween.tween_property(melee_viewmodel_instance, "rotation_degrees",
        melee_viewmodel_instance.rotation_degrees + Vector3(-60, 30, 60), 0.1)
    # 活跃帧 0.2s：从右上划到左下
    tween.tween_property(melee_viewmodel_instance, "rotation_degrees",
        melee_viewmodel_instance.rotation_degrees + Vector3(120, -60, -120), 0.2)
    # 后摇 0.1s：复位
    tween.tween_property(melee_viewmodel_instance, "rotation_degrees",
        melee_viewmodel_instance.rotation_degrees, 0.1)
    # 收尾：隐藏
    tween.tween_callback(func(): melee_viewmodel_instance.visible = false)

    # 命中区 monitoring 由 T4 接入：在 ACTIVE_START 开启、ACTIVE_END 关闭
    # 这里用 tween_callback 暴露时机给 T4（T4 会在此处补 monitoring 切换）
    # T4 实现时直接在本函数内插入：
    #   tween.tween_callback(_melee_enable_hitbox).set_delay(ACTIVE_START)  # 但 Tween 是顺序执行，需用 parallel 或自定义时间点
    # 推荐做法：用 get_tree().create_timer() 链式触发 monitoring 切换，与 Tween 解耦
```

**实现提示：** monitoring 切换建议用 `get_tree().create_timer(ACTIVE_START).timeout.connect(...)` 而非 Tween callback，避免与 Tween 顺序执行耦合。T4 会补充具体实现。

### 6. 重要约束

- **不**改动 `Weapon` 资源、`action_shoot()`、弹药/换弹逻辑
- **不**改动 `container` 内枪械模型的位置/可见性（与远程武器互不干扰）
- **不**查 `is_reloading`——近战与换弹互不阻塞（见 ADR 006 后续决策）
- **不**新增 Timer 节点到 `player.tscn`——冷却用浮点累加器
- **音效跳过**：`sounds/` 下无合适挥砍素材，v1 不做（见 ADR 006 后续决策）

## 验收标准

- [ ] `player.gd` 新增 `@export var melee_damage = 40`、`@export var melee_cooldown = 0.5`、`@export var melee_viewmodel: PackedScene`
- [ ] 新增 `@onready var camera_item`，`_ready()` 中实例化 `melee_viewmodel` 一次并挂 `CameraItem` 下，初始 `visible = false`，所有 mesh `layers = 2`
- [ ] 新增 `melee_cooldown_remaining` 浮点累加器，在 `_process(delta)` 递减
- [ ] 按 V（`melee` 动作）触发 `action_melee()`：显示 viewmodel → Tween 下劈（前摇 0.1s 举右上 → 活跃帧 0.2s 划左下 → 后摇 0.1s 复位）→ 隐藏
- [ ] 冷却中（0.5s 内）重复按 V 不重复触发，冷却结束方可再次挥砍
- [ ] 挥砍动画**不**改动 `container` 内枪械模型的位置/可见性
- [ ] **不**修改 `Weapon` 资源、`action_shoot()`、弹药/换弹逻辑
- [ ] 换弹中按 V 可正常触发挥砍（近战-换弹互不阻塞）
- [ ] 挥砍中按 R 可正常触发换弹
- [ ] 不新增 Timer 节点到 `player.tscn`

## 评论

- 挥砍时序 0.4s / 0.1s / 0.3s 来自 grill 会话，见 CONTEXT.md「Swing Duration」「Active Frames」
- 下劈动画样式来自 grill 会话，见 CONTEXT.md「Swing Animation Style」
- Viewmodel 生命周期（实例化一次）来自 grill 会话，见 CONTEXT.md「Melee Viewmodel Lifecycle」
- 近战-换弹并发（互不阻塞）来自 grill 会话，见 CONTEXT.md「Melee-Reload Independence」
- 冷却实现（浮点累加器）来自 grill 会话，见 CONTEXT.md「Melee Cooldown Implementation」
- 音效跳过来自 grill 会话，见 CONTEXT.md「Melee Swing Sound」
- 命中区 monitoring 的具体切换逻辑由 T4 补充——本工单只暴露时序常量（`ACTIVE_START`/`ACTIVE_END`）
