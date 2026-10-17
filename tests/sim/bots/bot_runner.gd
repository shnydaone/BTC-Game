class_name BotRunner
extends RefCounted
## Plays one bot through a mode headless and records what happened.

const ACTS_1_2_END: String = "2016-07-10"  # the day after halving 2, when Act 2's report card is in
const CSV_COLUMNS: PackedStringArray = [
	"date", "cash_usd", "btc_cold", "btc_exchange", "hashrate_ths", "share", "mined_usd", "power_usd",
	"equity_usd", "ownership",
]


class Run:
	extends RefCounted
	var bot: String = ""
	var mode: String = ""
	var seed_value: int = 0
	var dates: PackedStringArray = []
	var cash_cents: PackedInt64Array = []
	var cold_sats: PackedInt64Array = []
	var exchange_sats: PackedInt64Array = []
	var hashrate_hs: PackedFloat64Array = []
	var share: PackedFloat64Array = []
	var mined_cents: PackedInt64Array = []
	var power_cents: PackedInt64Array = []
	var equity_cents: PackedInt64Array = []
	var ownership: PackedFloat64Array = []
	var report_cards: Array[Dictionary] = []
	var restructured_on: PackedStringArray = []
	var payments_missed: int = 0
	var exchange_losses_sats: int = 0
	var objective_met_on: String = ""
	var loan_taken: bool = false
	var final_site: String = ""
	var act_lost: bool = false
	var seconds: float = 0.0
	var final_json: String = ""

	## Score at the end of the last act played: equity x ownership from its report card.
	func score_usd() -> float:
		return float(report_cards[-1]["score_usd"]) if not report_cards.is_empty() else 0.0

	func card(act: int) -> Dictionary:
		for c: Dictionary in report_cards:
			if int(c["act"]) == act:
				return c
		return {}

	func survived() -> bool:
		return not act_lost and restructured_on.is_empty()

	func csv_text() -> String:
		var lines: PackedStringArray = [",".join(CSV_COLUMNS)]
		for i: int in dates.size():
			lines.append("%s,%.2f,%.8f,%.8f,%.6f,%.8f,%.2f,%.2f,%.2f,%.6f" % [
				dates[i], cash_cents[i] / 100.0, cold_sats[i] / 1.0e8, exchange_sats[i] / 1.0e8,
				hashrate_hs[i] / 1.0e12, share[i], mined_cents[i] / 100.0, power_cents[i] / 100.0,
				equity_cents[i] / 100.0, ownership[i]])
		return "\n".join(lines) + "\n"


static func run(bot: Bot, mode_id: String, seed_value: int, end_date: String = ACTS_1_2_END) -> Run:
	var started: int = Time.get_ticks_usec()
	var sim := Sim.new_game(GameData.shared(), mode_id, seed_value)
	var r := Run.new()
	r.bot = bot.name
	r.mode = mode_id
	r.seed_value = seed_value
	while not sim.is_finished() and sim.current_date() < end_date:
		bot.decide(sim)
		var day: DayResult = sim.step_day()
		for e: Dictionary in day.events:
			match e["type"]:
				"act_ended":
					r.report_cards.append(e)
				"restructured":
					r.restructured_on.append(day.date)
				"payment_missed":
					r.payments_missed += 1
				"exchange_failed":
					r.exchange_losses_sats += int(e["lost_sats"])
				"objective_met":
					r.objective_met_on = day.date
				"act_lost":
					r.act_lost = true
		_record(r, sim, day)
	r.seconds = (Time.get_ticks_usec() - started) / 1.0e6
	r.loan_taken = sim.state.finance.loan_taken
	r.final_site = sim.state.hardware.site_id
	r.final_json = JSON.stringify(sim.to_dict(), "", true, true)
	return r


static func _record(r: Run, sim: Sim, day: DayResult) -> void:
	var s: SimState = sim.state
	var exchange: int = 0
	for id: String in s.custody.exchange_sats:
		exchange += s.custody.exchange_sats[id]
	r.dates.append(day.date)
	r.cash_cents.append(s.finance.cash_cents)
	r.cold_sats.append(s.custody.cold_sats)
	r.exchange_sats.append(exchange)
	r.hashrate_hs.append(s.player_hashrate_hs)
	r.share.append(s.network.player_share)
	r.mined_cents.append(s.mining.mined_value_cents_today)
	r.power_cents.append(s.hardware.power_cents_today)
	r.equity_cents.append(sim.finance.equity_cents(sim, day.day_index))
	r.ownership.append(s.finance.ownership)


## The five GDD 14 bots, freshly built.
static func all_bots() -> Array[Bot]:
	return [NeverUpgradeBot.new(), PassiveHodlerBot.new(), HindsightBot.new(), SensibleBot.new(), MaxLeverageBot.new()]
