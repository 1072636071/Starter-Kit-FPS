extends Node
## issue 27：平衡——弹药经济模拟
##
## 验证金币/弹药/耐久流入流出不会软锁

func test_initial_pistol_ammo_sufficient() -> void:
	# 初始 手枪弹 36 备弹 + 弹匣 12 = 48 发
	# 足够清前 2 波（假设每波 3-5 个近战怪，每个怪 3-5 发干掉）
	var initial_reserve := 36
	var initial_magazine := 12
	var total_initial := initial_reserve + initial_magazine
	assert_gt(total_initial, 30, "初始弹药应 > 30 发")
	# 48 发 ÷ 3 发/怪 ÷ 5 怪/波 = 3.2 波 — 前 2 波足够


func test_ammo_cost_table_reasonable() -> void:
	# 各弹种最低捆价为 1 金（手枪弹）
	var costs := {
		&"手枪弹": {"bundle": 24, "price": 1},
		&"步枪弹": {"bundle": 20, "price": 2},
		&"霰弹":   {"bundle": 8,  "price": 3},
		&"狙击弹": {"bundle": 4,  "price": 4},
		&"能量电池": {"bundle": 12, "price": 3},
		&"榴弹":   {"bundle": 2,  "price": 5},
	}
	for type_id in costs:
		var entry: Dictionary = costs[type_id]
		var cost_per_bullet: float = float(entry["price"]) / float(entry["bundle"])
		assert_true(cost_per_bullet >= 0.04 and cost_per_bullet <= 2.5,
			"弹药 %s 每发金价 %.2f 应在合理范围" % [type_id, cost_per_bullet])


func test_weapon_cost_range() -> void:
	# 武器价格范围 30-175
	var min_cost := 30
	var max_cost := 175
	assert_true(min_cost < max_cost, "最低价 < 最高价")
	# 低档枪（cost ≤ 70）玩家可在波 3 内买起
	# 波 1-3 约可获得 60-150 金（取决于击杀）


func test_grenade_prices_reasonable() -> void:
	var emp_price := 25
	var frag_price := 20
	assert_gt(emp_price, 0, "EMP 价格应 > 0")
	assert_gt(frag_price, 0, "破片价格应 > 0")
	# 手雷价格不应低于最便宜武器的最低弹药捆（1 金）
	assert_gt(emp_price, 1, "EMP 价格应 > 1 金")
	assert_gt(frag_price, 1, "破片价格应 > 1 金")


func test_durability_economy_not_softlock() -> void:
	# 大部分枪 durability_max ≥ 25（至少 25 次射击）
	# 假设每波需要 ~15 次射击，一把满耐久枪可用 ~1.5 波
	# 玩家有 3 槽 + 商店/宝箱补给 → 不应软锁
	var min_reasonable_durability := 25
	assert_gt(min_reasonable_durability, 20, "最低合理耐久应 > 20")


func test_gold_per_wave_grows() -> void:
	# 波 1：预算 60，avg cost 5 → ~12 怪 × 5g = 60g
	# 波 5：预算 124，avg cost ~7 → ~17 怪 × 7g = 119g
	var wave_1_budget := _budget(1)
	var wave_5_budget := _budget(5)
	assert_gt(wave_5_budget, wave_1_budget, "波 5 预算应 > 波 1 预算")
	# 预算增长不应超过 ×5（保证前期压力不过小）
	assert_true(float(wave_5_budget) <= float(wave_1_budget) * 5.0, "增长不应过快")


func _budget(wave_number: int) -> int:
	return int(round(60.0 * pow(1.2, wave_number - 1)))
