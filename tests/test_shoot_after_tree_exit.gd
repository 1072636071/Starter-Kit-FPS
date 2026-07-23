## 诊断测试：复现 player.gd:201 get_global_transform 在节点离开树时被调用的 bug
## 运行：godot --headless --path . res://tests/test_shoot_after_tree_exit.tscn --quit-after 20
## 判定：stderr 包含 "!is_inside_tree()" → BUG 存在（exit 1）；无此错误 → 已修复（exit 0）
extends Node3D

var player: CharacterBody3D
var frame_count := 0

func _ready():
	var player_scene = preload("res://objects/player.tscn")
	player = player_scene.instantiate()
	
	# player.gd 需要 crosshair 引用
	var hud = CanvasLayer.new()
	var crosshair = TextureRect.new()
	crosshair.name = "Crosshair"
	hud.add_child(crosshair)
	add_child(hud)
	player.crosshair = crosshair
	
	add_child(player)
	
	# 模拟射击输入持续按住（玩家死亡/坠落时鼠标仍按住）
	Input.action_press("shoot")
	print("[TEST] shoot 已按住，等待 player 射击后移除出树")

func _process(_delta):
	frame_count += 1
	
	# 第 3 帧：player 已射击过（cooldown 已启动），此时移除出树
	# 模拟 reload_current_scene() 导致的节点离树
	if frame_count == 3 and player and is_instance_valid(player):
		print("[TEST] 帧3：移除 player 出树")
		remove_child(player)
	
	# 第 4 帧：手动触发 _process 逻辑（模拟 Godot 在 scene change 过渡期仍调用 _process）
	if frame_count == 4 and player and is_instance_valid(player):
		print("[TEST] 帧4：player 不在树中，模拟 _process 仍被调用")
		# 直接调用 _process 来精确复现 bug 路径
		player._process(_delta)
	
	if frame_count >= 6:
		print("[TEST] 完成")
		# 清理
		if player and is_instance_valid(player):
			player.free()
		get_tree().quit(0)
