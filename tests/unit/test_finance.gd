extends GutTest

const H = preload("res://tests/sim_helpers.gd")


func test_salary_and_living_costs_on_the_first() -> void:
	var sim := H.game("slashdot")
	H.run_until(sim, "2009-02-01")
	var cash: int = sim.state.finance.cash_cents
	sim.step_day()  # 2009-02-01, no machines run yet... except the laptop's power
	var f := sim.finance
	var power: int = sim.state.hardware.power_cents_today
	assert_eq(sim.state.finance.cash_cents, cash + f.salary_cents - f.living_cents - power)


func test_quit_then_rejoin_after_delay() -> void:
	var sim := H.game("slashdot")
	assert_true(sim.apply({"type": "quit_job"})["ok"])
	assert_false(sim.state.finance.employed)
	assert_true(sim.apply({"type": "rejoin_job"})["ok"])
	var events: Array[Dictionary] = []
	for i: int in sim.finance.rehire_delay_days + 1:
		events.append_array(sim.step_day().events)
	assert_eq(H.of_type(events, "job_resumed").size(), 1)
	assert_true(sim.state.finance.employed)


func test_incorporation_waits_for_act_2() -> void:
	var sim := H.game("slashdot")
	assert_false(sim.apply({"type": "incorporate"})["ok"])
	var late := H.game("late")
	assert_true(late.apply({"type": "incorporate"})["ok"])
	assert_true(late.state.finance.incorporated)


func test_loan_needs_incorporation_and_is_one_only() -> void:
	var sim := H.game("late")
	assert_false(sim.apply({"type": "take_loan"})["ok"])
	sim.apply({"type": "incorporate"})
	var cash: int = sim.state.finance.cash_cents
	assert_true(sim.apply({"type": "take_loan"})["ok"])
	assert_eq(sim.state.finance.cash_cents, cash + sim.finance.loan_principal_cents)
	assert_false(sim.apply({"type": "take_loan"})["ok"])


func test_loan_amortizes_to_zero_on_schedule() -> void:
	var sim := H.game("late")
	sim.state.finance.cash_cents = 1_000_000_00
	sim.apply({"type": "incorporate"})
	sim.apply({"type": "take_loan"})
	var f := sim.state.finance
	assert_eq(f.loan_payment_cents, Finance.monthly_payment_cents(sim.finance.loan_principal_cents, 0.08, 36))
	var repaid: Array[Dictionary] = []
	while sim.current_date() < "2016-01-01" and f.loan_balance_cents > 0:
		repaid.append_array(H.of_type(sim.step_day().events, "loan_repaid"))
	assert_eq(f.loan_balance_cents, 0)
	assert_eq(repaid.size(), 1)
	assert_true(sim.current_date() >= "2015-11-01" and sim.current_date() <= "2015-12-02", "36 payments from Jan 2013")


func test_monthly_payment_formula() -> void:
	# $50,000 at 8% over 36 months is $1,566.82 a month.
	assert_eq(Finance.monthly_payment_cents(5_000_000, 0.08, 36), 156682)
	assert_eq(Finance.monthly_payment_cents(3600, 0.0, 36), 100)
