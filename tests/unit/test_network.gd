extends GutTest

const LAPTOP_HS: float = 800000.0

var data: GameData


func before_all() -> void:
	data = GameData.shared()


func _sim_at(mode_id: String) -> Sim:
	var sim := Sim.new_game(data, mode_id, 1)
	sim.state.hashrate_override_hs = 0.0  # no fleet unless a test sets one
	return sim


func _run_until(sim: Sim, iso_date: String) -> Array[DayResult]:
	var results: Array[DayResult] = []
	while sim.current_date() != iso_date:
		results.append(sim.step_day())
	return results


func test_zero_player_share_is_zero() -> void:
	var sim := _sim_at("cypherpunk")
	sim.state.hashrate_override_hs = 0.0
	sim.step_day()
	assert_eq(sim.state.network.player_share, 0.0)


func test_height_and_blocks_follow_history() -> void:
	var sim := _sim_at("cypherpunk")
	sim.state.hashrate_override_hs = LAPTOP_HS
	_run_until(sim, "2009-07-01")
	var i: int = data.history.index_of("2009-06-30")
	assert_eq(sim.state.network.height, data.history.height_end[i], "the player never adds blocks")
	assert_eq(sim.state.network.blocks_today, data.history.blocks[i])


func test_share_is_player_over_world_plus_player() -> void:
	var sim := _sim_at("cypherpunk")
	sim.state.hashrate_override_hs = LAPTOP_HS
	_run_until(sim, "2009-03-02")
	var world: float = data.history.hashrate_hs[data.history.index_of("2009-03-01")]
	assert_almost_eq(sim.state.network.player_share, LAPTOP_HS / (world + LAPTOP_HS), 1e-12)


func test_laptop_does_not_lift_difficulty_off_the_2009_floor() -> void:
	# The 2009 network plus one laptop stayed under the ~7.16 MH/s that difficulty 1 implies.
	var sim := _sim_at("cypherpunk")
	sim.state.hashrate_override_hs = LAPTOP_HS
	_run_until(sim, "2009-12-01")
	assert_eq(sim.state.network.effective_difficulty, 1.0)


func test_big_2009_player_lifts_difficulty() -> void:
	var sim := _sim_at("cypherpunk")
	sim.state.hashrate_override_hs = 8.0e6  # five desktops
	_run_until(sim, "2009-12-01")
	assert_gt(sim.state.network.effective_difficulty, 1.0)


func test_player_matching_the_world_doubles_difficulty_at_the_next_retarget() -> void:
	var sim := _sim_at("late")
	var start: int = sim.state.day_index
	# Skip to the start of a fresh epoch so it holds only days with the player.
	while sim.step_day().of_type("difficulty_adjusted").is_empty():
		pass
	var hist_before: float = sim.state.network.historical_difficulty
	assert_almost_eq(sim.state.network.effective_difficulty, hist_before, hist_before * 1e-12)
	var results: Array[DayResult] = []
	while true:
		sim.state.hashrate_override_hs = data.history.hashrate_hs[sim.state.day_index]
		var r := sim.step_day()
		if not r.of_type("difficulty_adjusted").is_empty():
			results.append(r)
			break
	var n := sim.state.network
	assert_almost_eq(n.effective_difficulty / n.historical_difficulty, 2.0, 1e-9)
	assert_almost_eq(results[0].of_type("difficulty_adjusted")[0]["change"], n.effective_difficulty / hist_before - 1.0, 1e-9)
	assert_gt(sim.state.day_index, start)


func test_retarget_clamps_at_four_x() -> void:
	var sim := _sim_at("late")
	while sim.step_day().of_type("difficulty_adjusted").is_empty():
		pass
	var before: float = sim.state.network.effective_difficulty
	while true:
		sim.state.hashrate_override_hs = 100.0 * data.history.hashrate_hs[sim.state.day_index]
		if not sim.step_day().of_type("difficulty_adjusted").is_empty():
			break
	assert_almost_eq(sim.state.network.effective_difficulty / before, 4.0, 1e-9)


func test_halving_event_fires_on_the_real_date() -> void:
	var sim := _sim_at("cypherpunk")
	sim.state.hashrate_override_hs = 8.0e6
	var halvings: Array = []
	for r: DayResult in _run_until(sim, "2012-12-01"):
		for e: Dictionary in r.of_type("subsidy_halved"):
			halvings.append([r.date, e["height"], e["subsidy_sats"]])
	assert_eq(halvings, [["2012-11-28", 210000, 2500000000]])


func test_late_mode_starts_at_halving_one() -> void:
	var sim := _sim_at("late")
	sim.state.hashrate_override_hs = 0.0
	assert_eq(sim.current_date(), "2012-11-28")
	var r := sim.step_day()
	assert_eq(r.of_type("subsidy_halved").size(), 1)
	assert_eq(sim.state.network.effective_difficulty, sim.state.network.historical_difficulty)


func test_subsidy_and_fees_today() -> void:
	var sim := _sim_at("late")
	sim.step_day()
	var i: int = data.history.index_of("2012-11-28")
	var n := sim.state.network
	var c := Consensus.new(data)
	assert_eq(n.subsidy_sats_today, c.subsidy_sats_for_range(n.height - n.blocks_today + 1, n.height))
	assert_eq(n.fees_sats_today, roundi(data.history.fees_btc[i] * 1e8))
