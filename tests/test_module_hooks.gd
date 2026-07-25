## Issue 09 测试：monster_base 行为模块挂钩（ADR 022）
## 验证：子节点模块自动发现 + module_setup / on_tick / on_enter_state /
##       on_exit_state / on_damage / on_death 回调；未实现方法的子节点自动跳过。
## 运行：godot --headless --path . res://tests/test_module_hooks.tscn --quit-after 30
extends Node3D

var failures: int = 0

## 假模块：实现全部 6 个钩子并记录调用
class FakeModule extends Node:
	var host: Node = null
	var setup_count: int = 0
	var ticks: int = 0
	var entered: Array = []
	var exited: Array = []
	var damages: Array = []
	var deaths: int = 0
	func module_setup(h: Node) -> void:
		host = h
		setup_count += 1
	func on_tick(_delta: float) -> void:
		ticks += 1
	func on_enter_state(s: int) -> void:
		entered.append(s)
	func on_exit_state(s: int) -> void:
		exited.append(s)
	func on_damage(a: float) -> void:
		damages.append(a)
	func on_death() -> void:
		deaths += 1

func _ready() -> void:
	call_deferred("_run_tests")

func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[TEST] ok: ", msg)
	else:
		print("[TEST] FAIL: ", msg)
		failures += 1

func _run_tests() -> void:
	# 用真实怪物场景（monster_melee）验证；模块在入树前挂载
	var monster: CharacterBody3D = preload("res://objects/monster_melee.tscn").instantiate()
	var module := FakeModule.new()
	monster.add_child(module)
	# 一个未实现任何钩子方法的普通子节点：应被注册但全部跳过（不报错）
	var plain := Node.new()
	monster.add_child(plain)

	add_child(monster)  # 触发 _ready → _setup_modules

	# 1. module_setup 收到宿主引用
	_check(module.setup_count == 1, "module_setup called once (got %d)" % module.setup_count)
	_check(module.host == monster, "module_setup received host reference")

	# 2. 状态转换 → on_enter_state（初始 IDLE → CHASE）
	monster._change_state(monster.AIState.CHASE)
	_check(module.entered == [monster.AIState.CHASE],
		"on_enter_state(CHASE) called (got %s)" % str(module.entered))
	# 同状态重复 _change_state 不触发（_ai_state == new_state 直接 return）
	monster._change_state(monster.AIState.CHASE)
	_check(module.entered.size() == 1, "same-state transition does not re-fire on_enter_state")

	# 3. damage() → on_exit_state(当前状态) + on_damage(amount)
	var health_before: float = monster.health
	monster.damage(15.0)
	_check(module.exited == [monster.AIState.CHASE],
		"on_exit_state called with current state on damage (got %s)" % str(module.exited))
	_check(module.damages == [15.0], "on_damage(15.0) called (got %s)" % str(module.damages))
	_check(monster.health < health_before, "damage still reduces health")

	# 4. on_tick：手动驱动 _physics_process（缓降阶段也会 tick）
	var ticks_before: int = module.ticks
	monster._physics_process(0.016)
	_check(module.ticks == ticks_before + 1, "on_tick called per physics frame (got %d)" % module.ticks)

	# 5. destroy() → on_death
	monster.destroy()
	_check(module.deaths == 1, "on_death called on destroy (got %d)" % module.deaths)

	# 6. 死亡后不再 tick / 受击不回调
	monster._physics_process(0.016)
	_check(module.ticks == ticks_before + 1, "no on_tick after death")
	monster.damage(5.0)
	_check(module.damages.size() == 1, "no on_damage after death")

	monster.queue_free()

	if failures == 0:
		print("[TEST] PASS — issue 09 module hooks")
		get_tree().quit(0)
	else:
		print("[TEST] FAIL — %d assertion(s) failed" % failures)
		get_tree().quit(1)
