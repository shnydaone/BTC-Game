class_name Objectives
extends RefCounted
## Act objectives and the act-end report card (GDD 6).
##
## Act 1, quit your day job: trailing mining revenue (BTC mined, valued at each day's
## close) covers living costs for 90 straight days. Selling the stack does not count.
## Act 2: hit the hashrate target at some point in the act and finish it solvent.

const HASHES_PER_TERAHASH: float = 1.0e12

var streak_days: int
var window_days: int
var crash_window: Array
var act2_target_hs: float


func _init(data: GameData) -> void:
	streak_days = int(data.tuning("objectives", "quit_job_streak_days"))
	window_days = int(data.tuning("objectives", "quit_job_window_days"))
	crash_window = data.tuning("objectives", "crash_2011_window")
	act2_target_hs = float(data.tuning("objectives", "act2_hashrate_target_ths")) * HASHES_PER_TERAHASH
	data.tuning("objectives", "grades")  # the grade rules below follow this table


func step(sim: Sim, day: int, result: DayResult) -> void:
	var o: SimState.ObjectivesState = sim.state.objectives
	o.act_peak_hashrate_hs = maxf(o.act_peak_hashrate_hs, sim.state.player_hashrate_hs)
	o.revenue_window.append(sim.state.mining.mined_value_cents_today)
	if o.revenue_window.size() > window_days:
		o.revenue_window.remove_at(0)
	if sim.current_date() == String(crash_window[0]):
		o.crash_held_sats = sim.custody.total_sats(sim.state)
	if o.act != 1 or o.quit_job_met_on != "":
		return
	var revenue: int = 0
	for cents: int in o.revenue_window:
		revenue += cents
	var costs: float = sim.finance.living_cents_per_day(sim.state) * window_days
	if o.revenue_window.size() == window_days and revenue >= costs:
		o.streak += 1
	else:
		o.streak = 0
	if o.streak >= streak_days:
		o.quit_job_met_on = sim.current_date()
		result.add("objective_met", {"act": 1, "objective": "quit_day_job"})


## The report card for the act that ends today. Acts before the game's start act are skipped.
func end_act(sim: Sim, act: int, result: DayResult) -> void:
	var o: SimState.ObjectivesState = sim.state.objectives
	if act < o.act:
		return
	var day: int = sim.state.day_index
	var primary: bool = false
	var bonuses: Array[bool] = []
	match act:
		1:
			primary = o.quit_job_met_on != ""
			bonuses = [o.crash_held_sats > 0 and not o.crash_sold]
		2:
			primary = o.act_peak_hashrate_hs >= act2_target_hs and sim.state.finance.cash_cents >= 0
			bonuses = [o.exchange_losses_sats == 0]
	var met: int = bonuses.count(true)
	var grade: String = "F" if o.act_lost else ("A" if primary and met == bonuses.size() else ("B" if primary else "C"))
	var equity: int = sim.finance.equity_cents(sim, day)
	var card: Dictionary = {
		"act": float(act),
		"date": sim.current_date(),
		"equity_usd": equity / Finance.CENTS_PER_USD,
		"ownership": sim.state.finance.ownership,
		"score_usd": equity * sim.state.finance.ownership / Finance.CENTS_PER_USD,
		"btc": float(sim.custody.total_sats(sim.state)) / sim.consensus.sats_per_btc,
		"primary_met": primary,
		"bonuses_met": float(met),
		"bonuses_total": float(bonuses.size()),
		"grade": grade,
	}
	o.report_cards.append(card)
	result.add("act_ended", card)
	o.act = act + 1
	o.exchange_losses_sats = 0
	o.act_peak_hashrate_hs = 0.0
