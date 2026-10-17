extends GutTest

const H = preload("res://tests/sim_helpers.gd")


## Feeds the objective a fixed daily mined value without running the rest of the sim.
func _feed(sim: Sim, cents_per_day: int, days: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i: int in days:
		var r := DayResult.new(sim.state.day_index, sim.current_date())
		sim.state.mining.mined_value_cents_today = cents_per_day
		sim.objectives.step(sim, sim.state.day_index, r)
		events.append_array(r.events)
		sim.state.day_index += 1
	return events


func test_quit_job_needs_90_days_of_covered_costs() -> void:
	var sim := H.game("slashdot")
	var enough: int = ceili(sim.finance.living_cents_per_day())
	var window: int = sim.objectives.window_days
	var met: Array[Dictionary] = H.of_type(_feed(sim, enough, window + 88), "objective_met")
	assert_eq(met.size(), 0, "89 days of streak")
	met = H.of_type(_feed(sim, enough, 1), "objective_met")
	assert_eq(met.size(), 1)
	assert_ne(sim.state.objectives.quit_job_met_on, "")


func test_a_short_month_resets_the_streak() -> void:
	var sim := H.game("slashdot")
	var enough: int = ceili(sim.finance.living_cents_per_day())
	_feed(sim, enough, sim.objectives.window_days + 60)
	assert_gt(sim.state.objectives.streak, 0)
	_feed(sim, 0, sim.objectives.window_days)
	assert_eq(sim.state.objectives.streak, 0)


func test_act_1_report_card() -> void:
	var sim := H.game("slashdot")
	var cards: Array[Dictionary] = H.of_type(H.run_until(sim, "2012-11-29"), "act_ended")
	assert_eq(cards.size(), 1)
	var card: Dictionary = cards[0]
	assert_eq(card["act"], 1.0)
	assert_eq(card["date"], "2012-11-28")
	assert_false(card["primary_met"], "a laptop never quits the day job")
	assert_eq(card["grade"], "C")
	assert_eq(sim.state.objectives.act, 2)


func test_selling_in_the_2011_crash_loses_the_bonus() -> void:
	var sim := H.game("cypherpunk")
	H.run_until(sim, "2011-07-01")
	var ex: String = sim.state.custody.active_exchange
	sim.state.custody.exchange_sats[ex] = 1000000
	sim.apply({"type": "sell_btc", "sats": 1000000})
	assert_true(sim.state.objectives.crash_sold)
