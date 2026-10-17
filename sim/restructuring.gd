class_name Restructuring
extends RefCounted
## Settles the day's cash (GDD 7.8). If cash is negative, exchange BTC is sold first.
## Living costs are personal: an unpaid share of them is a missed payment, never company
## debt. Before incorporation no debt is allowed, so the whole shortfall is a missed
## payment. After incorporation, unpaid company obligations (power, rent, the loan,
## repairs) start a cure clock; if the company is still short when it runs out, it is
## Chapter 11: creditors take part of the fleet, convert the debt to equity and cut the
## player's ownership. Below the floor the board replaces the player and the
## act is lost.

var ownership_floor: float
var dilution_base: float
var dilution_per_leverage: float
var dilution_max: float
var fleet_sold_fraction: float
var cure_days: int


func _init(data: GameData) -> void:
	ownership_floor = float(data.tuning("restructuring", "ownership_floor"))
	dilution_base = float(data.tuning("restructuring", "dilution_base"))
	dilution_per_leverage = float(data.tuning("restructuring", "dilution_per_leverage"))
	dilution_max = float(data.tuning("restructuring", "dilution_max"))
	fleet_sold_fraction = float(data.tuning("restructuring", "fleet_sold_fraction"))
	cure_days = int(data.tuning("restructuring", "cure_days"))


func settle(sim: Sim, day: int, result: DayResult) -> void:
	var f: SimState.FinanceState = sim.state.finance
	if f.cash_cents < 0:
		sim.treasury.raise_cash(sim, -f.cash_cents)
	if f.cash_cents >= 0:
		if f.overdue_since_day >= 0:
			f.overdue_since_day = -1
			result.add("payment_cured")
		return
	var shortfall: int = -f.cash_cents
	var personal: int = shortfall if not f.incorporated else mini(shortfall, f.personal_cents_today)
	if personal > 0:
		f.missed_cents += personal
		f.cash_cents += personal
		result.add("payment_missed", {"cents": personal})
	if f.cash_cents >= 0:
		return
	if f.overdue_since_day < 0:
		f.overdue_since_day = day
		result.add("payment_overdue", {"cents": -f.cash_cents, "cure_by_day": day + cure_days})
	elif day - f.overdue_since_day >= cure_days:
		chapter_11(sim, day, result)


func dilution(debt_cents: int, assets_cents: int) -> float:
	var leverage: float = float(debt_cents) / maxi(assets_cents, 1)
	return clampf(dilution_base + dilution_per_leverage * leverage, dilution_base, dilution_max)


func chapter_11(sim: Sim, day: int, result: DayResult) -> void:
	var state: SimState = sim.state
	var f: SimState.FinanceState = state.finance
	var btc: int = Finance.sats_to_cents(sim.custody.total_sats(state), sim.data.history.price_usd[day], sim.consensus.sats_per_btc)
	var assets: int = btc + sim.hardware.book_value_cents(state, day)
	var debt: int = f.loan_balance_cents - f.cash_cents
	var cut: float = dilution(debt, assets)
	# Creditors take the sale proceeds and convert what is still owed into equity.
	sim.hardware.liquidate_fraction(state, fleet_sold_fraction, day)
	f.cash_cents = 0
	f.loan_balance_cents = 0
	f.loan_payment_cents = 0
	f.ownership *= 1.0 - cut
	f.overdue_since_day = -1
	state.objectives.restructurings += 1
	result.add("restructured", {"ownership": f.ownership, "cut": cut, "debt_cents": debt})
	if f.ownership < ownership_floor:
		state.objectives.act_lost = true
		result.add("act_lost", {"act": state.objectives.act})
