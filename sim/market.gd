class_name Market
extends RefCounted
## Buying and selling BTC on the active exchange at the historical close (GDD 7.5).
##
## Liquidity is honest: each day the player can trade at most a share of that day's
## real exchange volume, and the fill moves against them with the share traded. The
## historical price itself never moves (fog of time).

var cap_fraction: float
var slippage: float
var fee: float
var crash_window: Array  # [from, to] ISO dates for the Act 1 bonus


func _init(data: GameData) -> void:
	cap_fraction = float(data.tuning("market", "sell_cap_fraction_of_volume"))
	slippage = float(data.tuning("market", "slippage_per_volume_share"))
	fee = float(data.tuning("market", "exchange_fee"))
	crash_window = data.tuning("objectives", "crash_2011_window")


func price(sim: Sim, day: int) -> float:
	return sim.data.history.price_usd[day]


func volume_sats(sim: Sim, day: int) -> int:
	return roundi(sim.data.history.volume_btc[day] * sim.consensus.sats_per_btc)


func trade_block_reason(sim: Sim) -> String:
	var day: int = sim.state.day_index
	if not sim.state.events.features.has("selling"):
		return "No market exists yet."
	if sim.state.custody.active_exchange == "":
		return "no exchange is open"
	if is_nan(price(sim, day)) or volume_sats(sim, day) <= 0:
		return "no trading today"
	return ""


## The most the player can still sell today: balance on the active exchange within the cap.
func max_sell_sats(sim: Sim) -> int:
	if trade_block_reason(sim) != "":
		return 0
	var cap: int = floori(volume_sats(sim, sim.state.day_index) * cap_fraction)
	var balance: int = sim.custody.exchange_balance(sim.state, sim.state.custody.active_exchange)
	return maxi(0, mini(balance, cap - sim.state.market.sold_today_sats))


## The most the player can still buy today within the cap, in sats.
func max_buy_sats(sim: Sim) -> int:
	if trade_block_reason(sim) != "":
		return 0
	return maxi(0, floori(volume_sats(sim, sim.state.day_index) * cap_fraction) - sim.state.market.bought_today_sats)


## Cash that buys about max_buy_sats today, allowing for the fee and the worst slippage.
func max_buy_cents(sim: Sim) -> int:
	var sats: int = max_buy_sats(sim)
	var close: float = price(sim, sim.state.day_index)
	if sats <= 0 or is_nan(close):
		return 0
	return floori(float(sats) / sim.consensus.sats_per_btc * close * (1.0 - slippage * cap_fraction) * (1.0 - fee) * Finance.CENTS_PER_USD)


## Average fill for a trade that takes the day's traded share from s0 to s1.
func _fill_price(close: float, s0: float, s1: float, selling: bool) -> float:
	var impact: float = slippage * (s0 + s1) / 2.0
	return close * (1.0 - impact) if selling else close * (1.0 + impact)


func sell(sim: Sim, sats: int) -> Dictionary:
	var reason: String = trade_block_reason(sim)
	if reason == "" and sats > max_sell_sats(sim):
		reason = "over today's limit of %d sats" % max_sell_sats(sim)
	if reason == "" and sats <= 0:
		reason = "nothing to sell"
	if reason != "":
		return {"ok": false, "reason": reason}
	var state: SimState = sim.state
	var day: int = state.day_index
	var vol: float = float(volume_sats(sim, day))
	var fill: float = _fill_price(price(sim, day), state.market.sold_today_sats / vol, (state.market.sold_today_sats + sats) / vol, true)
	var proceeds: int = roundi(float(sats) / sim.consensus.sats_per_btc * fill * (1.0 - fee) * Finance.CENTS_PER_USD)
	var ex: String = state.custody.active_exchange
	state.custody.exchange_sats[ex] = sim.custody.exchange_balance(state, ex) - sats
	state.market.sold_today_sats += sats
	_log_trade(state, "sell", sats, proceeds)
	state.finance.cash_cents += proceeds
	var today: String = sim.current_date()
	if today >= String(crash_window[0]) and today <= String(crash_window[1]):
		state.objectives.crash_sold = true
	return {"ok": true, "reason": "", "proceeds_cents": proceeds, "fill_usd": fill}


func buy(sim: Sim, cents: int) -> Dictionary:
	var reason: String = trade_block_reason(sim)
	var state: SimState = sim.state
	if reason == "" and (cents <= 0 or cents > state.finance.cash_cents):
		reason = "not enough cash"
	if reason != "":
		return {"ok": false, "reason": reason}
	var day: int = state.day_index
	var vol: float = float(volume_sats(sim, day))
	var close: float = price(sim, day)
	# Size the order at the close, then price it with slippage.
	var sats: int = floori(cents / Finance.CENTS_PER_USD * (1.0 - fee) / close * sim.consensus.sats_per_btc)
	var cap: int = floori(vol * cap_fraction) - state.market.bought_today_sats
	if sats > cap:
		return {"ok": false, "reason": "over today's limit of %d sats" % maxi(cap, 0)}
	var fill: float = _fill_price(close, state.market.bought_today_sats / vol, (state.market.bought_today_sats + sats) / vol, false)
	sats = floori(cents / Finance.CENTS_PER_USD * (1.0 - fee) / fill * sim.consensus.sats_per_btc)
	var ex: String = state.custody.active_exchange
	state.custody.exchange_sats[ex] = sim.custody.exchange_balance(state, ex) + sats
	state.market.bought_today_sats += sats
	_log_trade(state, "buy", sats, cents)
	state.finance.cash_cents -= cents
	return {"ok": true, "reason": "", "sats": sats, "fill_usd": fill}


## Adds to today's entry for this side, or starts one.
func _log_trade(state: SimState, side: String, sats: int, cents: int) -> void:
	var trades: Array[SimState.Trade] = state.market.trades
	if not trades.is_empty() and trades[-1].day == state.day_index and trades[-1].side == side:
		trades[-1].sats += sats
		trades[-1].cents += cents
		return
	var t := SimState.Trade.new()
	t.day = state.day_index
	t.side = side
	t.sats = sats
	t.cents = cents
	trades.append(t)


func start_day(state: SimState) -> void:
	state.market.sold_today_sats = 0
	state.market.bought_today_sats = 0
