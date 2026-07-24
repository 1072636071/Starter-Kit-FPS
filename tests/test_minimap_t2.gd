## 小地图 T2 测试：圆形小地图 UI 容器
## 运行：godot --headless --path . res://tests/test_minimap_t2.tscn --quit-after 30
## 判定：看到 [TEST] PASS 即通过；任何 [TEST] FAIL 行即失败（exit 1 由脚本自行 quit(1)）
extends Node3D

var failures: int = 0

func _ready():
	call_deferred("_run_tests")

func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1

func _run_tests() -> void:
	# 实例化 main.tscn 整个场景，验证 Minimap UI 容器
	var main_scene := preload("res://scenes/main.tscn")
	var main: Node3D = main_scene.instantiate()
	add_child(main)

	# 1. HUD 下存在 Minimap Control 节点
	var hud: CanvasLayer = main.get_node_or_null("HUD")
	_check(hud != null, "HUD CanvasLayer exists")
	var minimap: Control = hud.get_node_or_null("Minimap") if hud else null
	_check(minimap != null, "HUD/Minimap Control exists")
	if minimap:
		# 2. Minimap 锚定右上角（anchor_left=1, anchor_top=0）
		_check(abs(minimap.anchor_left - 1.0) < 0.001,
			"Minimap anchor_left = 1.0 (top-right, got %f)" % minimap.anchor_left)
		_check(abs(minimap.anchor_top - 0.0) < 0.001,
			"Minimap anchor_top = 0.0 (top-right, got %f)" % minimap.anchor_top)
		_check(abs(minimap.anchor_right - 1.0) < 0.001,
			"Minimap anchor_right = 1.0 (got %f)" % minimap.anchor_right)
		_check(abs(minimap.anchor_bottom - 0.0) < 0.001,
			"Minimap anchor_bottom = 0.0 (got %f)" % minimap.anchor_bottom)

		# 3. Minimap 尺寸合理（>0）
		var w := minimap.size.x
		var h := minimap.size.y
		_check(w > 50.0 and h > 50.0,
			"Minimap size non-trivial (got %s)" % str(minimap.size))

		# 4. Minimap 下存在 Background TextureRect 子节点
		var bg: TextureRect = minimap.get_node_or_null("Background")
		_check(bg != null, "HUD/Minimap/Background TextureRect exists")
		if bg:
			# 5. Background.texture 为 ViewportTexture
			var tex := bg.texture
			_check(tex != null, "Background.texture is non-null")
			_check(tex is ViewportTexture,
				"Background.texture is ViewportTexture (got %s)" % (
					tex.get_class() if tex else "null"))

			# 6. Background.material 为 ShaderMaterial（径向 alpha 遮罩）
			var mat := bg.material
			_check(mat != null, "Background.material is non-null")
			_check(mat is ShaderMaterial,
				"Background.material is ShaderMaterial (got %s)" % (
					mat.get_class() if mat else "null"))
			if mat is ShaderMaterial:
				var shader := (mat as ShaderMaterial).shader
				_check(shader != null, "ShaderMaterial has a Shader")
				if shader:
					# 7. Shader 是 canvas_item 类型（用于 2D TextureRect）
					_check(shader.code.find("shader_type canvas_item") >= 0,
						"Shader code is shader_type canvas_item")
					# 8. Shader 含径向 alpha 逻辑（smoothstep + distance + center）
					_check(shader.code.find("distance") >= 0,
						"Shader code computes radial distance")
					_check(shader.code.find("smoothstep") >= 0,
						"Shader code uses smoothstep for alpha falloff")
					_check(shader.code.find("0.5") >= 0,
						"Shader code references radius 0.5 (UV center)")

	# 9. 主相机与武器相机的 cull_mask 未被改动
	var player: CharacterBody3D = main.get_node_or_null("Player")
	if player:
		var main_cam: Camera3D = player.get_node_or_null("Head/Camera")
		if main_cam:
			_check(main_cam.cull_mask == 1048573,
				"main Camera cull_mask unchanged (got %d)" % main_cam.cull_mask)
		var weapon_cam: Camera3D = player.get_node_or_null("Head/Camera/SubViewportContainer/SubViewport/CameraItem")
		if weapon_cam:
			_check(weapon_cam.cull_mask == 1047554,
				"weapon CameraItem cull_mask unchanged (got %d)" % weapon_cam.cull_mask)

	if failures == 0:
		print("[TEST] PASS — minimap T2 circular UI container")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
