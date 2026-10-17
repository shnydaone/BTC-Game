class_name NeverUpgradeBot
extends Bot
## GDD 14 Never Upgrade: keeps first-gen hardware. It mines with the laptop until the
## first ASICs ship, fills the garage with ASIC Gen 1 units once, and never buys or
## sells hardware again. Its machines keep running whether or not they pay. It sells BTC
## only to keep a cash buffer.

const UNIT: String = "asic_gen1"
const BUFFER_MONTHS: float = 2.0
const BUYING_WINDOW_DAYS: int = 30  # one buying spree after the first ASICs ship, then never again
const STACK_SPENT_ON_ASICS: float = 0.5

var _first_day: int = -1


func _init() -> void:
	name = "never_upgrade"


func decide(sim: Sim) -> void:
	use_pool_when_possible(sim)
	decline_offers(sim)
	var buffer: int = roundi(BUFFER_MONTHS * monthly_costs_cents(sim))
	if sim.hardware.is_available(sim, UNIT) and _first_day < 0:
		_first_day = today(sim)
		if sim.state.hardware.site_id == "bedroom":
			sim.apply({"type": "move_site", "site_id": "garage"})
		raise_cash(sim, roundi(btc_value_cents(sim) * STACK_SPENT_ON_ASICS))
	var buying: bool = _first_day >= 0 and today(sim) - _first_day < BUYING_WINDOW_DAYS
	if buying:
		if exchange_sats(sim) > 0:
			sim.apply({"type": "sell_btc", "sats": mini(exchange_sats(sim), sim.market.max_sell_sats(sim))})
		buy_up_to(sim, UNIT, sim.state.finance.cash_cents - buffer)
		return
	var short: int = buffer - sim.state.finance.cash_cents
	if short > 0:
		raise_cash(sim, short)
	elif _in_flight(sim) == 0:
		sweep_to_cold(sim)
