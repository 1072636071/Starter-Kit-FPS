# 怪物模型动画介绍（Monster Model Animations）

> 本文件介绍 `models/monsters/` 下人形怪物模型（`monster-ranged.glb` 与 `monster-melee.glb`）自带的动画资源。
> 数据由直接解析 GLB 的 glTF JSON 块与动画时间轨道得到（两个模型动画集与时长**完全一致**）。
> 相关特性设计见 [`docs/adr/008-monster-weapons-and-animations.md`](../../docs/adr/008-monster-weapons-and-animations.md) 与 `CONTEXT.md`「怪物武器与动画」。

## 1. 模型与绑定方式

- 两个怪物 GLB 都是**完整绑定的人形模型**，自带 **29 条命名动画**，不是静态网格。
- 导入配置 `models/monsters/monster-*.glb.import` 中 `animation/import = true`，因此导入后 GLB 实例内**自带 `AnimationPlayer`** 与全部动画剪辑。
- `import_as_skeleton_bones = false` **仅表示骨骼不暴露成可编辑的 `BoneAttachment` 节点**，不等于"无骨骼 / 无动画"。武器仍可通过运行时把网格挂为 `arm-right` 等节点的子节点来绑定。
- 该模型是**节点式刚体绑定**（glTF `skins` 为空，无顶点蒙皮）：每条肢体是独立网格，动画直接驱动这些节点变换旋转肢体。

## 2. 节点（骨骼）层级

```
character-f            # GLB 场景根
└─ root
   ├─ leg-left
   ├─ leg-right
   └─ torso
      ├─ torso         # 躯干中段
      ├─ arm-left      # 左臂（远端，无独立 hand 节点）
      ├─ arm-right     # 右臂（远端，无独立 hand 节点）
      └─ head
```

- **`arm-right` / `arm-left` 即手臂末端**（没有单独的 `hand` 节点）。武器模型作为 `arm-right` 的子节点、用本地偏移调到手掌位置，即可随手臂挥动而跟随。
- 攻击剪辑的目标节点包含 `root` / `torso` / `arm-left` / `arm-right` / `leg-*` / `head`，即会驱动整体姿态（含轻微前冲/重心移动），无需手动补前冲 Tween。

## 3. 动画清单（含时长）

时长由动画时间轨道最大值得出，单位秒。短姿态类（holding-*、static）播一次后会停在末帧，可作常驻姿态；循环类（walk/idle/run/sprint）适合在移动/待机时循环播放。

### 攻击 / 近战

| 动画 | 时长 | 说明 | 本特性用途 |
|------|------|------|-----------|
| `attack-melee-right` | 0.417s | 右手臂挥击 / 拳击 | **持剑怪与空手怪的近战攻击**（剑随手臂劈下；空手即拳击）。活跃帧约 0.2s（约 48% 处） |
| `attack-melee-left` | 0.417s | 左手臂挥击 / 拳击 | 同上，左手变体（备用） |
| `attack-kick-right` | 0.583s | 右腿踢击 | 空手/踢击备选（用户选定"空手仅拳击"，故 v1 不接入） |
| `attack-kick-left` | 0.583s | 左腿踢击 | 同上 |

### 持械 / 持枪姿态（常驻）

| 动画 | 时长 | 说明 | 本特性用途 |
|------|------|------|-----------|
| `holding-right` | 0.167s | 右手持械静止姿态 | **远程怪物常驻持枪姿态**（`_ready` 播放后停在末帧，枪停手中） |
| `holding-left` | 0.167s | 左手持械静止姿态 | 备用 |
| `holding-both` | 0.167s | 双手持械静止姿态 | 备用 |
| `holding-right-shoot` | 0.200s | 右手持枪射击姿态 | 远程开火姿态备选（v1 用 `holding-right` + 后坐/闪光叠加） |
| `holding-left-shoot` | 0.200s | 左手持枪射击姿态 | 备用 |
| `holding-both-shoot` | 0.200s | 双手持枪射击姿态 | 备用 |

### 移动 / 待机

| 动画 | 时长 | 说明 | 当前是否使用 |
|------|------|------|--------------|
| `idle` | 1.333s | 待机循环 | ✅ 近战怪静止时播放（基类 `_select_animation("idle")`） |
| `walk` | 0.667s | 行走循环 | ✅ 慢速移动（strafe 半速）时播放 |
| `walk-backward` | 0.667s | 后退行走 | ❌ 未用（后退时仍用 walk） |
| `run` | 0.500s | 奔跑循环 | ✅ 全速移动（chase/back）时播放 |
| `sprint` | 0.500s | 冲刺循环 | ❌ 未用（怪物无 sprint 速度源，`move_speed` 为上限） |
| `static` | 0.100s | 静止基准姿态 | ❌ 未用 |

### 状态 / 死亡

| 动画 | 时长 | 说明 | 当前是否使用 |
|------|------|------|--------------|
| `die` | 0.333s | 死亡倒地 | ❌ **未用**（现用整体缩小 Tween 代替，见 §5） |

### 其他（本特性暂不涉及，列出备查）

| 动画 | 时长 | 说明 |
|------|------|------|
| `sit` / `wheelchair-sit` | 0.167s | 坐姿 / 轮椅坐姿 |
| `drive` | 0.167s | 驾驶姿态 |
| `wheelchair-move-*` | 0.500s | 轮椅四个方向移动 |
| `pick-up` | 0.333s | 拾取动作 |
| `interact-right` / `interact-left` | 0.667s | 左右交互 |
| `emote-yes` / `emote-no` | 0.667s | 点头 / 摇头表情 |

## 4. 在 Godot 中如何访问

- 动画由导入后的 **`AnimationPlayer`** 提供。怪物场景（`objects/monster_*.tscn`）通过 `Model/CharacterModel`（`CharacterModel` 是 GLB 实例）引用模型，因此 `AnimationPlayer` 位于 `Model/CharacterModel` 之下。
- 在怪物脚本中缓存引用（节点名由 Godot 导入生成，建议运行时查找而非硬编码路径）：

  ```gdscript
  var character_model: Node3D
  var anim_player: AnimationPlayer
  var arm_right: Node3D

  func _ready() -> void:
      character_model = $Model/CharacterModel
      anim_player = character_model.find_child("AnimationPlayer", true, false)
      arm_right   = character_model.find_child("arm-right", true, false)
      anim_player.play("holding-right")   # 常驻持枪姿态示例
  ```

- 武器挂载示例（挂到右手、随手臂动画跟随）：

  ```gdscript
  var weapon := weapon_model.instantiate()
  arm_right.add_child(weapon)
  weapon.position = Vector3(0, -ARM_LENGTH, 0.1)   # 本地偏移调到手掌，值靠试玩微调
  weapon.rotation_degrees = Vector3(0, 0, 0)
  ```

- 注意：GLB 导入默认 `import_as_skeleton_bones = false`，`arm-right` 等节点**仍作为普通节点存在于导入场景**（节点式绑定），可直接 `add_child` / `find_child`；无需开启骨骼节点暴露。

## 5. 当前使用情况检查（移动 / 受伤 / 死亡）

对照 `objects/monster_ranged.gd` 与 `objects/monster_melee.gd`：

| 行为 | 是否使用动画 | 当前实现 |
|------|--------------|----------|
| **移动（移动中）** | ✅ 是 | `_select_animation()`（基类 `monster_base.gd`）按水平速度选取 `walk`（慢，strafe 半速）/ `run`（快，chase 全速）骨骼剪辑循环播放；静止时近战播 `idle`、远程保持 `holding-right`。已移除程序化 `_animate_walk`/`_animate_idle` bob。 |
| **受伤（hurt）** | ❌ 否 | `damage()` 播放 `enemy_hurt.ogg` + `HitFeedback.flash()` + 程序化 `scale` 挤压 Tween，**未播放**任何受伤/硬直剪辑（模型本身也**没有** hurt/flinch 类剪辑） |
| **死亡（death）** | ✅ 是 | `destroy()`（基类 `monster_base.gd`）播放 `die`（0.333s）骨骼剪辑，用实际剪辑时长驱动 `queue_free`。已移除程序化整体缩小 Tween。 |

**结论**：移动与死亡已接入骨骼动画（T4/T5）；受伤仍为程序化反馈（模型无 hurt 剪辑，无法接入）。`sprint` 剪辑保留但因怪物无 sprint 速度源暂不选取。

## 6. 与"怪物武器与动画"特性（ADR 008）的关系

- T1（远程怪）：已接入 `holding-right`（常驻持枪姿态）+ 开火反馈；子弹从挂在 `arm-right` 的枪口 `Muzzle` 射出。
- T2（近战怪）：已接入 `attack-melee-right`（持剑挥砍 / 空手拳击），伤害在活跃帧（约 0.2s）按距离判定结算；`melee_weapon_model` 留空即空手变体。
- T4（移动/待机）：已接入 `walk` / `run` / `idle` 骨骼剪辑（基类 `_select_animation`），已移除程序化 bob。
- T5（死亡）：已接入 `die` 骨骼剪辑（基类 `destroy`），已移除程序化缩小 Tween。
- 闲置：`sprint` 剪辑已设循环但无 sprint 速度源（怪物 `move_speed` 为上限），暂不选取。
