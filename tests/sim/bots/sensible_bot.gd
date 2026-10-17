class_name SensibleBot
extends Bot
## GDD 14 Sensible: rule-based reasonable play.
##
## - Pool mining once pools exist; unprofitable units shut off, and units idle for a
##   month are sold.
## - Each week, buys the most efficient unit for sale if it pays back fast, funding it
##   from cash above a buffer and from up to a tenth of the stack a month. When the site
##   is full it sells its least efficient machines if the new unit is at least twice as
##   efficient, and moves to a bigger site when the stack can carry the rent.
## - Coins stay in cold storage. It moves only what it needs to an exchange and sells
##   there to keep a cash buffer.
## - Quits the day job once the Act 1 objective is met, and takes it back when broke.
## - Incorporates in Act 2 and never borrows. Declines trade offers.

const BUFFER_MONTHS: float = 3.0
const MAX_PAYBACK_DAYS: float = 180.0
const STACK_SPEND_FRACTION_PER_MONTH: float = 0.10
const IDLE_DAYS_BEFORE_SELLING: int = 30
const REVIEW_EVERY_DAYS: int = 7
const BROKE_MONTHS_OF_BTC: float = 6.0
const REPLACE_EFFICIENCY_RATIO: float = 2.0
const RENT_MONTHS_BEFORE_MOVING: float = 24.0

var _idle_days: Dictionary = {}  # lot id -> days powered but not running
var _last_stack_spend_day: int = -1000
var _funding: bool = false  # coins moved to the exchange to pay for hardware
var stack_spend_fraction: float = STACK_SPEND_FRACTION_PER_MONTH
var buffer_months: float = BUFFER_MONTHS
var review_every_days: int = REVIEW_EVERY_DAYS


func _init() -> void:
	name = "sensible"


func decide(sim: Sim) -> void:
	var s: SimState = sim.state
	use_pool_when_possible(sim)
	if not s.hardware.shutoff_unprofitable:
		sim.apply({"type": "set_shutoff_unprofitable", "enabled": true})
	decline_offers(sim)
	_manage_job(sim)
	if s.objectives.act >= sim.finance.incorporation_act and not s.finance.incorporated:
		sim.apply({"type": "incorporate"})
	if _funding:
		_finish_funding(sim)
	else:
		_manage_cash(sim)
	_sell_idle(sim)
	if _funding or today(sim) % review_every_days == 0:
		_invest(sim)


func buffer_cents(sim: Sim) -> float:
	return buffer_months * monthly_costs_cents(sim)


func _manage_job(sim: Sim) -> void:
	var f: SimState.FinanceState = sim.state.finance
	if f.employed and sim.state.objectives.quit_job_met_on != "":
		sim.apply({"type": "quit_job"})
	elif not f.employed and f.rehire_day < 0:
		var reserves: float = f.cash_cents + btc_value_cents(sim)
		if reserves < BROKE_MONTHS_OF_BTC * sim.finance.living_cents(sim.state):
			sim.apply({"type": "rejoin_job"})


func _manage_cash(sim: Sim) -> void:
	var short: int = roundi(buffer_cents(sim)) - sim.state.finance.cash_cents
	if short > 0:
		raise_cash(sim, short)
	elif _in_flight(sim) == 0:
		sweep_to_cold(sim)


func _sell_idle(sim: Sim) -> void:
	for lot: SimState.Lot in sim.state.hardware.lots.duplicate():
		if lot.arrive_day > today(sim) or not lot.powered:
			continue
		if lot.running == 0 and lot.count > lot.broken:
			_idle_days[lot.id] = int(_idle_days.get(lot.id, 0)) + 1
		else:
			_idle_days[lot.id] = 0
		if int(_idle_days[lot.id]) >= IDLE_DAYS_BEFORE_SELLING:
			sim.apply({"type": "sell_hardware", "lot_id": lot.id, "count": lot.count})
			_idle_days.erase(lot.id)


func _invest(sim: Sim) -> void:
	var unit_id: String = best_unit(sim)
	if unit_id == "":
		return
	var payback: float = payback_days(sim, unit_id)
	if payback > MAX_PAYBACK_DAYS:
		return
	var watts: float = sim.hardware.unit_watts(unit_id)
	if free_watts(sim) < watts:
		_grow_site(sim)
	if free_watts(sim) < watts:
		_replace_worst(sim, unit_id)
	if free_watts(sim) < watts:
		return
	var budget: int = sim.state.finance.cash_cents - roundi(buffer_cents(sim))
	if stack_spend_fraction > 0.0 and not _funding and today(sim) - _last_stack_spend_day >= DAYS_PER_MONTH and btc_sats(sim) > 0:
		_last_stack_spend_day = today(sim)
		_funding = true
		budget += raise_cash(sim, roundi(btc_value_cents(sim) * stack_spend_fraction))
	if budget > 0:
		buy_up_to(sim, unit_id, budget)


## Sells the coins moved for a hardware purchase as they arrive; done when none are left
## on the exchange or in flight.
func _finish_funding(sim: Sim) -> void:
	var sats: int = mini(exchange_sats(sim), sim.market.max_sell_sats(sim))
	if sats > 0:
		sim.apply({"type": "sell_btc", "sats": sats})
	if exchange_sats(sim) == 0 and _in_flight(sim) == 0:
		_funding = false


## Bedroom to garage at once; garage to the warehouse once incorporated and the reserves
## cover two years of its rent.
func _grow_site(sim: Sim) -> void:
	match sim.state.hardware.site_id:
		"bedroom":
			sim.apply({"type": "move_site", "site_id": "garage"})
		"garage":
			var rent: float = Finance.usd_to_cents(sim.sites.sites["warehouse"]["rent_usd_month"])
			if sim.state.finance.cash_cents + btc_value_cents(sim) > RENT_MONTHS_BEFORE_MOVING * rent:
				sim.apply({"type": "move_site", "site_id": "warehouse"})


## Sells the least efficient lot when the new unit is at least twice as efficient.
func _replace_worst(sim: Sim, unit_id: String) -> void:
	var hw: Hardware = sim.hardware
	var best_hpw: float = hw.unit_hashrate(sim.state, unit_id) / hw.unit_watts(unit_id)
	var worst: SimState.Lot = null
	var worst_hpw: float = INF
	for lot: SimState.Lot in sim.state.hardware.lots:
		if lot.arrive_day > today(sim):
			continue
		var hpw: float = hw.unit_hashrate(sim.state, lot.unit_id) / hw.unit_watts(lot.unit_id)
		if hpw < worst_hpw:
			worst_hpw = hpw
			worst = lot
	if worst != null and best_hpw >= REPLACE_EFFICIENCY_RATIO * worst_hpw:
		sim.apply({"type": "sell_hardware", "lot_id": worst.id, "count": worst.count})
