extends GutTest

const H = preload("res://tests/sim_helpers.gd")


func test_personal_shortfall_is_a_missed_payment() -> void:
	var sim := H.game("slashdot")
	H.run_until(sim, "2009-01-31")
	sim.state.finance.cash_cents = 0
	sim.apply({"type": "quit_job"})
	var r := sim.step_day()  # 2009-01-31
	r = sim.step_day()  # 2009-02-01: living costs, no salary
	assert_eq(r.of_type("payment_missed").size(), 1)
	assert_eq(sim.state.finance.cash_cents, 0)
	assert_eq(sim.state.finance.missed_cents, sim.finance.living_cents(sim.state))


func test_dilution_scales_with_leverage() -> void:
	var r := H.game().restructuring
	assert_almost_eq(r.dilution(0, 100), r.dilution_base, 1e-9)
	assert_almost_eq(r.dilution(50, 100), r.dilution_base + r.dilution_per_leverage * 0.5, 1e-9)
	assert_almost_eq(r.dilution(1000, 1), r.dilution_max, 1e-9)


func test_company_shortfall_is_chapter_11() -> void:
	var sim := H.game("late")
	sim.apply({"type": "incorporate"})
	sim.apply({"type": "take_loan"})
	sim.state.finance.cash_cents = 50_000_00
	sim.apply({"type": "buy_hardware", "unit_id": "gpu_card", "count": 8, "used": true})
	sim.step_day()
	sim.state.finance.cash_cents = -1_000_00
	var day: int = sim.state.day_index
	var r := DayResult.new(day, sim.current_date())
	sim.restructuring.settle(sim, day, r)
	assert_eq(r.of_type("payment_overdue").size(), 1, "the cure clock starts")
	assert_eq(r.of_type("restructured").size(), 0)
	r = DayResult.new(day + sim.restructuring.cure_days, "")
	sim.restructuring.settle(sim, day + sim.restructuring.cure_days, r)
	var done: Array[Dictionary] = r.of_type("restructured")
	assert_eq(done.size(), 1)
	assert_eq(sim.state.finance.loan_balance_cents, 0, "debt converted")
	assert_eq(sim.state.finance.cash_cents, 0)
	assert_lt(sim.state.finance.ownership, 1.0)
	assert_eq(H.lot_of(sim, "gpu_card").count, 6, "a quarter of the fleet sold")
	assert_eq(sim.state.objectives.restructurings, 1)


func test_ownership_below_floor_loses_the_act() -> void:
	var sim := H.game("late")
	sim.apply({"type": "incorporate"})
	sim.state.finance.ownership = 0.12
	sim.state.finance.cash_cents = -1_000_00
	sim.state.finance.overdue_since_day = sim.state.day_index - sim.restructuring.cure_days
	var r := DayResult.new(sim.state.day_index, sim.current_date())
	sim.restructuring.settle(sim, sim.state.day_index, r)
	assert_eq(r.of_type("act_lost").size(), 1)
	assert_true(sim.is_finished())
	assert_false(sim.apply({"type": "quit_job"})["ok"])


func test_unpaid_living_costs_never_trigger_chapter_11() -> void:
	var sim := H.game("late")
	sim.apply({"type": "incorporate"})
	H.run_until(sim, "2012-12-01")
	sim.apply({"type": "quit_job"})
	sim.state.finance.cash_cents = 0
	var r := sim.step_day()  # 2012-12-01: living costs due, no salary
	assert_eq(r.of_type("restructured").size(), 0)
	assert_eq(r.of_type("payment_missed").size(), 1)
	assert_eq(sim.state.finance.ownership, 1.0)


func test_paying_within_the_cure_window_avoids_chapter_11() -> void:
	var sim := H.game("late")
	sim.apply({"type": "incorporate"})
	sim.state.finance.cash_cents = -100_00
	var day: int = sim.state.day_index
	var r := DayResult.new(day, "")
	sim.restructuring.settle(sim, day, r)
	sim.state.finance.cash_cents = 500_00  # the player moved and sold coins
	r = DayResult.new(day + 3, "")
	sim.restructuring.settle(sim, day + 3, r)
	assert_eq(r.of_type("payment_cured").size(), 1)
	assert_eq(sim.state.finance.overdue_since_day, -1)
	assert_eq(sim.state.objectives.restructurings, 0)
