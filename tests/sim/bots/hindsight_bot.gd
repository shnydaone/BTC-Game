class_name HindsightBot
extends SensibleBot
## GDD 14 Hindsight: knows the future and sells tops. It defines the score ceiling.
##
## Plays like Sensible, but reads future prices from the history up to the day it is
## scored (an explicit oracle no other bot uses):
## - Values mined coins at the best close still to come, so it buys hashrate even before
##   BTC has a price, and never sells coins to buy hardware.
## - Sells when the price will fall by half before it is seen again, and buys back near
##   the bottom before the next rally.
## - Trades on the exchange that survives instead of the one that fails.

const SCORED_ON: String = "2016-07-09"  # Act 2's report card
const SELL_IF_DROP_AHEAD: float = 2.0  # today's close is at least twice a later low before it returns
const BUY_BEFORE_RALLY: float = 1.5  # the next rally to buy ahead of
const NEAR_BOTTOM: float = 1.15  # within 15% of the low before that rally
const SURVIVOR_EXCHANGE: String = "exchange_tier4"
const BUY_FRACTION_OF_SPARE_CASH: float = 0.9

var _sell_days: PackedByteArray = []
var _buy_days: PackedByteArray = []
var _best_ahead: PackedFloat64Array = []  # best close from day i through scoring


func _init() -> void:
	name = "hindsight"
	stack_spend_fraction = 0.0
	buffer_months = 0.5  # it knows it can always sell coins later
	review_every_days = 1


func decide(sim: Sim) -> void:
	if _best_ahead.is_empty():
		_build_oracle(sim.data.history)
	if sim.custody.is_open(sim, SURVIVOR_EXCHANGE) and sim.state.custody.active_exchange != SURVIVOR_EXCHANGE:
		var old: String = sim.state.custody.active_exchange
		if old != "" and exchange_sats(sim) > 0:
			sim.apply({"type": "transfer_btc", "from": old, "to": "cold", "sats": exchange_sats(sim)})
		sim.apply({"type": "set_exchange", "exchange": SURVIVOR_EXCHANGE})
	super.decide(sim)
	var day: int = today(sim)
	if day >= _best_ahead.size() or not has_price(sim) or sim.market.trade_block_reason(sim) != "":
		return
	if _sell_days[day] == 1:
		if sim.state.custody.cold_sats > 0:
			sim.apply({"type": "transfer_btc", "from": "cold", "to": sim.state.custody.active_exchange, "sats": sim.state.custody.cold_sats})
		var sats: int = sim.market.max_sell_sats(sim)
		if sats > 0:
			sim.apply({"type": "sell_btc", "sats": sats})
	elif _buy_days[day] == 1:
		var spare: int = sim.state.finance.cash_cents - roundi(buffer_cents(sim))
		var cents: int = mini(roundi(spare * BUY_FRACTION_OF_SPARE_CASH), sim.market.max_buy_cents(sim))
		if cents > 0:
			sim.apply({"type": "buy_btc", "cents": cents})


## Mined coins are worth the best close still to come.
func unit_margin_cents(sim: Sim, unit_id: String) -> float:
	var day: int = today(sim)
	var n: SimState.NetworkState = sim.state.network
	if day >= _best_ahead.size() or _best_ahead[day] <= 0.0 or n.network_hashrate_hs <= 0.0:
		return super.unit_margin_cents(sim, unit_id)
	var revenue_per_hs: float = float(n.subsidy_sats_today + n.fees_sats_today) / sim.consensus.sats_per_btc * _best_ahead[day] / n.network_hashrate_hs
	var hw: Hardware = sim.hardware
	var revenue: float = hw.unit_hashrate(sim.state, unit_id) * hw.uptime_of(unit_id) * revenue_per_hs * Finance.CENTS_PER_USD
	return revenue - sim.power.unit_cost_cents_per_day(sim, unit_id)


func _build_oracle(h: History) -> void:
	var last: int = h.index_of(SCORED_ON)
	var p := PackedFloat64Array()
	p.resize(last + 1)
	var carried: float = 0.0
	for i: int in last + 1:
		if h.has_price(i):
			carried = h.price_usd[i]
		p[i] = carried
	_best_ahead.resize(last + 1)
	var best: float = 0.0
	for i: int in range(last, -1, -1):
		best = maxf(best, p[i])
		_best_ahead[i] = best
	_sell_days.resize(last + 1)
	_buy_days.resize(last + 1)
	for i: int in last + 1:
		_sell_days[i] = 0
		_buy_days[i] = 0
		if p[i] <= 0.0:
			continue
		# Lowest close before the price first tops today again (or scoring).
		var low: float = p[i]
		for j: int in range(i + 1, last + 1):
			if p[j] > p[i]:
				break
			low = minf(low, p[j])
		if p[i] >= SELL_IF_DROP_AHEAD * low:
			_sell_days[i] = 1
			continue
		# Lowest close before the next rally to 1.5x today (or scoring).
		var floor_ahead: float = p[i]
		for j: int in range(i + 1, last + 1):
			if p[j] >= BUY_BEFORE_RALLY * p[i]:
				break
			floor_ahead = minf(floor_ahead, p[j])
		if p[i] <= NEAR_BOTTOM * floor_ahead:
			_buy_days[i] = 1


## Keeps coins where they are: the oracle decides when to sell, and the survivor
## exchange is safe.
func _manage_cash(sim: Sim) -> void:
	var short: int = roundi(buffer_cents(sim)) - sim.state.finance.cash_cents
	if short > 0:
		raise_cash(sim, short)
