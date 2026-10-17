class_name Custody
extends RefCounted
## Where the player's BTC sits: the cold wallet or an exchange (GDD 7.6). Exchange coins
## can be sold at once but are lost when the exchange fails; cold coins are safe but take
## a day to move. Not your keys, not your coins.

const COLD: String = "cold"

var to_exchange_days: int
var to_cold_days: int
var exchanges: Dictionary  # id -> {"opened_by": event id} or {"opened_on": ISO date}
var wallet_loss_enabled: bool
var wallet_loss_probability: float


func _init(data: GameData) -> void:
	to_exchange_days = int(data.tuning("market", "cold_to_exchange_days"))
	to_cold_days = int(data.tuning("market", "exchange_to_cold_days"))
	exchanges = data.tuning("market", "exchanges")
	wallet_loss_enabled = bool(data.tuning("market", "wallet_loss_enabled"))
	wallet_loss_probability = float(data.tuning("market", "wallet_loss_daily_probability"))


func is_open(sim: Sim, exchange_id: String) -> bool:
	if not exchanges.has(exchange_id) or sim.state.custody.closed_exchanges.has(exchange_id):
		return false
	var cfg: Dictionary = exchanges[exchange_id]
	if cfg.has("opened_by"):
		return sim.state.events.fired.has(cfg["opened_by"])
	return sim.current_date() >= String(cfg["opened_on"])


func open_exchanges(sim: Sim) -> PackedStringArray:
	var ids: PackedStringArray = []
	for id: String in exchanges:
		if is_open(sim, id):
			ids.append(id)
	ids.sort()
	return ids


func total_sats(state: SimState) -> int:
	var c: SimState.CustodyState = state.custody
	var total: int = c.cold_sats
	for id: String in c.exchange_sats:
		total += c.exchange_sats[id]
	for t: SimState.Transfer in c.transfers:
		total += t.sats
	return total


func exchange_balance(state: SimState, exchange_id: String) -> int:
	return state.custody.exchange_sats.get(exchange_id, 0)


## Mined coins go to the active exchange when the treasury policy sells, else to cold.
func deposit_mined(sim: Sim, sats: int) -> void:
	if sats <= 0:
		return
	var c: SimState.CustodyState = sim.state.custody
	if sim.state.market.policy != "hodl" and c.active_exchange != "":
		c.exchange_sats[c.active_exchange] = exchange_balance(sim.state, c.active_exchange) + sats
	else:
		c.cold_sats += sats


func set_active_exchange(sim: Sim, exchange_id: String) -> String:
	if not is_open(sim, exchange_id):
		return "exchange %s is not open" % exchange_id
	sim.state.custody.active_exchange = exchange_id
	return ""


func transfer(sim: Sim, origin: String, destination: String, sats: int) -> String:
	var c: SimState.CustodyState = sim.state.custody
	if sats <= 0:
		return "nothing to move"
	if origin == destination:
		return "same place"
	if origin != COLD and not is_open(sim, origin):
		return "exchange %s is not open" % origin
	if destination != COLD and not is_open(sim, destination):
		return "exchange %s is not open" % destination
	var available: int = c.cold_sats if origin == COLD else exchange_balance(sim.state, origin)
	if available < sats:
		return "not enough BTC"
	if origin == COLD:
		c.cold_sats -= sats
	else:
		c.exchange_sats[origin] = available - sats
	var t := SimState.Transfer.new()
	t.sats = sats
	t.origin = origin
	t.destination = destination
	# Moves requested before a day arrive at the end of it: a one-day move is there tomorrow.
	t.arrive_day = sim.state.day_index + (to_exchange_days if destination != COLD else to_cold_days) - 1
	c.transfers.append(t)
	return ""


func backup_wallet(sim: Sim) -> String:
	sim.state.custody.backed_up = true
	return ""


func step(sim: Sim, day: int, result: DayResult) -> void:
	var c: SimState.CustodyState = sim.state.custody
	if c.active_exchange == "" or not is_open(sim, c.active_exchange):
		var open: PackedStringArray = open_exchanges(sim)
		var chosen: String = open[0] if not open.is_empty() else ""
		if chosen != c.active_exchange:
			c.active_exchange = chosen
			if chosen != "":
				result.add("exchange_selected", {"exchange": chosen})
	var still_moving: Array[SimState.Transfer] = []
	for t: SimState.Transfer in c.transfers:
		if t.arrive_day > day:
			still_moving.append(t)
		elif t.destination == COLD:
			c.cold_sats += t.sats
		else:
			c.exchange_sats[t.destination] = exchange_balance(sim.state, t.destination) + t.sats
	c.transfers = still_moving
	if wallet_loss_enabled and not c.backed_up and c.cold_sats > 0:
		if sim.rng.uniform("custody") < wallet_loss_probability:
			result.add("wallet_lost", {"sats": c.cold_sats})
			c.cold_sats = 0


## An exchange failure (historical.json exchange_failure). The haircut applies to the
## balance and to coins in flight to or from it; a full haircut closes the exchange.
func exchange_failure(sim: Sim, exchange_id: String, haircut: float, result: DayResult) -> void:
	var c: SimState.CustodyState = sim.state.custody
	var balance: int = exchange_balance(sim.state, exchange_id)
	var lost: int = floori(balance * haircut)
	if c.exchange_sats.has(exchange_id):
		c.exchange_sats[exchange_id] = balance - lost
	for t: SimState.Transfer in c.transfers:
		if t.origin == exchange_id or t.destination == exchange_id:
			var cut: int = floori(t.sats * haircut)
			t.sats -= cut
			lost += cut
	if haircut >= 1.0:
		c.closed_exchanges.append(exchange_id)
		c.exchange_sats.erase(exchange_id)
	sim.state.objectives.exchange_losses_sats += lost
	result.add("exchange_failed", {"exchange": exchange_id, "lost_sats": lost})
