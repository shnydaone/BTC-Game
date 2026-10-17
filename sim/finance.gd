class_name Finance
extends RefCounted
## Cash, the day job, living costs, incorporation and the one small business loan
## (GDD 7.7). Before incorporation no debt is allowed; see Restructuring for what
## happens when cash runs out.

const CENTS_PER_USD: float = 100.0
const MONTHS_PER_YEAR: int = 12
const DAYS_PER_YEAR: float = 365.0
const FIRST_OF_MONTH: String = "-01"

var salary_cents: int
var living_cents: int
var rehire_delay_days: int
var incorporation_cents: int
var incorporation_act: int
var loan_principal_cents: int
var loan_annual_rate: float
var loan_term_months: int
var savings_cents: int


func _init(data: GameData) -> void:
	salary_cents = usd_to_cents(data.tuning("finance", "salary_usd_month"))
	living_cents = usd_to_cents(data.tuning("finance", "living_costs_usd_month"))
	rehire_delay_days = int(data.tuning("finance", "rehire_delay_days"))
	incorporation_cents = usd_to_cents(data.tuning("finance", "incorporation_cost_usd"))
	incorporation_act = int(data.tuning("finance", "incorporation_act"))
	loan_principal_cents = usd_to_cents(data.tuning("finance", "loan_principal_usd"))
	loan_annual_rate = float(data.tuning("finance", "loan_annual_rate"))
	loan_term_months = int(data.tuning("finance", "loan_term_months"))
	savings_cents = usd_to_cents(data.tuning("finance", "starting_savings_usd"))


static func usd_to_cents(usd: float) -> int:
	return roundi(usd * CENTS_PER_USD)


## Value of sats at a USD price, in cents. Zero when there is no price.
static func sats_to_cents(sats: int, price_usd: float, sats_per_btc: int) -> int:
	if is_nan(price_usd):
		return 0
	return roundi(float(sats) / sats_per_btc * price_usd * CENTS_PER_USD)


static func credit(state: SimState, cents: int, category: String) -> void:
	state.finance.cash_cents += cents
	Ledger.post(state, category, cents)


## Pays an expense even if it takes cash below zero; Restructuring settles that at day end.
static func debit(state: SimState, cents: int, category: String) -> void:
	state.finance.cash_cents -= cents
	Ledger.post(state, category, -cents)


func living_cents_per_day() -> float:
	return living_cents * MONTHS_PER_YEAR / DAYS_PER_YEAR


func step(sim: Sim, day: int, result: DayResult) -> void:
	var f: SimState.FinanceState = sim.state.finance
	f.personal_cents_today = 0
	if not f.employed and f.rehire_day >= 0 and day >= f.rehire_day:
		f.employed = true
		f.rehire_day = -1
		result.add("job_resumed")
	if not sim.data.history.dates[day].ends_with(FIRST_OF_MONTH):
		return
	if f.employed:
		credit(sim.state, salary_cents, "salary")
	debit(sim.state, living_cents, "living_costs")
	f.personal_cents_today = living_cents
	var rent: int = sim.sites.rent_cents(sim.state)
	if rent > 0:
		debit(sim.state, rent, "rent")
	if f.loan_balance_cents > 0:
		var interest: int = roundi(f.loan_balance_cents * loan_annual_rate / MONTHS_PER_YEAR)
		var principal: int = mini(f.loan_balance_cents, f.loan_payment_cents - interest)
		debit(sim.state, interest, "interest")
		f.cash_cents -= principal
		f.loan_balance_cents -= principal
		if f.loan_balance_cents == 0:
			f.loan_payment_cents = 0
			result.add("loan_repaid")


func quit_job(sim: Sim) -> String:
	var f: SimState.FinanceState = sim.state.finance
	if not f.employed:
		return "not employed"
	f.employed = false
	f.rehire_day = -1
	return ""


func rejoin_job(sim: Sim) -> String:
	var f: SimState.FinanceState = sim.state.finance
	if f.employed or f.rehire_day >= 0:
		return "already employed or hired"
	f.rehire_day = sim.state.day_index + rehire_delay_days
	return ""


func incorporate(sim: Sim) -> String:
	var f: SimState.FinanceState = sim.state.finance
	if f.incorporated:
		return "already incorporated"
	if sim.state.objectives.act < incorporation_act:
		return "incorporation unlocks in act %d" % incorporation_act
	if f.cash_cents < incorporation_cents:
		return "not enough cash"
	debit(sim.state, incorporation_cents, "incorporation")
	f.incorporated = true
	return ""


func take_loan(sim: Sim) -> String:
	var f: SimState.FinanceState = sim.state.finance
	if not f.incorporated:
		return "needs incorporation"
	if f.loan_taken:
		return "the one loan is already taken"
	f.loan_taken = true
	f.loan_balance_cents = loan_principal_cents
	f.loan_payment_cents = monthly_payment_cents(loan_principal_cents, loan_annual_rate, loan_term_months)
	f.cash_cents += loan_principal_cents
	return ""


static func monthly_payment_cents(principal_cents: int, annual_rate: float, months: int) -> int:
	var r: float = annual_rate / MONTHS_PER_YEAR
	if r == 0.0:
		return ceili(float(principal_cents) / months)
	return ceili(principal_cents * r / (1.0 - pow(1.0 + r, -months)))


## Owner's equity at fair value: cash, BTC at the day's close, hardware at book, less debt.
func equity_cents(sim: Sim, day: int) -> int:
	var f: SimState.FinanceState = sim.state.finance
	var btc: int = sats_to_cents(sim.custody.total_sats(sim.state), sim.data.history.price_usd[day], sim.consensus.sats_per_btc)
	return f.cash_cents + btc + sim.hardware.book_value_cents(sim.state, day) - f.loan_balance_cents


func score_cents(sim: Sim, day: int) -> int:
	return roundi(equity_cents(sim, day) * sim.state.finance.ownership)
