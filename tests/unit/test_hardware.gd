extends GutTest

const H = preload("res://tests/sim_helpers.gd")


func test_starting_laptop() -> void:
	var sim := H.game()
	var lot := H.lot_of(sim, "cpu_laptop")
	assert_not_null(lot)
	assert_eq(lot.count, 1)
	assert_eq(lot.cost_cents, 0)


func test_nothing_for_sale_before_mining_unlocks() -> void:
	var sim := H.game("slashdot")
	H.run_until(sim, "2010-07-01")
	assert_false(sim.hardware.is_available(sim, "cpu_desktop"))
	H.run_until(sim, "2010-07-12")
	assert_true(sim.hardware.is_available(sim, "cpu_desktop"))


func test_availability_follows_ship_dates() -> void:
	var sim := H.game("cypherpunk")
	H.run_until(sim, "2010-09-30")
	assert_false(sim.hardware.is_available(sim, "gpu_card"))
	H.run_until(sim, "2010-10-01")
	assert_true(sim.hardware.is_available(sim, "gpu_card"))
	H.run_until(sim, "2013-01-18")
	assert_false(sim.hardware.is_available(sim, "asic_gen1"))
	H.run_until(sim, "2013-01-20")
	assert_true(sim.hardware.is_available(sim, "asic_gen1"), "after first_asics_ship")


func test_gpu_rig_overhead_on_first_and_fifth_card() -> void:
	var sim := H.game("cypherpunk")
	H.run_until(sim, "2010-10-02")
	sim.state.finance.cash_cents = 10_000_000
	var card: int = sim.hardware.new_price_cents("gpu_card", sim.state.day_index)
	assert_eq(sim.hardware.quote_cents(sim, "gpu_card", 1, false), card + sim.hardware.rig_overhead_cents)
	assert_true(sim.apply({"type": "buy_hardware", "unit_id": "gpu_card", "count": 4})["ok"])
	assert_eq(sim.hardware.quote_cents(sim, "gpu_card", 1, false), card + sim.hardware.rig_overhead_cents, "fifth card starts a rig")
	assert_eq(sim.hardware.quote_cents(sim, "gpu_card", 0, false), 0)


func test_purchase_needs_cash_and_arrives_after_lead_time() -> void:
	var sim := H.game("cypherpunk")
	H.run_until(sim, "2010-10-02")
	sim.state.finance.cash_cents = 0
	assert_false(sim.apply({"type": "buy_hardware", "unit_id": "gpu_card", "count": 1})["ok"])
	sim.state.finance.cash_cents = 1_000_000
	var r: Dictionary = sim.apply({"type": "buy_hardware", "unit_id": "gpu_card", "count": 1})
	assert_true(r["ok"])
	assert_eq(r["arrive_day"], sim.state.day_index + sim.hardware.lead_time("gpu_card"))
	var arrived: Array[Dictionary] = H.of_type(H.run_until(sim, sim.data.history.dates[r["arrive_day"] + 1]), "hardware_arrived")
	assert_eq(arrived.size(), 1)


func test_asic_new_price_tracks_hashprice_within_clamp() -> void:
	var sim := H.game("late")
	var hw := sim.hardware
	var launch: int = sim.data.history.index_of("2013-01-19")
	assert_eq(hw.new_price_cents("asic_gen1", launch), hw.base_price_cents("asic_gen1"))
	var later: int = sim.data.history.index_of("2014-06-01")
	var ratio: float = float(hw.new_price_cents("asic_gen1", later)) / hw.base_price_cents("asic_gen1")
	assert_almost_eq(ratio, float(hw.price_clamp[0]), 1e-3, "hashprice collapsed, price at the floor")
	assert_eq(hw.new_price_cents("gpu_card", later), hw.base_price_cents("gpu_card"), "GPUs keep their price")


func test_used_price_falls_with_age_to_floor() -> void:
	var sim := H.game("late")
	var hw := sim.hardware
	var day: int = sim.state.day_index
	var young: int = hw.used_price_cents("gpu_card", 0, day)
	var old: int = hw.used_price_cents("gpu_card", 730, day)
	var ancient: int = hw.used_price_cents("gpu_card", 5000, day)
	assert_eq(young, roundi(hw.new_price_cents("gpu_card", day) * hw.used_fraction))
	assert_lt(old, young)
	assert_eq(ancient, roundi(hw.new_price_cents("gpu_card", day) * hw.used_fraction * hw.used_floor))


func test_book_value_is_straight_line() -> void:
	var sim := H.game("late")
	var lot := sim.hardware.add_lot(sim.state, "gpu_card", 1, 300_00, 0)
	assert_eq(sim.hardware.book_value_lot_cents(lot, 0), 300_00)
	var half: int = sim.hardware.depreciation_days / 2
	assert_eq(sim.hardware.book_value_lot_cents(lot, half), roundi(300_00 * (1.0 - float(half) / sim.hardware.depreciation_days)))
	assert_eq(sim.hardware.book_value_lot_cents(lot, sim.hardware.depreciation_days + 10), 0)


func test_failure_probability_rises_with_age() -> void:
	var hw := H.game().hardware
	assert_lt(hw.daily_failure_probability(10), hw.daily_failure_probability(400))
	assert_lt(hw.daily_failure_probability(400), hw.daily_failure_probability(5000))
	assert_almost_eq(1.0 - pow(1.0 - hw.daily_failure_probability(10), 365.0), float(hw.annual_failure_rate[0]), 1e-9)


func test_sell_returns_used_price_and_books_the_gain() -> void:
	var sim := H.game("cypherpunk")
	H.run_until(sim, "2010-10-02")
	sim.state.finance.cash_cents = 1_000_000
	var r: Dictionary = sim.apply({"type": "buy_hardware", "unit_id": "gpu_card", "count": 2, "used": true})
	assert_true(r["ok"])
	var lot := sim.hardware.find_lot(sim.state, r["lot_id"])
	var cash_before: int = sim.state.finance.cash_cents
	var s: Dictionary = sim.apply({"type": "sell_hardware", "lot_id": lot.id, "count": 1})
	assert_true(s["ok"])
	assert_eq(sim.state.finance.cash_cents, cash_before + s["proceeds_cents"])
	assert_eq(lot.count, 1)
