class_name Bot
extends RefCounted
## Base class for scripted players (GDD 14). A bot reads SimState freely but changes the
## game only through Sim.apply(), the same commands the UI uses. decide() runs once
## before each simulated day.
##
## Bot parameters are constants in each bot script: they are test strategy, not game
## tuning, so they stay out of data/tuning.

const SATS_PER_BTC: float = 1.0e8
const DAYS_PER_MONTH: float = 30.0

var name: String = "bot"


func decide(_sim: Sim) -> void:
	pass


# ---------------------------------------------------------------- reading the game


func today(sim: Sim) -> int:
	return sim.state.day_index


func price(sim: Sim) -> float:
	return sim.data.history.price_usd[today(sim)]


func has_price(sim: Sim) -> bool:
	return not is_nan(price(sim))


func btc_sats(sim: Sim) -> int:
	return sim.custody.total_sats(sim.state)


func btc_value_cents(sim: Sim) -> int:
	return Finance.sats_to_cents(btc_sats(sim), price(sim), sim.consensus.sats_per_btc)


func exchange_sats(sim: Sim) -> int:
	var ex: String = sim.state.custody.active_exchange
	return sim.custody.exchange_balance(sim.state, ex) if ex != "" else 0


func monthly_costs_cents(sim: Sim) -> float:
	return sim.treasury.daily_costs_cents(sim) * DAYS_PER_MONTH


## Expected daily margin of one unit at yesterday's network and today's close, in cents.
## NAN before BTC has a price.
func unit_margin_cents(sim: Sim, unit_id: String) -> float:
	var revenue_per_hs: float = sim.power.revenue_per_hs_day(sim, today(sim))
	if is_nan(revenue_per_hs):
		return NAN
	var hw: Hardware = sim.hardware
	var revenue: float = hw.unit_hashrate(sim.state, unit_id) * hw.uptime_of(unit_id) * revenue_per_hs * Finance.CENTS_PER_USD
	return revenue - sim.power.unit_cost_cents_per_day(sim, unit_id)


## The most efficient unit for sale today (lowest watts per hash), or "".
func best_unit(sim: Sim) -> String:
	var best: String = ""
	var best_j: float = INF
	for unit_id: String in sim.hardware.units:
		if not sim.hardware.is_available(sim, unit_id):
			continue
		var j: float = sim.hardware.unit_watts(unit_id) / sim.hardware.unit_hashrate(sim.state, unit_id)
		if j < best_j:
			best_j = j
			best = unit_id
	return best


## Site capacity not yet claimed by owned or ordered working units.
func free_watts(sim: Sim) -> float:
	var free: float = sim.sites.capacity_w(sim.state)
	for lot: SimState.Lot in sim.state.hardware.lots:
		if lot.powered:
			free -= (lot.count - lot.broken) * sim.hardware.unit_watts(lot.unit_id)
	return free


func payback_days(sim: Sim, unit_id: String) -> float:
	var margin: float = unit_margin_cents(sim, unit_id)
	if is_nan(margin) or margin <= 0.0:
		return INF
	return sim.hardware.quote_cents(sim, unit_id, 1, false) / margin


# ---------------------------------------------------------------- acting


## Buys as many new units as the budget and the site's free power allow. Returns the count.
func buy_up_to(sim: Sim, unit_id: String, budget_cents: int) -> int:
	var n: int = mini(floori(free_watts(sim) / sim.hardware.unit_watts(unit_id)), floori(budget_cents / maxf(1.0, sim.hardware.quote_cents(sim, unit_id, 1, false))))
	while n > 0 and sim.hardware.quote_cents(sim, unit_id, n, false) > mini(budget_cents, sim.state.finance.cash_cents):
		n -= 1
	if n > 0 and sim.apply({"type": "buy_hardware", "unit_id": unit_id, "count": n})["ok"]:
		return n
	return 0


## Sells exchange BTC for cash now; if the exchange holds too little, starts moving cold
## coins there (they arrive tomorrow). Returns cents raised today.
func raise_cash(sim: Sim, cents: int) -> int:
	if cents <= 0 or not has_price(sim) or sim.market.trade_block_reason(sim) != "":
		return 0
	var needed_sats: int = ceili(cents / Finance.CENTS_PER_USD / price(sim) * SATS_PER_BTC * 1.05)
	var sats: int = mini(needed_sats, sim.market.max_sell_sats(sim))
	var raised: int = 0
	if sats > 0:
		raised = int(sim.apply({"type": "sell_btc", "sats": sats}).get("proceeds_cents", 0))
	var short_sats: int = needed_sats - sats
	if short_sats > 0 and sim.state.custody.cold_sats > 0 and _in_flight(sim) == 0:
		sim.apply({"type": "transfer_btc", "from": "cold", "to": sim.state.custody.active_exchange,
			"sats": mini(short_sats, sim.state.custody.cold_sats)})
	return raised


## Moves exchange coins above keep_sats back to the cold wallet.
func sweep_to_cold(sim: Sim, keep_sats: int = 0) -> void:
	var ex: String = sim.state.custody.active_exchange
	var extra: int = exchange_sats(sim) - keep_sats
	if ex != "" and extra > 0:
		sim.apply({"type": "transfer_btc", "from": ex, "to": "cold", "sats": extra})


func _in_flight(sim: Sim) -> int:
	var total: int = 0
	for t: SimState.Transfer in sim.state.custody.transfers:
		total += t.sats
	return total


func use_pool_when_possible(sim: Sim) -> void:
	if sim.state.mining.mode == "solo" and sim.state.events.features.has("pool_mining"):
		sim.apply({"type": "set_mining_mode", "mode": "pool"})


func decline_offers(sim: Sim) -> void:
	for offer: SimState.Offer in sim.state.offers.open.duplicate():
		sim.apply({"type": "decline_offer", "id": offer.id})
