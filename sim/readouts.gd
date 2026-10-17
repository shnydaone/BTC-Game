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


# ---------------------------------------------------------------- names (placeholders until M3-4)


static func unit_label(sim: Sim, unit_id: String) -> String:
	var tier: String = sim.hardware.tier(unit_id)
	match tier:
		"CPU":
			return unit_id.trim_prefix("cpu_").capitalize()
		"GPU":
			return "GPU card"
		"FPGA":
			return "FPGA board"
	return tier


## Exchanges are numbered in opening order; parody names arrive in M3-4.
static func exchange_label(sim: Sim, exchange_id: String) -> String:
	var ids: Array = sim.custody.exchanges.keys()
	ids.sort()
	return "Exchange %d" % (ids.find(exchange_id) + 1)


static func codex_title(entry: String) -> String:
	return entry.capitalize()


# ---------------------------------------------------------------- mining economics


## USD earned per H/s per day at the last completed day's rewards and close. NAN without a price.
static func revenue_per_hs_day(sim: Sim) -> float:
	var n: SimState.NetworkState = sim.state.network
	var p: float = price(sim)
	if is_nan(p) or n.network_hashrate_hs <= 0.0:
		return NAN
	return float(n.subsidy_sats_today + n.fees_sats_today) / sim.consensus.sats_per_btc * p / n.network_hashrate_hs


## Hashprice, the miner's key number: USD per TH/s per day.
static func hashprice(sim: Sim) -> float:
	var r: float = revenue_per_hs_day(sim)
	return NAN if is_nan(r) else r * 1.0e12


static func hashprice_tooltip(sim: Sim) -> String:
	var n: SimState.NetworkState = sim.state.network
	if is_nan(hashprice(sim)):
		return "Hashprice: USD a miner earns per TH/s per day. No price yet."
	return "Hashprice %s/TH/day = (%s subsidy + %s fees) BTC x %s
/ network %s, counted in TH/s" % [
		Fmt.price(hashprice(sim)), Fmt.btc(n.subsidy_sats_today), Fmt.btc(n.fees_sats_today), Fmt.price(price(sim)),
		Fmt.hashrate(n.network_hashrate_hs)]


## Everything the shop and fleet rows need about one model.
static func unit_stats(sim: Sim, unit_id: String) -> Dictionary:
	var hw: Hardware = sim.hardware
	var hs: float = hw.unit_hashrate(sim.state, unit_id)
	var w: float = hw.unit_watts(unit_id)
	var up: float = hw.uptime_of(unit_id)
	var power_cents: float = sim.power.unit_cost_cents_per_day(sim, unit_id)
	var r: float = revenue_per_hs_day(sim)
	var revenue_cents: float = NAN if is_nan(r) else hs * up * r * Finance.CENTS_PER_USD
	var margin: float = NAN if is_nan(revenue_cents) else revenue_cents - power_cents
	var site: Dictionary = sim.sites.site(sim.state)
	var kwh_per_day: float = w * up * Power.HOURS_PER_DAY / Sites.WATTS_PER_KW * float(site["pue"])
	var new_price: int = hw.quote_cents(sim, unit_id, 1, false) if hw.base_price_cents(unit_id) > 0 else -1
	return {
		"label": unit_label(sim, unit_id),
		"tier": hw.tier(unit_id),
		"hashrate_hs": hs,
		"watts": w,
		"j_per_th": w / (hs / 1.0e12),
		"uptime": up,
		"revenue_cents_day": revenue_cents,
		"power_cents_day": power_cents,
		"margin_cents_day": margin,
		"breakeven_usd_kwh": NAN if is_nan(revenue_cents) else revenue_cents / Finance.CENTS_PER_USD / kwh_per_day,
		"new_cents": new_price,
		"used_cents": hw.quote_cents(sim, unit_id, 1, true) if new_price > 0 else -1,
		"payback_days": INF if is_nan(margin) or margin <= 0.0 or new_price <= 0 else new_price / margin,
		"lead_days": hw.lead_time(unit_id),
		"available": hw.is_available(sim, unit_id),
	}


static func unit_tooltip(sim: Sim, unit_id: String) -> String:
	var s: Dictionary = unit_stats(sim, unit_id)
	var text: String = "%s: %s at %s (%s J/TH), %s uptime." % [s["label"], Fmt.hashrate(s["hashrate_hs"]), Fmt.watts(s["watts"]), Fmt.thousands(roundi(s["j_per_th"])), Fmt.percent(s["uptime"], 0)]
	if is_nan(s["margin_cents_day"]):
		return text + "\nNo price yet, so no margin."
	text += "\nMargin %s/day = revenue %s - power %s" % [Fmt.usd(roundi(s["margin_cents_day"])), Fmt.usd(roundi(s["revenue_cents_day"])), Fmt.usd(roundi(s["power_cents_day"]))]
	text += "\nBreakeven power price %s/kWh at this site." % Fmt.price(s["breakeven_usd_kwh"])
	if s["payback_days"] < INF:
		text += "\nPays back a new unit in %d days at today's numbers." % ceili(s["payback_days"])
	return text


static func shop(sim: Sim) -> Array[String]:
	var out: Array[String] = []
	for unit_id: String in sim.hardware.units:
		if sim.hardware.is_available(sim, unit_id):
			out.append(unit_id)
	return out


## The fleet, one row per lot, with sale value and today's state.
static func fleet(sim: Sim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var day: int = sim.state.day_index
	for lot: SimState.Lot in sim.state.hardware.lots:
		out.append({
			"lot_id": lot.id,
			"unit_id": lot.unit_id,
			"label": unit_label(sim, lot.unit_id),
			"count": lot.count,
			"running": lot.running,
			"broken": lot.broken,
			"powered": lot.powered,
			"arrives": sim.data.history.dates[mini(lot.arrive_day, sim.data.history.size() - 1)] if lot.arrive_day > day else "",
			"book_cents": sim.hardware.book_value_lot_cents(lot, day),
			"sale_cents": sim.hardware.used_price_cents(lot.unit_id, day - lot.bought_day, day),
		})
	return out


# ---------------------------------------------------------------- network


static func network(sim: Sim) -> Dictionary:
	var n: SimState.NetworkState = sim.state.network
	var c: Consensus = sim.consensus
	var next_retarget: int = (n.height / c.retarget_interval + 1) * c.retarget_interval
	var next_halving: int = (c.halvings_at(n.height) + 1) * c.halving_interval
	return {
		"world_hs": n.world_hashrate_hs,
		"difficulty": n.effective_difficulty,
		"height": n.height,
		"blocks_today": n.blocks_today,
		"subsidy_btc": c.subsidy_sats(n.height) / float(c.sats_per_btc),
		"blocks_to_retarget": next_retarget - n.height,
		"blocks_to_halving": next_halving - n.height,
	}


# ---------------------------------------------------------------- sites


static func sites(sim: Sim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in sim.sites.sites:
		var cfg: Dictionary = sim.sites.sites[id]
		var reason: String = ""
		if id == sim.state.hardware.site_id:
			reason = "you are here"
		elif sim.state.objectives.act < int(cfg["available_act"]):
			reason = "opens in act %d" % int(cfg["available_act"])
		elif bool(cfg["requires_incorporation"]) and not sim.state.finance.incorporated:
			reason = "needs a company"
		out.append({
			"id": id,
			"capacity_w": float(cfg["capacity_kw"]) * Sites.WATTS_PER_KW,
			"usd_per_kwh": float(cfg["power_usd_per_kwh"]),
			"pue": float(cfg["pue"]),
			"rent_cents": Finance.usd_to_cents(cfg["rent_usd_month"]),
			"move_cents": Finance.usd_to_cents(cfg["move_cost_usd"]),
			"blocked": reason,
		})
	return out


# ---------------------------------------------------------------- finance


static func pnl(totals: Dictionary) -> Array[Array]:
	var rows: Array[Array] = []
	var keys: Array = totals.keys()
	keys.sort()
	for k: String in keys:
		rows.append([k.capitalize(), int(totals[k])])
	return rows


static func this_month(sim: Sim) -> Array[Array]:
	return pnl(sim.state.ledger.totals)


static func last_month(sim: Sim) -> Dictionary:
	var h: Array[SimState.MonthTotals] = sim.state.ledger.history
	if h.is_empty():
		return {}
	return {"month": h[-1].month, "rows": pnl(h[-1].totals), "net_cents": Ledger.month_net(h[-1].totals)}


static func _date_or_blank(sim: Sim, day: int) -> String:
	return "" if day < 0 else sim.data.history.dates[mini(day, sim.data.history.size() - 1)]


static func finance(sim: Sim) -> Dictionary:
	var f: SimState.FinanceState = sim.state.finance
	var fin: Finance = sim.finance
	var day: int = mini(sim.state.day_index, sim.data.history.size() - 1)
	return {
		"employed": f.employed,
		"rehire_date": _date_or_blank(sim, f.rehire_day),
		"salary_cents": fin.salary_cents,
		"living_cents": fin.living_cents(sim.state),
		"living_situation": sim.state.finance.living_situation,
		"rent_cents": sim.sites.rent_cents(sim.state),
		"incorporated": f.incorporated,
		"can_incorporate": not f.incorporated and sim.state.objectives.act >= fin.incorporation_act,
		"incorporation_cents": fin.incorporation_cents,
		"loan_taken": f.loan_taken,
		"loan_balance_cents": f.loan_balance_cents,
		"loan_payment_cents": f.loan_payment_cents,
		"loan_offer_cents": fin.loan_principal_cents,
		"loan_offer_payment_cents": Finance.monthly_payment_cents(fin.loan_principal_cents, fin.loan_annual_rate, fin.loan_term_months),
		"loan_rate": fin.loan_annual_rate,
		"loan_months": fin.loan_term_months,
		"ownership": f.ownership,
		"equity_cents": fin.equity_cents(sim, day),
		"score_cents": fin.score_cents(sim, day),
		"missed_cents": f.missed_cents,
		"overdue_until": _date_or_blank(sim, f.overdue_since_day + sim.restructuring.cure_days if f.overdue_since_day >= 0 else -1),
		"objective_streak": sim.state.objectives.streak,
		"objective_needed": sim.objectives.streak_days,
		"objective_met_on": sim.state.objectives.quit_job_met_on,
	}


# ---------------------------------------------------------------- treasury


static func exchanges(sim: Sim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in sim.custody.open_exchanges(sim):
		out.append({"id": id, "label": exchange_label(sim, id), "sats": sim.custody.exchange_balance(sim.state, id), "active": id == sim.state.custody.active_exchange})
	return out


static func place_label(sim: Sim, place: String) -> String:
	return "cold" if place == Custody.COLD else exchange_label(sim, place)


static func transfers(sim: Sim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: SimState.Transfer in sim.state.custody.transfers:
		out.append({"sats": t.sats, "from": place_label(sim, t.origin), "to": place_label(sim, t.destination), "arrives": _date_or_blank(sim, t.arrive_day + 1)})
	return out


## Rough proceeds at the last close, before slippage (the fill uses today's close).
static func estimate_sale_cents(sim: Sim, sats: int) -> int:
	return roundi(Finance.sats_to_cents(sats, price(sim), sim.consensus.sats_per_btc) * (1.0 - sim.market.fee))


static func trade_limits(sim: Sim) -> Dictionary:
	return {
		"blocked": sim.market.trade_block_reason(sim),
		"sell_sats": sim.market.max_sell_sats(sim),
		"buy_cents": sim.market.max_buy_cents(sim),
		"fee": sim.market.fee,
	}


static func offers(sim: Sim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for o: SimState.Offer in sim.state.offers.open:
		out.append({"id": o.id, "kind": o.kind, "sats": o.sats, "value_cents": o.value_cents, "expires": _date_or_blank(sim, o.expires_day)})
	return out


static func regret_cents(sim: Sim) -> int:
	return Finance.sats_to_cents(sim.state.offers.spent_sats, price(sim), sim.consensus.sats_per_btc)
