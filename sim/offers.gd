class_name Offers
extends RefCounted
## Forum trade offers and the pizza offer (decisions.md 2026-10-16). Accepting spends BTC
## on goods the player would have bought anyway, so it saves that much cash. The regret
## counter is the BTC spent, valued at today's close.

var mean_days: float
var value_range: Array  # [low, high] USD
var expiry_days: int
var pizza_sats: int
var pizza_value_cents: int
var pizza_milestone_cents: int


func _init(data: GameData) -> void:
	mean_days = float(data.tuning("offers", "mean_days_between_offers"))
	value_range = data.tuning("offers", "offer_value_usd")
	expiry_days = int(data.tuning("offers", "offer_expiry_days"))
	pizza_sats = roundi(float(data.tuning("offers", "pizza_btc")) * data.protocol_int("sats_per_btc"))
	pizza_value_cents = Finance.usd_to_cents(data.tuning("offers", "pizza_value_usd"))
	pizza_milestone_cents = Finance.usd_to_cents(data.tuning("offers", "pizza_milestone_usd"))


func step(sim: Sim, day: int, result: DayResult) -> void:
	var o: SimState.OffersState = sim.state.offers
	var keep: Array[SimState.Offer] = []
	for offer: SimState.Offer in o.open:
		if offer.expires_day < day:
			result.add("offer_expired", {"id": offer.id})
		else:
			keep.append(offer)
	o.open = keep
	var close: float = sim.data.history.price_usd[day]
	_check_pizza_milestone(sim, close, result)
	if not sim.state.events.features.has("mining") or is_nan(close):
		return
	if o.next_offer_day < 0:
		o.next_offer_day = day + _gap(sim)
	if day < o.next_offer_day:
		return
	var low: float = float(value_range[0])
	var usd: float = low + sim.rng.uniform("offers") * (float(value_range[1]) - low)
	var cents: int = Finance.usd_to_cents(usd)
	var sats: int = roundi(usd / close * sim.consensus.sats_per_btc)
	_add(sim, "forum", sats, cents, day, result)
	o.next_offer_day = day + _gap(sim)


## The first close at which the 10,000 pizza BTC are worth the milestone: the game replays
## their climb (decisions.md 2026-10-17). Once per game, in every mode.
func _check_pizza_milestone(sim: Sim, close: float, result: DayResult) -> void:
	var o: SimState.OffersState = sim.state.offers
	if o.pizza_milestone_seen or is_nan(close):
		return
	var cents: int = Finance.sats_to_cents(pizza_sats, close, sim.consensus.sats_per_btc)
	if cents >= pizza_milestone_cents:
		o.pizza_milestone_seen = true
		result.add("pizza_milestone", {"value_cents": cents, "sats": pizza_sats})


func _gap(sim: Sim) -> int:
	return maxi(1, roundi(-log(1.0 - sim.rng.uniform("offers") * 0.999999) * mean_days))


## The pizza_day event: offered only to a player who holds the coins.
func offer_pizza(sim: Sim, result: DayResult) -> void:
	if sim.custody.total_sats(sim.state) >= pizza_sats:
		_add(sim, "pizza", pizza_sats, pizza_value_cents, sim.state.day_index, result)


func _add(sim: Sim, kind: String, sats: int, cents: int, day: int, result: DayResult) -> void:
	var o: SimState.OffersState = sim.state.offers
	var offer := SimState.Offer.new()
	offer.id = o.next_id
	o.next_id += 1
	offer.kind = kind
	offer.sats = sats
	offer.value_cents = cents
	offer.expires_day = day + expiry_days
	o.open.append(offer)
	result.add("offer_made", {"id": offer.id, "kind": kind, "sats": sats, "value_cents": cents})


func _find(state: SimState, id: int) -> SimState.Offer:
	for offer: SimState.Offer in state.offers.open:
		if offer.id == id:
			return offer
	return null


## Pays from the cold wallet first, then the active exchange.
func accept(sim: Sim, id: int) -> String:
	var state: SimState = sim.state
	var offer := _find(state, id)
	if offer == null:
		return "no such offer"
	var c: SimState.CustodyState = state.custody
	var ex: String = c.active_exchange
	var on_exchange: int = sim.custody.exchange_balance(state, ex) if ex != "" else 0
	if c.cold_sats + on_exchange < offer.sats:
		return "not enough BTC"
	var from_cold: int = mini(c.cold_sats, offer.sats)
	c.cold_sats -= from_cold
	if offer.sats > from_cold:
		c.exchange_sats[ex] = on_exchange - (offer.sats - from_cold)
	Finance.credit(state, offer.value_cents, "trade_savings")
	state.offers.spent_sats += offer.sats
	state.offers.decided += 1
	state.offers.open.erase(offer)
	return ""


func decline(sim: Sim, id: int) -> String:
	var offer := _find(sim.state, id)
	if offer == null:
		return "no such offer"
	sim.state.offers.decided += 1
	sim.state.offers.open.erase(offer)
	return ""


func regret_cents(sim: Sim, day: int) -> int:
	return Finance.sats_to_cents(sim.state.offers.spent_sats, sim.data.history.price_usd[day], sim.consensus.sats_per_btc)
