class_name Power
extends RefCounted
## Decides which machines run today and pays for their power (GDD 7.1):
## power_cost = sum(watts x uptime) x 24 / 1000 x price_per_kWh x PUE.
##
## Units fill the site's kW capacity most efficient first. With the shut-off setting on,
## units whose expected revenue is below their power cost stay off. Before incorporation
## the player cannot go negative, so units the cash cannot pay for shut off.

const HOURS_PER_DAY: float = 24.0


## Expected USD revenue per H/s per day at yesterday's network state, or NAN without a price.
func revenue_per_hs_day(sim: Sim, day: int) -> float:
	var n: SimState.NetworkState = sim.state.network
	var close: float = sim.data.history.price_usd[day]
	if is_nan(close) or n.network_hashrate_hs <= 0.0:
		return NAN
	return float(n.subsidy_sats_today + n.fees_sats_today) / sim.consensus.sats_per_btc * close / n.network_hashrate_hs


func unit_cost_cents_per_day(sim: Sim, unit_id: String) -> float:
	var s: Dictionary = sim.sites.site(sim.state)
	var kwh: float = sim.hardware.unit_watts(unit_id) * sim.hardware.uptime_of(unit_id) * HOURS_PER_DAY / Sites.WATTS_PER_KW
	return kwh * float(s["pue"]) * float(s["power_usd_per_kwh"]) * Finance.CENTS_PER_USD


func step(sim: Sim, day: int, result: DayResult) -> void:
	var state: SimState = sim.state
	var hw: Hardware = sim.hardware
	var revenue_per_hs: float = revenue_per_hs_day(sim, day)
	var mining: bool = state.events.features.has("mining")
	var candidates: Array[SimState.Lot] = []
	for lot: SimState.Lot in state.hardware.lots:
		lot.running = 0
		# Before mining unlocks the laptop is just the player's computer.
		if not mining or lot.arrive_day > day or not lot.powered or lot.count - lot.broken <= 0:
			continue
		if state.hardware.shutoff_unprofitable and not is_nan(revenue_per_hs):
			var revenue: float = hw.unit_hashrate(state, lot.unit_id) * hw.uptime_of(lot.unit_id) * revenue_per_hs * Finance.CENTS_PER_USD
			if revenue < unit_cost_cents_per_day(sim, lot.unit_id):
				continue
		candidates.append(lot)
	candidates.sort_custom(func(a: SimState.Lot, b: SimState.Lot) -> bool:
		var ea: float = hw.unit_watts(a.unit_id) / hw.unit_hashrate(state, a.unit_id)
		var eb: float = hw.unit_watts(b.unit_id) / hw.unit_hashrate(state, b.unit_id)
		return ea < eb if ea != eb else a.id < b.id)

	var free_w: float = sim.sites.capacity_w(state)
	for lot: SimState.Lot in candidates:
		var watts: float = hw.unit_watts(lot.unit_id)
		lot.running = mini(lot.count - lot.broken, floori(free_w / watts))
		free_w -= lot.running * watts

	var cost: float = _cost(sim, candidates)
	if not state.finance.incorporated and cost > state.finance.cash_cents:
		var stopped: int = 0
		for i: int in range(candidates.size() - 1, -1, -1):
			var lot: SimState.Lot = candidates[i]
			while lot.running > 0 and cost > state.finance.cash_cents:
				lot.running -= 1
				stopped += 1
				cost -= unit_cost_cents_per_day(sim, lot.unit_id)
		if stopped > 0:
			result.add("machines_shut_off", {"count": stopped, "reason": "cash"})

	var cents: int = maxi(0, roundi(cost))
	Finance.debit(state, cents, "power")
	state.hardware.power_cents_today = cents
	var hashrate: float = 0.0
	for lot: SimState.Lot in candidates:
		hashrate += lot.running * hw.unit_hashrate(state, lot.unit_id) * hw.uptime_of(lot.unit_id)
	state.player_hashrate_hs = hashrate if state.hashrate_override_hs < 0.0 else state.hashrate_override_hs


func _cost(sim: Sim, lots: Array[SimState.Lot]) -> float:
	var cost: float = 0.0
	for lot: SimState.Lot in lots:
		cost += lot.running * unit_cost_cents_per_day(sim, lot.unit_id)
	return cost
