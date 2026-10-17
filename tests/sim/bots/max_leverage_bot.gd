class_name MaxLeverageBot
extends Bot
## GDD 14 Max Leverage: borrows to the limit and buys every rig.
##
## Spends all cash on the most efficient unit for sale, sells every mined coin the day
## it arrives to buy more, quits the day job as soon as the Act 1 objective allows,
## incorporates and draws the one loan as soon as Act 2 opens, and never turns a
## machine off or sells one. It shops weekly, which keeps the lot count (and run time)
## sane. With only the Act 2 loan in M2 it survives Slashdot Acts 1-2; the GDD's
## 2018/2022 outcome needs the Act 3-4 finance (M6).


const REVIEW_EVERY_DAYS: int = 7


func _init() -> void:
	name = "max_leverage"


func decide(sim: Sim) -> void:
	var s: SimState = sim.state
	use_pool_when_possible(sim)
	decline_offers(sim)
	if s.market.policy != "sell_percent" and s.events.features.has("selling"):
		sim.apply({"type": "set_treasury_policy", "policy": "sell_percent", "percent": 1.0})
	if s.finance.employed and s.objectives.quit_job_met_on != "":
		sim.apply({"type": "quit_job"})
	if s.objectives.act >= sim.finance.incorporation_act:
		if not s.finance.incorporated:
			sim.apply({"type": "incorporate"})
		if not s.finance.loan_taken:
			sim.apply({"type": "take_loan"})
	if today(sim) % REVIEW_EVERY_DAYS != 0:
		return
	var unit_id: String = best_unit(sim)
	if unit_id == "":
		return
	if free_watts(sim) < sim.hardware.unit_watts(unit_id):
		sim.apply({"type": "move_site", "site_id": "warehouse" if s.finance.incorporated else "garage"})
	buy_up_to(sim, unit_id, s.finance.cash_cents)
