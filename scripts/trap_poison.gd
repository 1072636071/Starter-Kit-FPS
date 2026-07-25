extends "res://scripts/trap_base.gd"
## 毒陷阱：触发后展开绿色粒子区域，每 tick_interval 秒扣 poison_dps 伤害，持续 duration 秒

@export var poison_radius: float = 3.0
@export var tick_interval: float = 0.5
@export var poison_dps: int = 8
@export var duration: float = 10.0

var _player_in_area: Node3D = null
var _elapsed: float = 0.0
var _tick_timer: float = 0.0
var _active: bool = false


func activate(player: Node3D) -> void:
	if _active:
		return
	_active = true
	_player_in_area = player

	# 展开粒子区域：创建 GPUParticles3D 表示毒雾
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = false
	particles.amount = 30
	particles.lifetime = duration
	particles.process_material = _make_particle_material()
	add_child(particles)

	# 禁用碰撞体，让 DOT 按时间持续（不依赖持续碰撞检测）
	if $CollisionShape3D:
		$CollisionShape3D.disabled = true

	# 设置 DOT 计时器
	_elapsed = 0.0
	_tick_timer = 0.0


func _make_particle_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.spread = 180.0
	mat.gravity = Vector3(0, 0.5, 0)
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 2.0
	mat.scale_min = 0.3
	mat.scale_max = 1.0
	mat.color = Color(0.2, 0.9, 0.2, 0.6)
	mat.color_ramp = _make_color_ramp()
	return mat


func _make_color_ramp() -> GradientTexture1D:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(0.1, 1.0, 0.1, 0.7),
		Color(0.0, 0.7, 0.0, 0.4),
		Color(0.0, 0.3, 0.0, 0.0),
	])
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	return tex


func _process(delta: float) -> void:
	if not _active:
		return

	_elapsed += delta
	if _elapsed >= duration:
		queue_free()
		return

	_tick_timer += delta
	if _tick_timer >= tick_interval:
		_tick_timer -= tick_interval
		_apply_dot()


func _apply_dot() -> void:
	if not is_instance_valid(_player_in_area):
		return

	var dist := global_position.distance_to(_player_in_area.global_position)
	if dist <= poison_radius:
		if _player_in_area.has_method("damage"):
			_player_in_area.damage(poison_dps)
