extends GutTest

const H = preload("res://tests/sim_helpers.gd")


func test_cost_matches_the_gdd_formula() -> void:
	var sim := H.game("cypherpunk")
	var s: Dictionary = sim.sites.site(sim.state)
	var expected: float = 35.0 * 0.5 * 24.0 / 1000.0 * float(s["pue"]) * float(s["power_usd_per_kwh"]) * 100.0
	assert_almost_eq(sim.power.unit_cost_cents_per_day(sim, "cpu_laptop"), expected, 1e-9)
	var cash: int = sim.state.finance.cash_cents
	sim.step_day()
	assert_eq(cash - sim.state.finance.cash_cents, roundi(expected), "only power is due on day one")


func test_laptop_hashes_at_half_uptime() -> void:
	var sim := H.game("cypherpunk")
	sim.step_day()
	assert_almost_eq(sim.state.player_hashrate_hs, 800000.0 * 0.5, 1e-6)


func test_bedroom_capacity_caps_running_units() -> void:
	var sim := H.game("cypherpunk")
	H.run_until(sim, "2010-10-02")
	sim.state.finance.cash_cents = 100_000_00
	sim.apply({"type": "buy_hardware", "unit_id": "gpu_card", "count": 8, "used": true})
	sim.step_day()
	var watts: float = sim.hardware.unit_watts("gpu_card")
	var lot := H.lot_of(sim, "gpu_card")
	assert_eq(lot.running, floori(1000.0 / watts), "cards first, by efficiency")
	assert_eq(H.lot_of(sim, "cpu_laptop").running, 1, "the leftover watts still fit the laptop")


func test_garage_lifts_the_cap() -> void:
	var sim := H.game("cypherpunk")
	H.run_until(sim, "2010-10-02")
	sim.state.finance.cash_cents = 100_000_00
	sim.apply({"type": "buy_hardware", "unit_id": "gpu_card", "count": 8, "used": true})
	assert_true(sim.apply({"type": "move_site", "site_id": "garage"})["ok"])
	sim.step_day()
	assert_eq(H.lot_of(sim, "gpu_card").running, 8)


func test_short_cash_shuts_machines_off_before_incorporation() -> void:
	var sim := H.game("cypherpunk")
	sim.state.finance.cash_cents = 0
	var r := sim.step_day()
	assert_eq(r.of_type("machines_shut_off").size(), 1)
	assert_eq(sim.state.player_hashrate_hs, 0.0)
	assert_eq(sim.state.finance.cash_cents, 0)


func test_unprofitable_units_stay_off_when_set() -> void:
	var sim := H.game("late")
	H.run_until(sim, "2013-06-01")
	sim.apply({"type": "set_shutoff_unprofitable", "enabled": true})
	sim.step_day()
	assert_eq(H.lot_of(sim, "cpu_laptop").running, 0, "a laptop cannot pay its power in 2013")
	sim.apply({"type": "set_shutoff_unprofitable", "enabled": false})
	sim.step_day()
	assert_eq(H.lot_of(sim, "cpu_laptop").running, 1)
