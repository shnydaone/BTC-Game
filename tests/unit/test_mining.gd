extends GutTest

const H = preload("res://tests/sim_helpers.gd")


func test_slashdot_mode_mines_nothing_before_the_story() -> void:
	var sim := H.game("slashdot")
	H.run_until(sim, "2010-07-11")
	assert_eq(sim.custody.total_sats(sim.state), 0)
	assert_false(sim.state.events.features.has("mining"))
	H.run_until(sim, "2010-08-11")
	assert_true(sim.state.events.features.has("mining"))
	assert_gt(sim.custody.total_sats(sim.state), 0, "a month of laptop mining")


func test_cypherpunk_laptop_mines_from_genesis() -> void:
	var sim := H.game("cypherpunk")
	H.run_until(sim, "2009-04-01")
	assert_gt(H.btc(sim.custody.total_sats(sim.state)), 10000.0)


func test_pool_needs_pools_to_exist() -> void:
	var sim := H.game("cypherpunk")
	assert_false(sim.apply({"type": "set_mining_mode", "mode": "pool"})["ok"])
	H.run_until(sim, "2010-12-17")
	assert_true(sim.apply({"type": "set_mining_mode", "mode": "pool"})["ok"])


func test_solo_mean_matches_pool_before_fee() -> void:
	# Same 60 days, solo across seeds versus pool expected value.
	var pool := H.game("cypherpunk", 1)
	pool.state.hashrate_override_hs = 5.0e9  # a few percent of the network
	H.run_until(pool, "2010-12-17")
	pool.apply({"type": "set_mining_mode", "mode": "pool"})
	var start: int = pool.custody.total_sats(pool.state)
	H.run_until(pool, "2011-02-15")
	var pool_gain: float = (pool.custody.total_sats(pool.state) - start) / (1.0 - pool.mining.pool_fee)
	var solo_total: float = 0.0
	var seeds: int = 30
	for seed_value: int in seeds:
		var solo := H.game("cypherpunk", 100 + seed_value)
		solo.state.hashrate_override_hs = 5.0e9
		H.run_until(solo, "2010-12-17")
		var s0: int = solo.custody.total_sats(solo.state)
		H.run_until(solo, "2011-02-15")
		solo_total += solo.custody.total_sats(solo.state) - s0
	assert_almost_eq(solo_total / seeds / pool_gain, 1.0, 0.05)


func test_mining_revenue_is_booked_at_the_close() -> void:
	var sim := H.game("cypherpunk")
	H.run_until(sim, "2010-12-17")
	sim.apply({"type": "set_mining_mode", "mode": "pool"})
	sim.step_day()
	var m := sim.state.mining
	var close: float = sim.data.history.price_usd[sim.state.day_index - 1]
	assert_gt(m.mined_sats_today, 0)
	assert_eq(m.mined_value_cents_today, roundi(m.mined_sats_today / 1.0e8 * close * 100.0))
	assert_eq(sim.state.ledger.totals.get("mining_revenue", 0) > 0, true)


func test_cpu_speedup_event_applies() -> void:
	var sim := H.game("cypherpunk")
	H.run_until(sim, "2010-07-29")
	assert_almost_eq(sim.hardware.unit_hashrate(sim.state, "cpu_laptop"), 800000.0, 1e-6)
	H.run_until(sim, "2010-07-30")
	assert_almost_eq(sim.hardware.unit_hashrate(sim.state, "cpu_laptop"), 800000.0 * 2.4, 1e-6)
