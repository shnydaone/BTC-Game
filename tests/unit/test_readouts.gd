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
