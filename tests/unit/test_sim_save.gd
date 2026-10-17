extends GutTest

const SAVE_SCRIPT: GDScript = preload("res://autoload/save.gd")

var data: GameData


func before_all() -> void:
	data = GameData.shared()


func _run(sim: Sim, days: int) -> void:
	for i: int in days:
		# A varying player hashrate exercises the epoch accumulators.
		sim.state.hashrate_override_hs = 1.0e6 * (1 + sim.state.day_index % 7)
		sim.rng.uniform("test")
		sim.step_day()


func test_save_and_load_continues_identically() -> void:
	var straight := Sim.new_game(data, "cypherpunk", 2024)
	_run(straight, 1000)

	var first := Sim.new_game(data, "cypherpunk", 2024)
	_run(first, 500)
	var resumed: Sim = SAVE_SCRIPT.from_json(SAVE_SCRIPT.to_json(first))
	assert_not_null(resumed)
	_run(resumed, 500)

	assert_eq(SAVE_SCRIPT.to_json(resumed), SAVE_SCRIPT.to_json(straight))


func test_step_day_reports_the_simulated_date() -> void:
	var sim := Sim.new_game(data, "slashdot", 1)
	var r := sim.step_day()
	assert_eq(r.date, "2009-01-03")
	assert_eq(sim.current_date(), "2009-01-04")


func test_sim_stops_at_the_end_of_history() -> void:
	var sim := Sim.new_game(data, "late", 1)
	sim.state.day_index = data.history.size() - 1
	assert_not_null(sim.step_day())
	assert_true(sim.is_finished())


## A busy game: purchases, a site move, pool mining, selling, transfers and offers.
func _busy(sim: Sim, days: int) -> void:
	for i: int in days:
		var date: String = sim.current_date()
		if date == "2010-10-02":
			sim.state.finance.cash_cents += 20_000_00
			sim.apply({"type": "move_site", "site_id": "garage"})
			sim.apply({"type": "buy_hardware", "unit_id": "gpu_card", "count": 6})
			sim.apply({"type": "buy_hardware", "unit_id": "cpu_desktop", "count": 1, "used": true})
		elif date == "2010-12-20":
			sim.apply({"type": "set_mining_mode", "mode": "pool"})
			sim.apply({"type": "set_treasury_policy", "policy": "sell_percent", "percent": 0.3})
		elif date == "2011-03-01":
			sim.apply({"type": "transfer_btc", "from": "cold", "to": "exchange_tier1", "sats": 100 * 100000000})
		for offer: SimState.Offer in sim.state.offers.open.duplicate():
			sim.apply({"type": "accept_offer" if offer.id % 2 == 0 else "decline_offer", "id": offer.id})
		sim.step_day()


func test_busy_game_saves_and_resumes_identically() -> void:
	var straight := Sim.new_game(data, "cypherpunk", 7)
	_busy(straight, 1000)
	var first := Sim.new_game(data, "cypherpunk", 7)
	_busy(first, 640)
	var resumed: Sim = SAVE_SCRIPT.from_json(SAVE_SCRIPT.to_json(first))
	_busy(resumed, 360)
	assert_eq(SAVE_SCRIPT.to_json(resumed), SAVE_SCRIPT.to_json(straight))
	assert_gt(straight.state.hardware.lots.size(), 1)
	assert_gt(straight.state.ledger.history.size(), 10)


func test_same_seed_same_game_different_seed_different_luck() -> void:
	var a := Sim.new_game(data, "cypherpunk", 11)
	var b := Sim.new_game(data, "cypherpunk", 11)
	var c := Sim.new_game(data, "cypherpunk", 12)
	_busy(a, 800)
	_busy(b, 800)
	_busy(c, 800)
	assert_eq(SAVE_SCRIPT.to_json(a), SAVE_SCRIPT.to_json(b))
	assert_ne(a.state.mining.blocks_found, c.state.mining.blocks_found)
