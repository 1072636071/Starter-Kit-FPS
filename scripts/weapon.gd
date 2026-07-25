extends Resource
class_name Weapon

@export_subgroup("Model")
@export var model: PackedScene # Model of the weapon
@export var position: Vector3 # On-screen position
@export var rotation: Vector3 # On-screen rotation
@export var muzzle_position: Vector3 # On-screen position of muzzle flash
@export var albedo_texture: Texture2D # Weapon texture (workaround for GLB import texture loss)

@export_subgroup("Properties")
@export_range(0.1, 1) var cooldown: float = 0.1 # Firerate
@export_range(1, 1000) var max_distance: int = 1000 # Fire distance
@export_range(0, 100) var damage: float = 25 # Damage per hit
@export_range(0, 5) var spread: float = 0 # Spread of each shot
@export_range(1, 5) var shot_count: int = 1 # Amount of shots
@export_range(0, 50) var knockback: int = 20 # Amount of knockback

@export var min_knockback: Vector2 = Vector2(0.001, 0.001) # x for vertical knockback, y for horizontal knockback
@export var max_knockback: Vector2 = Vector2(0.0025, 0.002) # x for vertical knockback, y for horizontal knockback

@export_subgroup("Sounds")
@export var sound_shoot: String # Sound path

@export_subgroup("Crosshair")
@export var crosshair: Texture2D # Image of crosshair on-screen

@export_subgroup("Projectile")
@export var projectile_color: Color = Color(1.0, 0.6, 0.1) # Bullet glow color
@export var projectile_size: Vector3 = Vector3(1, 1, 1) # Bullet scale
@export_range(30, 50) var projectile_speed: float = 40.0 # Bullet flight speed (m/s)

@export_subgroup("Ammo")
@export var display_name: String = "Weapon" # 中文显示名
@export_range(1, 999) var magazine_size: int = 8 # 弹匣容量
@export_range(0, 9999) var max_reserve: int = 40 # 备弹上限
@export_range(0.1, 10) var reload_time: float = 1.5 # 换弹时间（秒）
# DEPRECATED（issue 09，ADR 022）：商店已改用按弹药类型计价的成本表（shop_ui.AMMO_COST_PER_TYPE），
# 本字段不再被任何逻辑引用，仅为兼容旧 .tres 资源保留；issue 15/16 接弹药成本表后删除。
@export var gold_cost_per_bullet: int = 1

@export_subgroup("Identity (ADR 022)")
@export var ammo_type: StringName = &"手枪弹"           # 弹药类型（手枪弹/步枪弹/霰弹/狙击弹/能量电池/榴弹）
@export var weapon_cost: int = 30                        # 商店售价（金）
@export var durability_max: int = 150                    # 最大耐久（每扣扳机 -1，归零枪爆）
@export var role_title: String = ""                      # 角色定位，如 "入门可靠型"
@export var role_features: String = ""                   # 核心特征描述
@export var reliability_stars: int = 2                   # 可靠性 ★ 1-3

## Beam 武器模式（issue 15）："" = 常规弹体，"beam" = 持续射线
@export_subgroup("Beam")
@export var weapon_mode: String = ""
## beam 模式每 tick 间隔（秒），每 tick 扣 1 弹药 + 1 耐久 + 结算一次伤害
@export var tick_interval: float = 0.1


## 根据耐久比例返回对应颜色：>0.6 绿 / >0.2 黄 / ≤0.2 红
static func durability_color(ratio: float) -> Color:
	if ratio > 0.6:
		return Color(0.2, 0.9, 0.2, 0.85)
	elif ratio > 0.2:
		return Color(0.9, 0.8, 0.1, 0.85)
	else:
		return Color(0.95, 0.15, 0.15, 0.85)
