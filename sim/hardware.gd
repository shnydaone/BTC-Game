class_name Hardware
extends RefCounted
## The player's machines (GDD 7.2, 7.9): buying new or used, lead times, aging and
## failures, automatic repairs, depreciation, and selling. Facts come from
## data/hardware/hardware.json, feel values from data/tuning/hardware.json.

const DAYS_PER_YEAR: float = 365.0
const HASHES_PER_TERAHASH: float = 1.0e12
const GPU_TIER: String = "GPU"
const DEFAULT_KEY: String = "default"

var units: Dictionary = {}  # unit id -> hardware.json unit
var purchase_price_usd: Dictionary
var uptime: Dictionary
var cards_per_rig: int
var rig_overhead_cents: int
var rig_overhead_w: float
var annual_failure_rate: Array
var repair_fraction: float
var lead_time_days: Dictionary
var depreciation_days: int
var tracks_hashprice: Array
var price_clamp: Array
var used_fraction: float
var used_life_days: float
var used_floor: float
var hashprice_window: PackedFloat64Array = []  # trailing mean USD per TH/s per day, 0 without a price

var _history: History


func _init(data: GameData) -> void:
	_history = data.history
	for u: Dictionary in data.hardware:
		units[u["id"]] = u
	purchase_price_usd = data.tuning("hardware", "purchase_price_usd")
	uptime = data.tuning("hardware", "uptime")
	cards_per_rig = int(data.tuning("hardware", "gpu_cards_per_rig"))
	rig_overhead_cents = Finance.usd_to_cents(data.tuning("hardware", "gpu_rig_overhead_usd"))
	rig_overhead_w = float(data.tuning("hardware", "gpu_rig_overhead_w"))
	annual_failure_rate = data.tuning("hardware", "annual_failure_rate")
	repair_fraction = float(data.tuning("hardware", "repair_cost_fraction"))
	lead_time_days = data.tuning("hardware", "lead_time_days")
	depreciation_days = roundi(float(data.tuning("hardware", "depreciation_years")) * DAYS_PER_YEAR)
	tracks_hashprice = data.tuning("hardware", "new_price_tracks_hashprice")
	price_clamp = data.tuning("hardware", "new_price_clamp")
	used_fraction = float(data.tuning("hardware", "used_price_fraction"))
	used_life_days = float(data.tuning("hardware", "used_useful_life_years")) * DAYS_PER_YEAR
	used_floor = float(data.tuning("hardware", "used_price_floor"))
	_build_hashprice(int(data.tuning("hardware", "price_hashprice_window_days")))


func _build_hashprice(window: int) -> void:
	var h := _history
	var daily := PackedFloat64Array()
	daily.resize(h.size())
	for i: int in h.size():
		if h.has_price(i) and h.hashrate_hs[i] > 0.0:
			daily[i] = (h.subsidy_btc[i] + h.fees_btc[i]) * h.price_usd[i] / (h.hashrate_hs[i] / HASHES_PER_TERAHASH)
	hashprice_window.resize(h.size())
	var total: float = 0.0
	for i: int in h.size():
		total += daily[i]
		if i >= window:
			total -= daily[i - window]
		hashprice_window[i] = total / mini(i + 1, window)


func _lookup(table: Dictionary, key: String) -> Variant:
	return table[key] if table.has(key) else table[DEFAULT_KEY]


func tier(unit_id: String) -> String:
	return units[unit_id]["tier"]


func uptime_of(unit_id: String) -> float:
	return float(_lookup(uptime, unit_id))


## Hashrate of one unit while running, after software speedups for its tier.
func unit_hashrate(state: SimState, unit_id: String) -> float:
	return float(units[unit_id]["hashrate_hs"]) * state.hardware.tier_multipliers.get(tier(unit_id), 1.0)


## Wall power of one unit, with a GPU card's share of its rig's overhead.
func unit_watts(unit_id: String) -> float:
	var w: float = float(units[unit_id]["power_w"])
	if tier(unit_id) == GPU_TIER:
		w += rig_overhead_w / cards_per_rig
	return w


func is_available(sim: Sim, unit_id: String) -> bool:
	if not units.has(unit_id) or not sim.state.events.features.has("mining"):
		return false
	var u: Dictionary = units[unit_id]
	if u["unlock_event"] != null and not sim.state.events.fired.has(u["unlock_event"]):
		return false
	return sim.current_date() >= String(u["available_from"]) and base_price_cents(unit_id) > 0


func base_price_cents(unit_id: String) -> int:
	var u: Dictionary = units[unit_id]
	if u["launch_price_usd"] != null:
		return Finance.usd_to_cents(u["launch_price_usd"])
	if purchase_price_usd.has(unit_id):
		return Finance.usd_to_cents(purchase_price_usd[unit_id])
	return -1


func new_price_cents(unit_id: String, day: int) -> int:
	var base: int = base_price_cents(unit_id)
	if base <= 0 or not tracks_hashprice.has(tier(unit_id)):
		return base
	var launch: int = _history.index_of(units[unit_id]["available_from"])
	if launch < 0 or hashprice_window[launch] <= 0.0 or day < launch:
		return base
	var ratio: float = clampf(hashprice_window[day] / hashprice_window[launch], float(price_clamp[0]), float(price_clamp[1]))
	return roundi(base * ratio)


func used_price_cents(unit_id: String, age_days: int, day: int) -> int:
	var remaining: float = maxf(used_floor, 1.0 - age_days / used_life_days)
	return roundi(new_price_cents(unit_id, day) * used_fraction * remaining)


func lead_time(unit_id: String) -> int:
	return int(_lookup(lead_time_days, tier(unit_id)))


func gpu_cards(state: SimState) -> int:
	var n: int = 0
	for lot: SimState.Lot in state.hardware.lots:
		if tier(lot.unit_id) == GPU_TIER:
			n += lot.count
	return n


func _rigs(cards: int) -> int:
	return ceili(float(cards) / cards_per_rig)


## Price of buying count units today, including rigs for any new GPU cards.
func quote_cents(sim: Sim, unit_id: String, count: int, used: bool) -> int:
	var day: int = sim.state.day_index
	var each: int = used_price_cents(unit_id, _used_age_days(unit_id, day), day) if used else new_price_cents(unit_id, day)
	var total: int = each * count
	if tier(unit_id) == GPU_TIER:
		var cards: int = gpu_cards(sim.state)
		total += (_rigs(cards + count) - _rigs(cards)) * rig_overhead_cents
	return total


## Used units on the market are a year old, or as old as the model if it is newer.
func _used_age_days(unit_id: String, day: int) -> int:
	var released: int = _history.index_of(units[unit_id]["available_from"])
	return mini(roundi(DAYS_PER_YEAR), maxi(0, day - released))


func buy(sim: Sim, unit_id: String, count: int, used: bool) -> Dictionary:
	if count <= 0:
		return {"ok": false, "reason": "count must be positive"}
	if not is_available(sim, unit_id):
		return {"ok": false, "reason": "%s is not for sale" % unit_id}
	var cost: int = quote_cents(sim, unit_id, count, used)
	if cost > sim.state.finance.cash_cents:
		return {"ok": false, "reason": "not enough cash"}
	var day: int = sim.state.day_index
	var lot := add_lot(sim.state, unit_id, count, cost, day)
	if used:
		lot.bought_day = day - _used_age_days(unit_id, day)
		lot.arrive_day = day
	else:
		lot.arrive_day = day + lead_time(unit_id)
	sim.state.finance.cash_cents -= cost
	return {"ok": true, "reason": "", "lot_id": lot.id, "cost_cents": cost, "arrive_day": lot.arrive_day}


func add_lot(state: SimState, unit_id: String, count: int, cost_cents: int, day: int) -> SimState.Lot:
	var lot := SimState.Lot.new()
	lot.id = state.hardware.next_lot_id
	state.hardware.next_lot_id += 1
	lot.unit_id = unit_id
	lot.count = count
	lot.cost_cents = cost_cents
	lot.bought_day = day
	lot.purchased_day = day
	lot.arrive_day = day
	state.hardware.lots.append(lot)
	return lot


func find_lot(state: SimState, lot_id: int) -> SimState.Lot:
	for lot: SimState.Lot in state.hardware.lots:
		if lot.id == lot_id:
			return lot
	return null


func sell(sim: Sim, lot_id: int, count: int) -> Dictionary:
	var lot := find_lot(sim.state, lot_id)
	if lot == null or count <= 0 or count > lot.count:
		return {"ok": false, "reason": "no such units"}
	if lot.arrive_day > sim.state.day_index:
		return {"ok": false, "reason": "not delivered yet"}
	var proceeds: int = _sale_value_cents(lot, count, sim.state.day_index)
	_remove_units(sim.state, lot, count, proceeds, sim.state.day_index)
	return {"ok": true, "reason": "", "proceeds_cents": proceeds}


## Working units sell at the used price, broken ones (sold last) at the floor.
func _sale_value_cents(lot: SimState.Lot, count: int, day: int) -> int:
	var working: int = mini(count, lot.count - lot.broken)
	var each: int = used_price_cents(lot.unit_id, day - lot.bought_day, day)
	var scrap: int = roundi(new_price_cents(lot.unit_id, day) * used_floor)
	return working * each + (count - working) * scrap


func _remove_units(state: SimState, lot: SimState.Lot, count: int, proceeds: int, day: int) -> void:
	var book_share: int = roundi(book_value_lot_cents(lot, day) * float(count) / lot.count)
	var cost_share: int = roundi(lot.cost_cents * float(count) / lot.count)
	var working_sold: int = mini(count, lot.count - lot.broken)
	lot.broken -= count - working_sold
	lot.count -= count
	lot.cost_cents -= cost_share
	lot.running = mini(lot.running, lot.count - lot.broken)
	state.finance.cash_cents += proceeds
	Ledger.post(state, "hardware_sale_gain", proceeds - book_share)
	if lot.count == 0:
		state.hardware.lots.erase(lot)


## Sells this share of every delivered lot, rounding down per lot (Chapter 11). Returns proceeds.
func liquidate_fraction(state: SimState, fraction: float, day: int) -> int:
	var total: int = 0
	for lot: SimState.Lot in state.hardware.lots.duplicate():
		var count: int = floori(lot.count * fraction)
		if count > 0 and lot.arrive_day <= day:
			var proceeds: int = _sale_value_cents(lot, count, day)
			_remove_units(state, lot, count, proceeds, day)
			total += proceeds
	return total


func book_value_lot_cents(lot: SimState.Lot, day: int) -> int:
	var age: int = maxi(0, day - lot.purchased_day)
	return roundi(lot.cost_cents * maxf(0.0, 1.0 - float(age) / depreciation_days))


func book_value_cents(state: SimState, day: int) -> int:
	var total: int = 0
	for lot: SimState.Lot in state.hardware.lots:
		total += book_value_lot_cents(lot, day)
	return total


func daily_failure_probability(age_days: int) -> float:
	var year: int = mini(age_days / roundi(DAYS_PER_YEAR), annual_failure_rate.size() - 1)
	return 1.0 - pow(1.0 - float(annual_failure_rate[year]), 1.0 / DAYS_PER_YEAR)


func step(sim: Sim, day: int, result: DayResult) -> void:
	var state: SimState = sim.state
	for lot: SimState.Lot in state.hardware.lots:
		if lot.arrive_day == day and lot.purchased_day != day:
			result.add("hardware_arrived", {"lot_id": lot.id, "unit_id": lot.unit_id, "count": lot.count})
		if lot.arrive_day > day:
			continue
		# Failures among yesterday's running units.
		if lot.running > 0:
			var failed: int = mini(lot.running, sim.rng.poisson("hardware", lot.running * daily_failure_probability(day - lot.bought_day)))
			if failed > 0:
				lot.broken += failed
				lot.running -= failed
				result.add("hardware_failed", {"lot_id": lot.id, "unit_id": lot.unit_id, "count": failed})
		# Repairs, one unit at a time while cash allows.
		if lot.broken > 0:
			var each: int = roundi(new_price_cents(lot.unit_id, day) * repair_fraction)
			var fixed: int = 0
			while lot.broken > 0 and state.finance.cash_cents >= each:
				Finance.debit(state, each, "repairs")
				lot.broken -= 1
				fixed += 1
			if fixed > 0:
				result.add("hardware_repaired", {"lot_id": lot.id, "count": fixed, "cost_cents": each * fixed})
		# Depreciation: straight line from purchase.
		var age: int = day - lot.purchased_day
		if age < depreciation_days:
			Ledger.post(state, "depreciation", -(book_value_lot_cents(lot, day) - book_value_lot_cents(lot, day + 1)))


func set_powered(sim: Sim, lot_id: int, powered: bool) -> String:
	var lot := find_lot(sim.state, lot_id)
	if lot == null:
		return "no such lot"
	lot.powered = powered
	return ""
