extends GutTest

const H = preload("res://tests/sim_helpers.gd")
const BTC: int = 100000000


## A Cypherpunk game on date with coins on the active exchange.
func _with_coins_on_exchange(iso_date: String, sats: int) -> Sim:
	var sim := H.game("cypherpunk")
	H.run_until(sim, iso_date)
	var ex: String = sim.state.custody.active_exchange
	sim.state.custody.exchange_sats[ex] = sim.custody.exchange_balance(sim.state, ex) + sats
	return sim


func test_no_selling_before_the_first_exchange() -> void:
	var sim := H.game("cypherpunk")
	H.run_until(sim, "2010-07-01")
	assert_eq(sim.market.trade_block_reason(sim), "No market exists yet.")
	H.run_until(sim, "2010-07-19")
	assert_eq(sim.state.custody.active_exchange, "exchange_tier1")
	assert_eq(sim.market.trade_block_reason(sim), "")


func test_sell_cap_is_a_share_of_real_volume() -> void:
	var sim := _with_coins_on_exchange("2011-06-08", 1_000_000 * BTC)
	var cap: int = floori(sim.market.volume_sats(sim, sim.state.day_index) * sim.market.cap_fraction)
	assert_eq(sim.market.max_sell_sats(sim), cap)
	assert_false(sim.apply({"type": "sell_btc", "sats": cap + 1})["ok"])
	assert_true(sim.apply({"type": "sell_btc", "sats": cap})["ok"])
	assert_eq(sim.market.max_sell_sats(sim), 0, "nothing left today")
	sim.step_day()
	assert_gt(sim.market.max_sell_sats(sim), 0, "the cap resets daily")


func test_fill_includes_slippage_and_fee() -> void:
	var sim := _with_coins_on_exchange("2011-06-08", 100_000 * BTC)
	var day: int = sim.state.day_index
	var vol: float = sim.market.volume_sats(sim, day)
	var sats: int = floori(vol * 0.05)
	var close: float = sim.market.price(sim, day)
	var cash: int = sim.state.finance.cash_cents
	var r: Dictionary = sim.apply({"type": "sell_btc", "sats": sats})
	var share: float = sats / vol
	var expected_fill: float = close * (1.0 - sim.market.slippage * share / 2.0)
	assert_almost_eq(float(r["fill_usd"]), expected_fill, 1e-9)
	assert_eq(sim.state.finance.cash_cents - cash, roundi(sats / 1.0e8 * expected_fill * (1.0 - sim.market.fee) * 100.0))


func test_buy_spends_cash_for_coins() -> void:
	var sim := _with_coins_on_exchange("2012-01-10", 0)
	sim.state.finance.cash_cents = 100_000
	var r: Dictionary = sim.apply({"type": "buy_btc", "cents": 100_000})
	assert_true(r["ok"])
	assert_eq(sim.state.finance.cash_cents, 0)
	assert_gt(r["sats"], 0)


func test_cold_to_exchange_takes_a_day() -> void:
	var sim := H.game("cypherpunk")
	H.run_until(sim, "2010-08-01")
	var cold: int = sim.state.custody.cold_sats
	assert_true(sim.apply({"type": "transfer_btc", "from": "cold", "to": "exchange_tier1", "sats": 1000 * BTC})["ok"])
	assert_eq(sim.state.custody.cold_sats, cold - 1000 * BTC)
	assert_eq(sim.custody.exchange_balance(sim.state, "exchange_tier1"), 0, "in flight")
	sim.step_day()
	assert_eq(sim.custody.exchange_balance(sim.state, "exchange_tier1"), 1000 * BTC)


func test_mt_gox_failure_takes_exchange_coins_only() -> void:
	var sim := _with_coins_on_exchange("2014-02-01", 500 * BTC)
	var cold: int = sim.state.custody.cold_sats
	var events: Array[Dictionary] = H.run_until(sim, "2014-02-08")
	var failed: Array[Dictionary] = H.of_type(events, "exchange_failed")
	assert_eq(failed.size(), 1)
	assert_eq(failed[0]["exchange"], "exchange_tier1")
	assert_gte(int(failed[0]["lost_sats"]), 500 * BTC)
	assert_gte(sim.state.custody.cold_sats, cold, "cold coins untouched")
	assert_false(sim.custody.is_open(sim, "exchange_tier1"))
	assert_eq(sim.state.custody.active_exchange, "exchange_tier4", "the survivor takes over")


func test_partial_haircut_keeps_the_exchange_open() -> void:
	var sim := _with_coins_on_exchange("2012-01-10", 100 * BTC)
	var ex: String = sim.state.custody.active_exchange
	var before: int = sim.custody.exchange_balance(sim.state, ex)
	sim.custody.exchange_failure(sim, ex, 0.36067, DayResult.new(0, ""))
	assert_eq(sim.custody.exchange_balance(sim.state, ex), before - floori(before * 0.36067))
	assert_true(sim.custody.is_open(sim, ex))


func test_survivor_exchange_opens_in_august_2011() -> void:
	var sim := H.game("cypherpunk")
	H.run_until(sim, "2011-08-17")
	assert_false(sim.custody.is_open(sim, "exchange_tier4"))
	H.run_until(sim, "2011-08-18")
	assert_true(sim.custody.is_open(sim, "exchange_tier4"))


func test_hodl_mines_to_cold_and_selling_policies_mine_to_the_exchange() -> void:
	var sim := H.game("cypherpunk")
	H.run_until(sim, "2010-12-17")
	sim.apply({"type": "set_mining_mode", "mode": "pool"})
	sim.step_day()
	assert_eq(sim.custody.exchange_balance(sim.state, "exchange_tier1"), 0)
	sim.apply({"type": "set_treasury_policy", "policy": "sell_percent", "percent": 0.5})
	sim.step_day()
	var mined: int = sim.state.mining.mined_sats_today
	assert_gt(mined, 0)
	assert_eq(sim.custody.exchange_balance(sim.state, "exchange_tier1"), mined - floori(mined * 0.5))


func test_cover_costs_keeps_a_cash_buffer() -> void:
	var sim := _with_coins_on_exchange("2012-01-10", 10_000 * BTC)
	sim.state.finance.cash_cents = 0
	sim.apply({"type": "set_treasury_policy", "policy": "cover_costs"})
	sim.step_day()
	assert_gt(sim.state.finance.cash_cents, 0)


func test_wallet_loss_needs_the_flag_and_no_backup() -> void:
	var sim := H.game("cypherpunk")
	sim.custody.wallet_loss_enabled = true
	sim.custody.wallet_loss_probability = 1.0
	sim.apply({"type": "backup_wallet"})
	H.run_until(sim, "2009-03-01")
	assert_gt(sim.state.custody.cold_sats, 0, "backed up")
	sim.state.custody.backed_up = false
	var cold: int = sim.state.custody.cold_sats
	var lost: Array[Dictionary] = sim.step_day().of_type("wallet_lost")
	assert_eq(lost.size(), 1)
	assert_gte(int(lost[0]["sats"]), cold)
