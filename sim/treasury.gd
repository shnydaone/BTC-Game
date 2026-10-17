class_name Treasury
extends RefCounted
## The player's standing treasury policy (GDD 7.6): HODL everything, sell a share of each
## day's production, or sell only to keep a cash buffer for running costs.

const POLICIES: PackedStringArray = ["hodl", "sell_percent", "cover_costs"]
const DAYS_PER_MONTH: float = 30.0

var buffer_days: int


func _init(data: GameData) -> void:
	buffer_days = int(data.tuning("treasury", "cover_costs_buffer_days"))


func set_policy(sim: Sim, policy: String, percent: float) -> String:
	if not POLICIES.has(policy):
		return "unknown policy %s" % policy
	if policy == "sell_percent" and (percent <= 0.0 or percent > 1.0):
		return "percent must be in (0, 1]"
	sim.state.market.policy = policy
	sim.state.market.sell_percent = percent if policy == "sell_percent" else 0.0
	return ""


## Running costs per day: living costs and rent spread over the month, today's power,
## and the loan payment.
func daily_costs_cents(sim: Sim) -> float:
	var monthly: float = sim.finance.living_cents + sim.sites.rent_cents(sim.state) + sim.state.finance.loan_payment_cents
	return monthly / DAYS_PER_MONTH + sim.state.hardware.power_cents_today


func step(sim: Sim, day: int, result: DayResult) -> void:
	var m: SimState.MarketState = sim.state.market
	match m.policy:
		"sell_percent":
			var sats: int = mini(floori(sim.state.mining.mined_sats_today * m.sell_percent), sim.market.max_sell_sats(sim))
			if sats > 0:
				sim.market.sell(sim, sats)
		"cover_costs":
			var target: float = buffer_days * daily_costs_cents(sim)
			if sim.state.finance.cash_cents < target:
				raise_cash(sim, roundi(target) - sim.state.finance.cash_cents)


## Sells enough exchange BTC for the cash, within today's limit. Returns cents raised.
func raise_cash(sim: Sim, cents: int) -> int:
	var close: float = sim.market.price(sim, sim.state.day_index)
	if cents <= 0 or sim.market.trade_block_reason(sim) != "":
		return 0
	# Ask for a little extra to cover the fee and slippage.
	var gross: float = cents / Finance.CENTS_PER_USD / (1.0 - sim.market.fee) / (1.0 - sim.market.slippage * sim.market.cap_fraction)
	var sats: int = mini(ceili(gross / close * sim.consensus.sats_per_btc), sim.market.max_sell_sats(sim))
	if sats <= 0:
		return 0
	var sale: Dictionary = sim.market.sell(sim, sats)
	return int(sale.get("proceeds_cents", 0))
