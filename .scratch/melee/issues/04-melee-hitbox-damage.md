Status: completed
Blocked by: 03

# T4 — Melee Hitbox 命中区与伤害结算

## 构建内容

在 [player.gd](file:///e:/work/sp/Starter-Kit-FPS/objects/player.gd) 与 [player.tscn](file:///e:/work/sp/Starter-Kit-FPS/objects/player.tscn) 中加入**前方 `Area3D` 命中区（Melee Hitbox）**，在挥砍活跃帧开启 monitoring，收集命中怪物并去重结算伤害。

### 1. 场景节点（`player.tscn`）

在 Player 根节点下新增（与 `Collider`/`Head` 平级）：

```
[node name="MeleeHitbox" type="Area3D" parent="."]
monitoring = false
monitorable = false

[node name="HitShape" type="CollisionShape3D" parent="MeleeHitbox"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.5, -1.0)
shape = SubResource("BoxShape3D_melee")
```

其中 `BoxShape3D_melee` 为：

```
[sub_resource type="BoxShape3D" id="BoxShape3D_melee"]
size = Vector3(1.5, 1.5, 2.0)
```

**关键定位：**

- Area3D 挂在 **Player 根节点**下（不是 Camera/Head），故**只跟随玩家 yaw，不跟随相机 pitch**——见 CONTEXT.md「Melee Hitbox Orientation」
- HitShape 中心相对 Player 根：`Vector3(0, 0.5, -1.0)`（前方 1m、腰部高度）
- BoxShape3D 尺寸：`Vector3(1.5, 1.5, 2.0)`（宽×高×深，深度 = `melee_reach`）
- 世界坐标覆盖 y∈[0.25, 1.75]，能罩住 `monster_melee` 的 1.4m 胶囊
- `monitoring = false` 默认关闭，仅活跃帧开启
- `monitorable = false` 不需要被其他 Area3D 监听

### 2. player.gd 引用与状态

```gdscript
@onready var melee_hitbox: Area3D = $MeleeHitbox

# 当前挥砍已结算的敌人集合（每次挥砍重置），用实例 id 去重
var _melee_hit_targets: Dictionary = {}  # key: instance_id, value: true
```

### 3. 在 `action_melee()` 中接入 monitoring 切换

T3 的 `action_melee()` 末尾补充（用 `get_tree().create_timer()` 与 Tween 解耦）：

```gdscript
# 重置本次挥砍已命中集合
_melee_hit_targets.clear()
melee_hitbox.monitoring = false  # 保险：先关再开

# 前摇结束 → 开启 monitoring（活跃帧开始）
get_tree().create_timer(ACTIVE_START).timeout.connect(func():
    if is_inside_tree():
        melee_hitbox.monitoring = true
)
# 后摇开始 → 关闭 monitoring（活跃帧结束）
get_tree().create_timer(ACTIVE_END).timeout.connect(func():
    melee_hitbox.monitoring = false
)
```

### 4. 命中结算（每帧检查 overlapping bodies）

在 `_physics_process(delta)` 中（如已有则末尾追加）：

```gdscript
func _melee_process_hits() -> void:
    if not melee_hitbox or not melee_hitbox.monitoring:
        return
    var bodies := melee_hitbox.get_overlapping_bodies()
    for body in bodies:
        if not is_instance_valid(body):
            continue
        # 用 has_method("damage") 过滤——墙体 StaticBody3D 等无 damage() 自然跳过
        # 见 CONTEXT.md「Melee Hitbox Wall Piercing」
        if not body.has_method("damage"):
            continue
        var id := body.get_instance_id()
        if _melee_hit_targets.has(id):
            continue  # 本次挥砍已结算过，跳过
        _melee_hit_targets[id] = true
        body.damage(melee_damage)  # 自动触发 HitFeedback.flash，见 ADR 005
```

并在 `_process(delta)` 或 `_physics_process(delta)` 中调用：

```gdscript
_melee_process_hits()
```

**注：** 用 `get_overlapping_bodies()` 而非 `body_entered` 信号——因为 monitoring 在活跃帧开启时，已经在盒子内的敌人不会触发 `body_entered`（信号只在进入瞬间触发）。每帧轮询 overlapping 才能可靠捕获。

### 5. 重要约束

- 命中区几何**不**随相机 pitch 倾斜（Q2 决策）
- 用 `has_method("damage")` 过滤命中目标，**不**配置 collision layer/mask（Q5 决策）——墙体 StaticBody3D 无 `damage()` 自然被跳过
- **已知边缘情况**：薄墙后的敌人可能被穿墙砍中（盒子几何上重叠但视线被挡）——v1 接受，未来增强可加 RayCast 视线检查
- 每次挥砍每个敌人**只结算一次**：用 `_melee_hit_targets` 字典按 `instance_id` 去重
- 命中后调用 `body.damage(melee_damage)`——三种怪物的 `damage()` 已接入 `HitFeedback.flash(self)`，命中变色反馈自动生效
- 与现有 `Weapon`/弹体/弹药体系无耦合、无副作用

## 验收标准

- [x] `player.tscn` 新增 `MeleeHitbox` Area3D 节点（挂 Player 根下），`monitoring = false` 默认关闭
- [x] 命中区几何：`BoxShape3D(1.5, 1.5, 2.0)`，中心 `Vector3(0, 0.5, -1.0)`
- [x] 仅在挥砍活跃帧（0.1s–0.3s）开启 `monitoring`，动画其余时间关闭
- [x] 命中目标用 `has_method("damage")` 过滤，墙体等无 `damage()` 的物体被跳过
- [x] 收集到重叠怪物后用 `_melee_hit_targets` 字典按 `instance_id` 去重，单次挥砍对同一敌人只调用一次 `damage(melee_damage)`
- [x] 命中后怪物按 `melee_damage=40` 扣血，并自动触发 Hit Flash 泛红（复用 `HitFeedback.flash`）
- [x] 挥砍未命中任何物体时安静结束，无报错
- [x] 命中区不随相机 pitch 倾斜（看天/看地时命中区保持水平）
- [x] 与现有 `Weapon`/弹体/弹药体系无耦合、无副作用

## 评论

- 命中区朝向（yaw-only，挂 Player 根）来自 grill 会话，见 CONTEXT.md「Melee Hitbox Orientation」
- 穿墙语义（has_method 过滤 + 接受薄墙边缘情况）来自 grill 会话，见 CONTEXT.md「Melee Hitbox Wall Piercing」
- 活跃帧时序（0.1s–0.3s）由 T3 暴露的 `ACTIVE_START`/`ACTIVE_END` 常量驱动
- 用 `get_overlapping_bodies()` 而非 `body_entered` 信号——monitoring 开启时已在盒内的敌人不会触发 enter 信号
- 修复了 ADR 006 中关于"`monster_melee` 的 HitArea 先例"的误导性表述——该节点是死代码，玩家近战才是项目内 Area3D 命中区模式的首个真实用例
