extends GutTest

const H = preload("res://tests/sim_helpers.gd")


func test_fmt_numbers() -> void:
	assert_eq(Fmt.thousands(1234567), "1,234,567")
	assert_eq(Fmt.thousands(-1000), "-1,000")
	assert_eq(Fmt.usd(1234), "$12.34")
	assert_eq(Fmt.usd(123456), "$1,235")
	assert_eq(Fmt.usd(123_456_789), "$1.23M")
	assert_eq(Fmt.price(0.000764), "$0.00076")
	assert_eq(Fmt.price(0.0858), "$0.086")
	assert_eq(Fmt.price(29.6), "$29.60")
	assert_eq(Fmt.price(19187.78), "$19,188")
	assert_eq(Fmt.btc(0), "0")
	assert_eq(Fmt.btc(50_000_000), "0.50000000")
	assert_eq(Fmt.btc(1_000_000_000_00), "1,000")
	assert_eq(Fmt.hashrate(800000.0), "800 kH/s")
	assert_eq(Fmt.hashrate(1.4e13), "14.0 TH/s")
	assert_eq(Fmt.percent(0.1197, 2), "11.97%")
	assert_eq(Fmt.signed_percent(-0.026), "-2.6%")
	assert_eq(Fmt.watts(3125.0), "3.1 kW")


func test_no_price_before_the_first_rate() -> void:
	var sim := H.game("slashdot")
	H.run_until(sim, "2009-06-01")
	assert_true(is_nan(Readouts.price(sim)))
	assert_eq(Readouts.price_tooltip(sim), "No market exists yet. Bitcoin has no price.")
	assert_eq(Readouts.sparkline(sim).size(), 0)


func test_price_is_the_last_completed_close() -> void:
	var sim := H.game("slashdot")
	H.run_until(sim, "2011-06-09")  # 2011-06-08 is done, 06-09 is in progress
	var h: History = sim.data.history
	assert_eq(Readouts.date(sim), "2011-06-09")
	assert_eq(Readouts.price(sim), h.price_usd[h.index_of("2011-06-08")], "fog of time: today's close is unknown")
	assert_almost_eq(Readouts.change_24h(sim), h.price_usd[h.index_of("2011-06-08")] / h.price_usd[h.index_of("2011-06-07")] - 1.0, 1e-12)
	var spark := Readouts.sparkline(sim)
	assert_eq(spark.size(), Readouts.SPARKLINE_DAYS)
	assert_eq(spark[-1], Readouts.price(sim))


func test_btc_split_and_tooltip() -> void:
	var sim := H.game("cypherpunk")
	H.run_until(sim, "2010-08-01")
	sim.apply({"type": "transfer_btc", "from": "cold", "to": "exchange_tier1", "sats": 100_000_000})
	assert_eq(Readouts.moving_sats(sim), 100_000_000)
	assert_eq(Readouts.cold_sats(sim) + Readouts.exchange_sats(sim) + Readouts.moving_sats(sim), sim.custody.total_sats(sim.state))
	assert_string_contains(Readouts.btc_tooltip(sim), "Moving 1.00 BTC")


func test_hashrate_tooltip_shows_the_sum() -> void:
	var sim := H.game("cypherpunk")
	sim.step_day()
	assert_eq(Readouts.hashrate_hs(sim), 400000.0)
	assert_eq(Readouts.hashrate_tooltip(sim), "Your hashrate 400 kH/s = 1 x 800 kH/s x 50% uptime")
	assert_string_contains(Readouts.share_tooltip(sim), "yours 400 kH/s")


func test_machines_for_the_facility_view() -> void:
	var sim := H.game("cypherpunk")
	H.run_until(sim, "2010-10-02")
	sim.state.finance.cash_cents = 10_000_00
	sim.apply({"type": "buy_hardware", "unit_id": "gpu_card", "count": 2})
	var m: Array[Dictionary] = Readouts.machines(sim)
	assert_eq(m.size(), 2)
	assert_eq(m[0]["unit_id"], "cpu_laptop")
	assert_true(bool(m[1]["in_transit"]), "GPUs have a lead time")
	assert_eq(int(m[1]["tiles"]), 1)
	sim.step_day()
	assert_almost_eq(Readouts.running_w(sim), 35.0, 1e-9, "only the laptop runs while the cards ship")


func test_unit_stats_margin_and_breakeven() -> void:
	var sim := H.game("cypherpunk")
	H.run_until(sim, "2010-11-01")
	var s: Dictionary = Readouts.unit_stats(sim, "gpu_card")
	assert_almost_eq(s["margin_cents_day"], s["revenue_cents_day"] - s["power_cents_day"], 1e-6)
	assert_almost_eq(s["power_cents_day"], sim.power.unit_cost_cents_per_day(sim, "gpu_card"), 1e-9)
	# At the breakeven price the power cost equals the revenue.
	var site: Dictionary = sim.sites.site(sim.state)
	var kwh: float = s["watts"] * s["uptime"] * 24.0 / 1000.0 * float(site["pue"])
	assert_almost_eq(s["breakeven_usd_kwh"] * kwh * 100.0, s["revenue_cents_day"], 1e-6)
	assert_almost_eq(s["payback_days"], s["new_cents"] / s["margin_cents_day"], 1e-6)
	assert_string_contains(Readouts.unit_tooltip(sim, "gpu_card"), "Breakeven power price")


func test_hashprice_uses_the_last_close() -> void:
	var sim := H.game("late")
	H.run_until(sim, "2013-06-01")
	var n := sim.state.network
	var expected: float = Network.hashprice_sats_per_th_day(n) / 1.0e8 * Readouts.price(sim)
	assert_almost_eq(Readouts.hashprice(sim), expected, expected * 1e-9)


func test_network_countdowns() -> void:
	var sim := H.game("cypherpunk")
	H.run_until(sim, "2012-11-01")
	var n: Dictionary = Readouts.network(sim)
	assert_eq(int(n["blocks_to_halving"]), 210000 - int(n["height"]))
	assert_between(int(n["blocks_to_retarget"]), 1, 2016)
	assert_eq(n["subsidy_btc"], 50.0)


func test_sites_explain_why_they_are_closed() -> void:
	var sim := H.game("slashdot")
	var reasons: Dictionary = {}
	for s: Dictionary in Readouts.sites(sim):
		reasons[s["id"]] = s["blocked"]
	assert_eq(reasons["bedroom"], "you are here")
	assert_eq(reasons["garage"], "")
	assert_eq(reasons["warehouse"], "opens in act 2")


func test_exchanges_are_numbered_in_order() -> void:
	var sim := H.game("late")
	assert_eq(Readouts.exchange_label(sim, "exchange_tier1"), "Exchange 1")
	assert_eq(Readouts.exchange_label(sim, "exchange_tier4"), "Exchange 2")


func test_trades_are_logged_per_day_and_side() -> void:
	var sim := H.game("cypherpunk")
	H.run_until(sim, "2011-03-01")
	var ex: String = sim.state.custody.active_exchange
	sim.state.custody.exchange_sats[ex] = 1000 * 100000000
	sim.apply({"type": "sell_btc", "sats": 100000000})
	sim.apply({"type": "sell_btc", "sats": 200000000})
	sim.state.finance.cash_cents += 10000
	sim.apply({"type": "buy_btc", "cents": 10000})
	var trades: Array[SimState.Trade] = sim.state.market.trades
	assert_eq(trades.size(), 2)
	assert_eq(trades[0].side, "sell")
	assert_eq(trades[0].sats, 300000000)
	assert_eq(trades[1].side, "buy")


func test_codex_unlocks_persist_through_a_save() -> void:
	var sim := H.game("slashdot")
	H.run_until(sim, "2010-12-31")
	assert_true(sim.state.events.codex.has("mining"))
	assert_true(sim.state.events.codex.has("solo_vs_pool"))
	var again: Sim = load("res://autoload/save.gd").from_json(load("res://autoload/save.gd").to_json(sim))
	assert_eq(again.state.events.codex, sim.state.events.codex)
	assert_true(H.game("late").state.events.codex.has("halving") == false, "halving is unlocked on the halving day itself")
	assert_true(H.game("late").state.events.codex.has("custody"), "Late mode starts with past entries")
