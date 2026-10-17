extends GutTest

const H = preload("res://tests/sim_helpers.gd")


func test_every_effect_type_has_a_handler() -> void:
	for e: Dictionary in GameData.shared().events:
		for fx: Dictionary in e["effects"]:
			assert_true(Events.handles(fx["type"]), "%s in %s" % [fx["type"], e["id"]])


func test_each_event_fires_once_on_its_date() -> void:
	var sim := H.game("cypherpunk")
	var fired: Dictionary = {}
	while not sim.is_finished():
		var r := sim.step_day()
		for e: Dictionary in r.of_type("historical_event"):
			assert_false(fired.has(e["id"]), "%s fired twice" % e["id"])
			fired[e["id"]] = r.date
	for e: Dictionary in sim.data.events:
		assert_eq(fired.get(e["id"], ""), e["date"], e["id"])


func test_halving_events_match_the_chain_height() -> void:
	var sim := H.game("cypherpunk")
	sim.state.hashrate_override_hs = 0.0
	while not sim.is_finished():
		var r := sim.step_day()
		for e: Dictionary in r.of_type("historical_event"):
			for ev: Dictionary in sim.data.events.filter(func(x: Dictionary) -> bool: return x["id"] == e["id"]):
				for fx: Dictionary in ev["effects"]:
					if fx["type"] == "halving":
						assert_eq(r.of_type("subsidy_halved").size(), 1, ev["id"])
						assert_eq(r.of_type("subsidy_halved")[0]["height"], int(fx["height"]))


func test_slashdot_unlocks_mining_on_2010_07_11() -> void:
	var sim := H.game("slashdot")
	var events: Array[Dictionary] = H.run_until(sim, "2010-07-12")
	var unlocks: Array[Dictionary] = H.of_type(events, "feature_unlocked").filter(func(e: Dictionary) -> bool: return e["feature"] == "mining")
	assert_eq(unlocks.size(), 1)


func test_late_mode_starts_with_history_applied() -> void:
	var sim := H.game("late")
	var f: PackedStringArray = sim.state.events.features
	for feature: String in ["mining", "price", "selling", "exchange_custody", "pool_mining"]:
		assert_true(f.has(feature), feature)
	assert_almost_eq(sim.state.hardware.tier_multipliers.get("CPU", 1.0), 2.4, 1e-9)
	assert_eq(sim.state.objectives.act, 2)
	assert_eq(sim.state.custody.active_exchange, "", "picked on the first day")
	sim.step_day()
	assert_eq(sim.state.custody.active_exchange, "exchange_tier1")
	assert_eq(sim.state.objectives.report_cards.size(), 0, "no act 1 report card in Late mode")


func test_pizza_offer_only_for_holders() -> void:
	var rich := H.game("cypherpunk")
	var offers: Array[Dictionary] = H.of_type(H.run_until(rich, "2010-05-23"), "offer_made")
	assert_eq(offers.filter(func(e: Dictionary) -> bool: return e["kind"] == "pizza").size(), 1)
	var poor := H.game("slashdot")
	assert_eq(H.of_type(H.run_until(poor, "2010-05-23"), "offer_made").size(), 0)


func test_accepting_an_offer_saves_cash_and_counts_regret() -> void:
	var sim := H.game("cypherpunk")
	var made: Array[Dictionary] = H.of_type(H.run_until(sim, "2010-05-23"), "offer_made")
	var pizza: Dictionary = made.filter(func(e: Dictionary) -> bool: return e["kind"] == "pizza")[0]
	var cash: int = sim.state.finance.cash_cents
	var sats: int = sim.custody.total_sats(sim.state)
	assert_true(sim.apply({"type": "accept_offer", "id": pizza["id"]})["ok"])
	assert_eq(sim.state.finance.cash_cents, cash + int(pizza["value_cents"]))
	assert_eq(sim.custody.total_sats(sim.state), sats - int(pizza["sats"]))
	var later: int = sim.data.history.index_of("2021-11-08")
	assert_gt(sim.offers.regret_cents(sim, later), 100_000_000_00, "10,000 BTC at the 2021 peak")


func test_forum_offers_arrive_after_mining_and_price() -> void:
	var sim := H.game("slashdot")
	var offers: Array[Dictionary] = H.of_type(H.run_until(sim, "2011-12-31"), "offer_made")
	assert_gt(offers.size(), 3)
	assert_true(offers.all(func(e: Dictionary) -> bool: return e["kind"] == "forum"))
