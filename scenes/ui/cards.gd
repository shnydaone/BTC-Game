class_name Cards
extends RefCounted
## Builds the card specs the moment queue shows: historical event cards (with a replay
## when the event has one), offers, the quit-job goal, cure-clock warnings, report cards,
## Chapter 11, act lost, the living-situation choice and the pizza regret replay.
##
## A spec: {kind, title, date, body: Array[String], lines: Array[[label, value]],
## choices: Array[{text, cmd?, call?}], replay: {series, start, end, pins}}.
## Greybox wording; the M3-4 content pass fills data/events/cards.json.

const PIZZA_EVENT: String = "pizza_day"


## Every moment in one simulated day, in the order its events happened.
static func from_day(sim: Sim, result: DayResult, screen: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var impacts: Array[Array] = _impacts(sim, result)
	var pizza_offer: Dictionary = {}
	for e: Dictionary in result.of_type("offer_made"):
		if e["kind"] == "pizza":
			pizza_offer = e
	for e: Dictionary in result.events:
		match e["type"]:
			"historical_event":
				var ev: Dictionary = sim.data.event(e["id"])
				if bool(ev["auto_pause"]) or ev["replay"] != null:
					out.append(event_card(sim, ev, impacts, pizza_offer if ev["id"] == PIZZA_EVENT else {}))
			"offer_made":
				# The pizza offer arrives with the Pizza Day card, which carries its choices.
				if e["kind"] == "forum":
					out.append(offer_card(sim, e, result.date))
			"objective_met":
				out.append(objective_card(result.date))
			"payment_overdue":
				out.append(overdue_card(sim, e, result.date, screen))
			"act_ended":
				out.append(report_card(e))
			"restructured":
				out.append(chapter_11_card(e, result.date))
			"act_lost":
				out.append(act_lost_card(e, result.date, screen))
			"pizza_milestone":
				out.append(pizza_card(sim, e, result.day_index))
			"difficulty_adjusted":
				if bool(sim.data.tuning("clock", "pause_on_difficulty_adjustment")):
					out.append({"kind": "difficulty", "title": "Difficulty adjusted", "date": result.date,
						"body": ["Difficulty moved %s at block %s." % [Fmt.signed_percent(e["change"]), Fmt.thousands(e["height"])]]})
	return out


## What the day's other events did to the player, for "What this means for your business".
static func _impacts(sim: Sim, result: DayResult) -> Array[Array]:
	var lines: Array[Array] = []
	for e: Dictionary in result.events:
		match e["type"]:
			"feature_unlocked":
				lines.append(["Unlocked", String(e["feature"]).replace("_", " ")])
			"exchange_failed":
				lines.append(["Your loss", "%s BTC on %s" % [Fmt.btc(e["lost_sats"]), Readouts.exchange_label(sim, e["exchange"])] if int(e["lost_sats"]) > 0 else "nothing: no coins there"])
			"subsidy_halved":
				lines.append(["Block reward", "now %s BTC" % Fmt.btc(e["subsidy_sats"])])
			"hardware_sped_up":
				lines.append(["%s mining" % e["tier"], "%.1fx faster" % e["multiplier"]])
			"codex_unlocked":
				lines.append(["New Codex entry", Readouts.codex_title(e["entry"])])
	return lines


static func event_card(sim: Sim, ev: Dictionary, impacts: Array[Array], pizza_offer: Dictionary) -> Dictionary:
	var flavor: Dictionary = sim.data.cards.get(ev["id"], {})
	var body: Array[String] = [String(ev["summary"])]
	if flavor.has("mentor") and MentorFeed.has_mentor(sim):
		body.append(String(flavor["mentor"]).replace("~anon", Readouts.mentor_handle(sim)))
	if flavor.has("meme"):
		body.append(String(flavor["meme"]))
	if flavor.has("business"):
		body.append("What this means for your business: " + String(flavor["business"]))
	var spec: Dictionary = {"kind": "event", "id": ev["id"], "title": ev["headline"], "date": ev["date"], "body": body, "lines": impacts}
	if ev["replay"] != null:
		var h: History = sim.data.history
		var r: Dictionary = ev["replay"]
		var start: int = h.index_of(r["start"])
		var end: int = h.index_of(r["end"])
		spec["replay"] = {"series": r.get("chart", "price"), "start": start, "end": end, "pins": _pins(sim, start, end, ev["id"])}
	if not pizza_offer.is_empty():
		spec["choices"] = _offer_choices(pizza_offer)
		spec["lines"] = impacts + [["The offer", "two pizzas for %s BTC" % Fmt.btc(pizza_offer["sats"])]]
	return spec


## Other dated events inside a replay window, as annotation pins.
static func _pins(sim: Sim, start: int, end: int, except_id: String) -> Array:
	var pins: Array = []
	for e: Dictionary in sim.data.events:
		var i: int = sim.data.history.index_of(e["date"])
		if i >= start and i <= end and e["id"] != except_id:
			pins.append([i, String(e["headline"])])
	return pins


static func _offer_choices(offer: Dictionary) -> Array:
	return [
		{"text": "Accept", "cmd": {"type": "accept_offer", "id": offer["id"]}},
		{"text": "Decline", "cmd": {"type": "decline_offer", "id": offer["id"]}},
	]


static func offer_card(_sim: Sim, e: Dictionary, date: String) -> Dictionary:
	var what: String = "two pizzas" if e["kind"] == "pizza" else "goods you would buy anyway"
	return {"kind": "offer", "title": "A forum trade offer", "date": date,
		"body": ["Someone on the forum offers %s, worth %s, for %s BTC. Accepting saves that much cash; the coins are gone for good." % [what, Fmt.usd(e["value_cents"]), Fmt.btc(e["sats"])]],
		"choices": _offer_choices(e)}


static func objective_card(date: String) -> Dictionary:
	return {"kind": "objective", "title": "Mining pays the bills", "date": date,
		"body": ["For 90 days in a row, a month of mining revenue has covered a month of living costs. You could quit the day job."],
		"choices": [
			{"text": "Quit the day job", "cmd": {"type": "quit_job"}},
			{"text": "Not yet"},
		]}


static func overdue_card(sim: Sim, e: Dictionary, date: String, screen: Node) -> Dictionary:
	return {"kind": "overdue", "title": "Payment overdue", "date": date,
		"body": ["The company is %s short on its bills. Raise cash within %d days (sell BTC, sell machines) or it enters Chapter 11." % [Fmt.usd(e["cents"]), sim.restructuring.cure_days]],
		"choices": [{"text": "Go to Treasury", "call": func() -> void: screen.right.show_tab(4)}, {"text": "Continue"}]}


static func report_card(e: Dictionary) -> Dictionary:
	var act: int = int(e["act"])
	return {"kind": "report", "title": "Act %d report card" % act, "date": e["date"],
		"body": ["Grade %s." % e["grade"]],
		"lines": [
			["Primary objective", "met" if bool(e["primary_met"]) else "missed"],
			["Bonus objectives", "%d of %d" % [int(e["bonuses_met"]), int(e["bonuses_total"])]],
			["Owner's equity", Fmt.usd(roundi(float(e["equity_usd"]) * 100.0))],
			["Ownership", Fmt.percent(e["ownership"], 1)],
			["Score", Fmt.usd(roundi(float(e["score_usd"]) * 100.0))],
			["BTC held", Fmt.btc(roundi(float(e["btc"]) * 1.0e8))],
		],
		"choices": [{"text": "On to Act %d" % (act + 1)}]}


static func chapter_11_card(e: Dictionary, date: String) -> Dictionary:
	return {"kind": "chapter11", "title": "Chapter 11", "date": date,
		"body": ["The company could not pay its bills. Creditors took part of the fleet and turned %s of debt into equity." % Fmt.usd(e["debt_cents"])],
		"lines": [["Ownership cut", Fmt.percent(e["cut"], 1)], ["Your ownership now", Fmt.percent(e["ownership"], 1)], ["Below 10%", "the board replaces you"]],
		"choices": [{"text": "Keep going"}]}


static func act_lost_card(e: Dictionary, date: String, screen: Node) -> Dictionary:
	var main: Node = screen.main
	var mode: String = GameClock.sim.state.mode_id if GameClock.sim != null else "slashdot"
	return {"kind": "act_lost", "title": "The board replaced you", "date": date,
		"body": ["Your ownership fell below 10%%. Act %d is lost." % int(e["act"])],
		"choices": [
			{"text": "Replay the act", "call": func() -> void:
				if Save.has_save(Save.AUTOSAVE):
					main.continue_game(Save.AUTOSAVE)
				else:
					main.start_new_game(mode)},
			{"text": "Quit to title", "call": func() -> void: main.show_title()},
		]}


static func living_card(sim: Sim) -> Dictionary:
	var choices: Array = []
	var options: Dictionary = sim.finance.living_situations
	for k: String in options:
		choices.append({"text": "%s %s/mo" % [k.capitalize(), Fmt.usd(options[k])], "cmd": {"type": "choose_living", "situation": k}})
	return {"kind": "living", "title": "Where do you live?", "date": Readouts.date(sim),
		"body": ["Rent, food and bills come out on the 1st whether or not you have a job. Cheaper living saves faster and makes quitting the day job easier. You choose once."],
		"choices": choices}


static func pizza_card(sim: Sim, e: Dictionary, day: int) -> Dictionary:
	var start: int = sim.data.history.index_of(sim.data.event(PIZZA_EVENT)["date"])
	return {"kind": "pizza", "title": "Two pizzas, %s" % Fmt.usd(e["value_cents"]), "date": sim.data.history.dates[day],
		"body": ["On 2010-05-22 someone paid 10,000 BTC for two pizzas. Today those coins are worth %s." % Fmt.usd(e["value_cents"])],
		"replay": {"series": "pizza", "start": start, "end": day, "pins": []}}
