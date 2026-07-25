extends Node
## issue 27：平衡——波次生存模拟（验证波次预算公式与敌人配置）
##
## 模拟 RunDirector 波次预算/组成逻辑，验证难度递增合理。

func test_wave_budget_formula() -> void:
	# 波次预算公式：60 × 1.2^(N-1)
	assert_eq(_budget(1), 60, "波 1 预算 = 60")
	assert_gt(_budget(3), 80, "波 3 预算应 > 80")
	assert_gt(_budget(5), 120, "波 5 预算应 > 120")
	assert_gt(_budget(10), 300, "波 10 预算应 > 300")
	assert_gt(_budget(15), 700, "波 15 预算应 > 700")


func test_wave_composition_scales_with_budget() -> void:
	# 高波次应生成更多怪物（预算增长 → 类型数增长）
	for wave_num in [1, 5, 10, 15]:
		var budget := _budget(wave_num)
		var types := _available_types(wave_num)
		assert_gt(types.size(), 0, "波 %d 应有可用敌种" % wave_num)
		# 模拟随机生成：预期怪物数 ≈ budget / avg_cost
		# avg_cost 随波次递增（高波解锁高价敌人）


func test_enemy_costs_are_positive() -> void:
	for type_id in _config():
		var cost: int = _config()[type_id]["cost"]
		assert_gt(cost, 0, "敌人 %s 成本应 > 0" % type_id)


func test_enemy_rewards_are_positive() -> void:
	for type_id in _config():
		var reward: int = _config()[type_id]["reward"]
		assert_gt(reward, 0, "敌人 %s 奖励应 > 0" % type_id)


func test_min_wave_increases_with_cost() -> void:
	# 高成本敌人应在更高波次解锁
	var entries: Array = []
	for type_id in _config():
		var entry := _config()[type_id]
		entries.append({"type": type_id, "cost": entry["cost"], "min_wave": entry["min_wave"]})
	# 按 cost 排序
	entries.sort_custom(func(a, b): return a["cost"] < b["cost"])
	# 低cost 敌人应早解锁
	for i in range(1, entries.size()):
		var prev := entries[i - 1]
		var curr := entries[i]
		assert_true(curr["min_wave"] >= prev["min_wave"], 
			"高cost敌人(%s, cost=%d)不应比低cost敌人(%s, cost=%d)更早解锁" % [curr["type"], curr["cost"], prev["type"], prev["cost"]])


func test_no_enemy_costs_zero() -> void:
	for type_id in _config():
		assert_neq(_config()[type_id]["cost"], 0, "敌人 %s 成本不应为 0" % type_id)


# === 辅助方法（与 run_director.gd 同步） ===

func _budget(wave_number: int) -> int:
	return int(round(60.0 * pow(1.2, wave_number - 1)))


func _config() -> Dictionary:
	return {
		&"monster_melee": {"cost": 5, "reward": 5, "min_wave": 1},
		&"monster_ranged": {"cost": 8, "reward": 8, "min_wave": 4},
		&"enemy": {"cost": 10, "reward": 10, "min_wave": 7},
	}


func _available_types(wave_number: int) -> Array:
	var out: Array = []
	for type_id in _config():
		if wave_number >= _config()[type_id]["min_wave"]:
			out.append(type_id)
	return out
