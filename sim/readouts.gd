class_name Readouts
extends RefCounted
## Display-ready numbers and tooltip text for the UI (GDD 11.1: every number has a
## tooltip with its definition and the formula with live values). The UI shows these and
## never calculates economics itself.
##
## Fog of time: the day in progress is state.day_index. Its close is not known yet, so
## prices shown are the last completed day's. Trades placed now fill at today's close.

const SPARKLINE_DAYS: int = 30


static func date(sim: Sim) -> String:
	return sim.data.history.dates[mini(sim.state.day_index, sim.data.history.size() - 1)]


static func act(sim: Sim) -> int:
	return sim.state.objectives.act


## The most recent completed day with a price, or -1.
static func last_close_day(sim: Sim) -> int:
	var h: History = sim.data.history
	for i: int in range(mini(sim.state.day_index, h.size()) - 1, -1, -1):
		if h.has_price(i):
			return i
	return -1


static func price(sim: Sim) -> float:
	var i: int = last_close_day(sim)
	return sim.data.history.price_usd[i] if i >= 0 else NAN


## Change from the previous close to the last close.
static func change_24h(sim: Sim) -> float:
	var i: int = last_close_day(sim)
	if i < 1 or not sim.data.history.has_price(i - 1):
		return NAN
	return sim.data.history.price_usd[i] / sim.data.history.price_usd[i - 1] - 1.0


## Closes for the last SPARKLINE_DAYS completed days that have one, oldest first.
static func sparkline(sim: Sim, days: int = SPARKLINE_DAYS) -> PackedFloat64Array:
	var h: History = sim.data.history
	var out := PackedFloat64Array()
	var end: int = mini(sim.state.day_index, h.size())
	for i: int in range(maxi(0, end - days), end):
		if h.has_price(i):
			out.append(h.price_usd[i])
	return out


static func cash_cents(sim: Sim) -> int:
	return sim.state.finance.cash_cents


static func cold_sats(sim: Sim) -> int:
	return sim.state.custody.cold_sats


static func exchange_sats(sim: Sim) -> int:
	var total: int = 0
	for id: String in sim.state.custody.exchange_sats:
		total += sim.state.custody.exchange_sats[id]
	return total


static func moving_sats(sim: Sim) -> int:
	var total: int = 0
	for t: SimState.Transfer in sim.state.custody.transfers:
		total += t.sats
	return total


static func hashrate_hs(sim: Sim) -> float:
	return sim.state.player_hashrate_hs


static func share(sim: Sim) -> float:
	return sim.state.network.player_share


## One entry per lot for the facility view.
static func machines(sim: Sim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var hw: Hardware = sim.hardware
	var day: int = sim.state.day_index
	for lot: SimState.Lot in sim.state.hardware.lots:
		out.append({
			"lot_id": lot.id,
			"unit_id": lot.unit_id,
			"tier": hw.tier(lot.unit_id),
			"count": lot.count,
			"running": lot.running,
			"broken": lot.broken,
			"powered": lot.powered,
			"in_transit": lot.arrive_day > day,
			"tiles": footprint_tiles(sim, lot.unit_id),
		})
	return out


static func footprint_tiles(sim: Sim, unit_id: String) -> int:
	var table: Dictionary = sim.data.tuning("hardware", "footprint_tiles")
	return int(table.get(unit_id, table["default"]))


static func site_name(sim: Sim) -> String:
	return sim.state.hardware.site_id


static func capacity_w(sim: Sim) -> float:
	return sim.sites.capacity_w(sim.state)


## Wall power of the units running today, including GPU rig overhead.
static func running_w(sim: Sim) -> float:
	var w: float = 0.0
	for lot: SimState.Lot in sim.state.hardware.lots:
		w += lot.running * sim.hardware.unit_watts(lot.unit_id)
	return w


# ---------------------------------------------------------------- tooltips


static func date_tooltip(sim: Sim) -> String:
	return "Act %d, %s mode. Each tick is one game day." % [act(sim), sim.state.mode_id.capitalize()]


static func price_tooltip(sim: Sim) -> String:
	var i: int = last_close_day(sim)
	if i < 0:
		return "No market exists yet. Bitcoin has no price."
	var h: History = sim.data.history
	var text: String = "Last close %s on %s." % [Fmt.price(h.price_usd[i]), h.dates[i]]
	var c: float = change_24h(sim)
	if not is_nan(c):
		text += "\n24h change %s = %s / %s - 1" % [Fmt.signed_percent(c), Fmt.price(h.price_usd[i]), Fmt.price(h.price_usd[i - 1])]
	text += "\nToday's close is not known yet: trades fill at it."
	return text


static func cash_tooltip(sim: Sim) -> String:
	var f: SimState.FinanceState = sim.state.finance
	var text: String = "Cash %s." % Fmt.usd(f.cash_cents)
	if f.loan_balance_cents > 0:
		text += "\nLoan balance %s, %s a month." % [Fmt.usd(f.loan_balance_cents), Fmt.usd(f.loan_payment_cents)]
	return text


static func btc_tooltip(sim: Sim) -> String:
	var text: String = "Cold storage %s BTC: safe, a day to move.\nOn exchanges %s BTC: sellable now, lost if the exchange fails." % [
		Fmt.btc(cold_sats(sim)), Fmt.btc(exchange_sats(sim))]
	if moving_sats(sim) > 0:
		text += "\nMoving %s BTC." % Fmt.btc(moving_sats(sim))
	var p: float = price(sim)
	if not is_nan(p):
		var total: int = sim.custody.total_sats(sim.state)
		text += "\nWorth %s = %s BTC x %s" % [Fmt.usd(Finance.sats_to_cents(total, p, sim.consensus.sats_per_btc)), Fmt.btc(total), Fmt.price(p)]
	return text


static func hashrate_tooltip(sim: Sim) -> String:
	var parts: PackedStringArray = []
	for lot: SimState.Lot in sim.state.hardware.lots:
		if lot.running > 0:
			parts.append("%d x %s x %s uptime" % [lot.running, Fmt.hashrate(sim.hardware.unit_hashrate(sim.state, lot.unit_id)), Fmt.percent(sim.hardware.uptime_of(lot.unit_id), 0)])
	if parts.is_empty():
		return "Your hashrate: nothing is mining."
	return "Your hashrate %s = %s" % [Fmt.hashrate(hashrate_hs(sim)), " + ".join(parts)]


static func share_tooltip(sim: Sim) -> String:
	var n: SimState.NetworkState = sim.state.network
	return "Network share %s = yours %s / (world %s + yours)\nYou earn this share of the %d blocks found today." % [
		Fmt.percent(n.player_share, 4), Fmt.hashrate(n.player_hashrate_hs), Fmt.hashrate(n.world_hashrate_hs), n.blocks_today]


static func power_tooltip(sim: Sim) -> String:
	return "%s: %s of %s in use. Power today %s." % [
		site_name(sim).capitalize(), Fmt.watts(running_w(sim)), Fmt.watts(capacity_w(sim)), Fmt.usd(sim.state.hardware.power_cents_today)]
